#!/usr/bin/env python3
"""Open the daily dashboard once per login, reusing existing windows."""
import fcntl
import json
import os
from pathlib import Path
import shlex
import subprocess
import time

SCRIPTS = Path(__file__).resolve().parent


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
    if cls in ('dotfiles-pomoru', 'dotfiles-music'):
        return 'pomoru' if cls.endswith('pomoru') else 'music'
    if cls == 'com.mitchellh.ghostty':
        if title == 'pomoru':
            return 'pomoru'
        if title == 'cliamp' or title.endswith(' | cliamp'):
            return 'music'
    return None


def arrange(windows):
    # Float first to rebuild just these three leaves in the dwindle tree.
    for address in windows.values():
        dispatch('setfloating', f'address:{address}')
        dispatch('movetoworkspacesilent', f'1,address:{address}')
    dispatch('workspace', '1')
    dispatch('settiled', f'address:{windows["pomoru"]}')
    dispatch('focuswindow', f'address:{windows["pomoru"]}')
    dispatch('layoutmsg', 'preselect r')
    dispatch('settiled', f'address:{windows["calendar"]}')
    dispatch('focuswindow', f'address:{windows["pomoru"]}')
    dispatch('layoutmsg', 'preselect d')
    dispatch('settiled', f'address:{windows["music"]}')
    dispatch('focuswindow', f'address:{windows["pomoru"]}')


def start():
    existing = {}
    for client in clients():
        name = identify(client)
        if name:
            existing.setdefault(name, client)
    if len(existing) == 3 and all(c['workspace']['id'] == 1 for c in existing.values()):
        print('Space 1 dashboard already open; keeping current layout.')
        return
    commands = {
        'pomoru': [str(SCRIPTS / 'ubuntu-app-launch.sh'), 'ghostty', '--class=dotfiles-pomoru', '-e', 'pomoru'],
        'calendar': [str(SCRIPTS / 'ubuntu-app-launch.sh'), 'chrome', '--app=https://calendar.notion.com'],
        'music': [str(SCRIPTS / 'ubuntu-app-launch.sh'), 'ghostty', '--class=dotfiles-music', '-e', str(SCRIPTS / 'music-player.sh')],
    }
    for name, command in commands.items():
        if name not in existing:
            dispatch('exec', '[workspace 1 silent; float] ' + shlex.join(command))
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        for client in clients():
            name = identify(client)
            if name:
                existing.setdefault(name, client)
        if len(existing) == 3:
            arrange({name: c['address'] for name, c in existing.items()})
            print('Space 1 dashboard ready.')
            return
        time.sleep(0.25)
    missing = ', '.join(set(commands) - set(existing))
    raise RuntimeError(f'Dashboard startup timed out waiting for: {missing}')


def main():
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
