#!/usr/bin/env python3
"""Open the daily dashboard after the desktop is ready, without taking focus."""
import fcntl
import json
import logging
import os
from pathlib import Path
import shlex
import subprocess
import time

SCRIPTS = Path(__file__).resolve().parent
IPC_ERRORS = (OSError, subprocess.SubprocessError, ValueError, RuntimeError)


def ipc(*args):
    return subprocess.check_output(['hyprctl', *args], text=True, timeout=10).strip()


def dispatch(command, argument):
    result = ipc('dispatch', command, argument)
    if result != 'ok':
        raise RuntimeError(f'{command}: {result}')


def clients():
    return json.loads(ipc('-j', 'clients'))


def identify(client):
    cls, title = client.get('class', ''), client.get('title', '')
    if cls.startswith('chrome-calendar.notion.com__'):
        return 'calendar'
    # Keep recognizing windows opened by earlier versions of this helper.
    if cls in ('com.dotfiles.pomoru', 'dotfiles-pomoru'):
        return 'pomoru'
    if cls in ('com.dotfiles.music', 'dotfiles-music'):
        return 'music'
    if cls == 'com.mitchellh.ghostty':
        if title == 'pomoru':
            return 'pomoru'
        if title == 'cliamp' or title.endswith(' | cliamp'):
            return 'music'
    return None


def desktop_state(backend):
    monitors = json.loads(ipc('-j', 'monitors'))
    workspaces = json.loads(ipc('-j', 'workspaces'))
    target = next((w.get('monitor') for w in workspaces if w['id'] == 1), None)
    monitor = next((m for m in monitors if m['name'] == target), None)
    if monitor is None:
        monitor = next((m for m in monitors if m.get('focused')), None)
    if not monitor or monitor.get('disabled') or monitor['width'] <= 0 or monitor['height'] <= 0:
        return None
    layers = json.loads(ipc('-j', 'layers')).get(monitor['name'], {}).get('levels', {})
    namespaces = {layer.get('namespace') for level in layers.values() for layer in level
                  if layer.get('w', 0) > 0 and layer.get('h', 0) > 0}
    required = {'caelestia-background', 'caelestia-topbar'} if backend == 'caelestia' else {'dms:bar'}
    if not required <= namespaces:
        return None
    # Wait for reserved bar/frame space to settle as well as the surfaces.
    return (monitor['name'], monitor['width'], monitor['height'],
            monitor.get('scale', 1), tuple(monitor.get('reserved', [])))


def wait_for_desktop(timeout=60):
    backend = subprocess.check_output([str(SCRIPTS / 'ubuntu-desktop-shell.sh'), 'current'],
                                      text=True, timeout=10).strip()
    deadline = time.monotonic() + timeout
    previous = None
    logging.info('Waiting for Hyprland monitor and %s desktop surfaces', backend)
    while time.monotonic() < deadline:
        try:
            state = desktop_state(backend)
            if state is not None and state == previous:
                logging.info('Desktop ready on %s', state[0])
                return
            previous = state
        except IPC_ERRORS as error:
            previous = None
            logging.warning('Desktop readiness check will retry: %s', error)
        time.sleep(0.5)
    raise RuntimeError(f'Timed out waiting for Hyprland/{backend} desktop readiness')


def arrange(windows):
    """Repair only unfinished placement; preserve existing tiles and user focus."""
    for client in windows.values():
        address = client['address']
        if client.get('floating'):
            # In Hyprland 0.53, settiled moves a floating window to the active
            # workspace. Move it back in the same IPC batch, without focusing it.
            result = ipc('--batch', f'dispatch settiled address:{address}; '
                         f'dispatch movetoworkspacesilent 1,address:{address}')
            if any(line.strip() != 'ok' for line in result.splitlines() if line.strip()):
                raise RuntimeError(f'Window placement: {result}')
        elif client['workspace']['id'] != 1:
            dispatch('movetoworkspacesilent', f'1,address:{address}')


def start():
    wait_for_desktop()
    commands = {
        'pomoru': [str(SCRIPTS / 'ubuntu-app-launch.sh'), 'ghostty',
                   '--class=com.dotfiles.pomoru', '-e', 'pomoru'],
        'calendar': [str(SCRIPTS / 'ubuntu-app-launch.sh'), 'chrome', '--app=https://calendar.notion.com'],
        'music': [str(SCRIPTS / 'ubuntu-app-launch.sh'), 'ghostty',
                  '--class=com.dotfiles.music', '-e', str(SCRIPTS / 'music-player.sh')],
    }
    launched = set()
    deadline = time.monotonic() + 120
    existing = {}
    while time.monotonic() < deadline:
        try:
            # Re-read addresses on every pass: a client can close or be replaced
            # while Chrome or a terminal application is still starting.
            existing = {}
            for client in clients():
                name = identify(client)
                if name and client.get('mapped', True):
                    existing.setdefault(name, client)
            if len(existing) == 3 and all(c['workspace']['id'] == 1 and not c.get('floating')
                                          for c in existing.values()):
                logging.info('Space 1 dashboard ready; preserving current tile layout')
                return
            arrange(existing)
            # Launch each missing app once. Retrying IPC/placement must not open
            # duplicate windows when an app takes a long time to map its window.
            for name, command in commands.items():
                if name not in existing and name not in launched:
                    # A timeout can lose the reply after exec was accepted.
                    # Mark it pending before dispatch so the next pass waits
                    # for the window instead of starting a duplicate.
                    launched.add(name)
                    try:
                        dispatch('exec', '[workspace 1 silent; tile; no_initial_focus on] ' + shlex.join(command))
                    except subprocess.CalledProcessError as error:
                        # hyprctl 0.53 exits 1-4 before writing the request
                        # (socket setup, missing instance, connection failure).
                        # Exit 6 means reading the reply failed after submission.
                        if error.returncode in (1, 2, 3, 4):
                            launched.remove(name)
                        raise
                    except (OSError, RuntimeError):
                        # The local client could not run, or Hyprland explicitly
                        # rejected exec: these failures are safe to resubmit.
                        launched.remove(name)
                        raise
                    logging.info('Started %s on workspace 1', name)
        except IPC_ERRORS as error:
            logging.warning('Dashboard startup will retry: %s', error)
        time.sleep(0.5)
    status = ', '.join(f'{name}: ' + ('not detected' if name not in existing else
                      f'workspace={existing[name]["workspace"]["id"]}, floating={existing[name]["floating"]}')
                       for name in commands)
    raise RuntimeError(f'Dashboard startup timed out: {status}')


def main():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
    os.environ['PATH'] = str(Path.home() / '.local/bin') + ':' + os.environ.get('PATH', '/usr/bin:/bin')
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    signature = os.environ['HYPRLAND_INSTANCE_SIGNATURE']
    with (runtime / f'dotfiles-workspace-one-{signature}.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        start()


if __name__ == '__main__':
    main()
