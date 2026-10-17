#!/usr/bin/env python3
"""Persistent work/break timer. Only `watch` produces desktop effects.

Actions print the same JSON contract as status. A locked pending-event queue
prevents duplicate effects between workers. Events are claimed before delivery:
crashes can lose a notification, but cannot replay an already claimed sound.
"""
import argparse
from contextlib import contextmanager
import fcntl
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
DEFAULTS = {'work_minutes': 30, 'break_minutes': 3, 'snooze_minutes': 3,
            'warning_seconds': 60, 'auto_start_work': False, 'auto_start_break': False}
STATES = {'off', 'work', 'wait-break', 'break', 'wait-work'}


def validate_config(config):
    result = dict(DEFAULTS, **config)
    for key in DEFAULTS:
        value = result[key]
        if key.startswith('auto_start_'):
            if type(value) is not bool:
                raise ValueError(f'{key} must be a boolean')
        elif type(value) not in (int, float) or not math.isfinite(value) or value < (0 if key == 'warning_seconds' else 1 / 60) or value > 525600:
            raise ValueError(f'{key} must be a finite positive duration (warning_seconds may be zero)')
    return result


def load_config():
    config = dict(DEFAULTS)
    paths = [ROOT / 'platforms/ubuntu/break-timer.json',
             Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'dotfiles/break-timer.json']
    for path in paths:
        try:
            data = json.loads(path.read_text())
            if not isinstance(data, dict):
                raise ValueError('configuration must be a JSON object')
            config = validate_config(dict(config, **data))
        except FileNotFoundError:
            pass
        except (OSError, ValueError, TypeError) as error:
            print(f'break-timer: ignoring invalid config {path}: {error}', file=sys.stderr)
    return config


def fresh_state():
    return {'state': 'off', 'deadline': None, 'warned': False, 'events': []}


class Timer:
    def __init__(self, directory, config):
        self.directory = Path(directory)
        self.config = validate_config(config)
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.directory.chmod(0o700)
        self.path = self.directory / 'break-timer.json'

    @contextmanager
    def transaction(self):
        fd = os.open(self.directory / 'break-timer.lock', os.O_CREAT | os.O_RDWR, 0o600)
        with os.fdopen(fd, 'a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                state = json.loads(self.path.read_text())
                if not isinstance(state, dict) or state.get('state') not in STATES:
                    raise ValueError('invalid state')
                deadline = state.get('deadline')
                if state['state'] in ('work', 'break') and (type(deadline) not in (int, float) or not math.isfinite(deadline)):
                    raise ValueError('invalid deadline')
                if not isinstance(state.get('events'), list) or any(not isinstance(e, dict) or e.get('kind') not in ('start', 'warning', 'complete') or e.get('phase') not in ('work', 'break') for e in state['events']):
                    raise ValueError('invalid events')
            except (OSError, ValueError, TypeError):
                state = fresh_state()
            yield state
            temporary = None
            try:
                with tempfile.NamedTemporaryFile('w', dir=self.directory, delete=False) as output:
                    temporary = output.name
                    json.dump(state, output)
                    output.flush()
                    os.fsync(output.fileno())
                os.replace(temporary, self.path)
            finally:
                if temporary and os.path.exists(temporary):
                    os.unlink(temporary)

    def start(self, state, phase, now, seconds=None):
        state.update(state=phase, deadline=now + (seconds if seconds is not None else self.config[f'{phase}_minutes'] * 60), warned=False)
        state['events'].append({'kind': 'start', 'phase': phase})

    def advance(self, state, now):
        phase = state['state']
        if phase not in ('work', 'break'):
            return
        remaining = state['deadline'] - now
        if remaining <= 0:
            state['events'].append({'kind': 'complete', 'phase': phase})
            next_phase = 'break' if phase == 'work' else 'work'
            state.update(state=f'wait-{next_phase}', deadline=None, warned=False)
            if self.config[f'auto_start_{next_phase}']:
                self.start(state, next_phase, now)
        elif self.config['warning_seconds'] and remaining <= self.config['warning_seconds'] and not state.get('warned'):
            state['warned'] = True
            state['events'].append({'kind': 'warning', 'phase': phase})

    def run(self, action, now):
        with self.transaction() as state:
            self.advance(state, now)
            if action == 'toggle':
                action = 'start-break' if state['state'] in ('work', 'wait-break') else 'start-work'
            if action in ('start-work', 'start-break'):
                state['events'] = []
                self.start(state, action[6:], now)
            elif action == 'stop':
                state.update(fresh_state())
            elif action == 'snooze':
                phase = state['state']
                seconds = self.config['snooze_minutes'] * 60
                if phase in ('work', 'break'):
                    state.update(deadline=state['deadline'] + seconds, warned=False)
                elif phase in ('wait-break', 'wait-work'):
                    state['events'] = []
                    self.start(state, 'work' if phase == 'wait-break' else 'break', now, seconds)
            remaining = max(0, math.ceil((state.get('deadline') or now) - now)) if state['state'] in ('work', 'break') else 0
            labels = {'off': 'Off', 'wait-break': 'Start break', 'wait-work': 'Start work', 'work': 'Work', 'break': 'Break'}
            label = labels[state['state']]
            if state['state'] in ('work', 'break'):
                label += f' {remaining // 60:02d}:{remaining % 60:02d}'
            result = {'state': state['state'], 'remaining_seconds': remaining, 'label': label,
                      'tooltip': f'{label} · Super+P switches phase; choose an action below'}
            # Bound the queue if status is polled for days without a worker.
            state['events'] = state['events'][-16:]
        return result

    def claim_events(self):
        with self.transaction() as state:
            events = state['events'][:]
            state['events'] = []
        return events


def emit(event):
    phase = event['phase']
    kind = event['kind']
    messages = {'start': f'{phase.title()} timer started', 'warning': f'{phase.title()} ends soon',
                'complete': 'Time for a break — click the timer to start' if phase == 'work' else 'Break finished — click the timer to start work'}
    if shutil.which('notify-send'):
        try:
            subprocess.run(['notify-send', '--app-name=Break Timer', 'Break Timer', messages[kind]], timeout=5, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (OSError, subprocess.TimeoutExpired):
            pass
    if kind == 'start':
        return
    sound = ROOT / 'break-timer/sounds' / ('warning-beep.mp3' if kind == 'warning' else 'timer-complete.mp3')
    player = shutil.which('pw-play') or shutil.which('mpv')
    if player and sound.is_file():
        command = [player, str(sound)] if Path(player).name == 'pw-play' else [player, '--no-video', '--really-quiet', str(sound)]
        try:
            subprocess.run(command, timeout=15, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (OSError, subprocess.TimeoutExpired):
            pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['status', 'toggle', 'start-work', 'start-break', 'snooze', 'stop', 'watch'], nargs='?', default='status')
    parser.add_argument('--now', type=float, help='deterministic epoch time for status/actions (not watch)')
    args = parser.parse_args()
    if args.now is not None and (not math.isfinite(args.now) or args.action == 'watch'):
        parser.error('--now must be finite and cannot be used with watch')
    state_root = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'dotfiles'
    backend = Timer(state_root, load_config())
    if args.action != 'watch':
        print(json.dumps(backend.run(args.action, args.now if args.now is not None else time.time())))
        return
    try:
        while True:
            backend.run('status', time.time())
            for event in backend.claim_events():
                emit(event)
            time.sleep(1)
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
