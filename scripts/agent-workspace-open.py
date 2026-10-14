#!/usr/bin/env python3
"""Route identifiable new application windows to a local agent's Ghostty window."""

import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
EXCLUDED = {'com.electron.aqua-voice', 'com.raycast.macos'}


def warn(message):
    print(f'agent-workspace: {message}', file=sys.stderr)


def windows():
    result = subprocess.run(
        ['aerospace', 'list-windows', '--all', '--format',
         '%{window-id} %{app-bundle-id} %{app-pid} %{workspace} %{window-title}', '--json'],
        capture_output=True, text=True, timeout=4, check=True,
    )
    return json.loads(result.stdout)


def origin_workspace(items, origin_id, origin_pid):
    for item in items:
        if (str(item['window-id']) == origin_id
                and item['app-bundle-id'] == 'com.mitchellh.ghostty'
                and str(item['app-pid']) == origin_pid):
            return item['workspace']
    return None


def resolve_app(mode, value):
    result = subprocess.run(
        ['/usr/bin/osascript', '-l', 'JavaScript',
         str(ROOT / 'agent-workspace-resolve-app.js'), mode, value],
        capture_output=True, text=True, timeout=5, check=True,
    )
    return result.stdout.strip()


def request_target(kind, args):
    """Return (bundle ID, expected title fragments), or None for unsupported forms."""
    if kind == 'code':
        if any(arg in args for arg in ['--reuse-window', '-r', '--wait', '-w', '--diff', '--merge']):
            return None
        # A code CLI query must never create or route a window.
        if not args or any(arg in args for arg in ['--version', '-v', '--help', '-h', '--list-extensions', '--install-extension', '--uninstall-extension', '--status']):
            return None
        allowed = {'--new-window', '-n', '--goto', '-g'}
        if any(arg.startswith('-') and arg not in allowed for arg in args):
            return None
        paths = [arg for arg in args if not arg.startswith('-')]
        if not paths:
            return None
        path = re.sub(r':\d+(?::\d+)?$', '', paths[-1])
        return 'com.microsoft.VSCode', [Path(path).name]

    app = None
    bundle = None
    reveal = False
    targets = []
    index = 0
    while index < len(args):
        arg = args[index]
        if arg in ['-a', '-b']:
            index += 1
            if index >= len(args):
                return None
            if arg == '-a':
                app = args[index]
            else:
                bundle = args[index]
        elif arg == '-R':
            reveal = True
        elif arg in ['-g', '-n', '-j']:
            pass
        elif arg.startswith('-'):
            return None
        else:
            targets.append(arg)
        index += 1
    if len(targets) != 1:
        return None
    target = targets[0]
    if reveal:
        return 'com.apple.finder', [Path(target).resolve().parent.name]
    if Path(target).is_dir() and not app and not bundle:
        return 'com.apple.finder', [Path(target).resolve().name]
    is_url = bool(urlparse(target).scheme) and not Path(target).exists()
    expected = [] if is_url else [Path(target).name]
    if not bundle:
        bundle = resolve_app('app', app) if app else resolve_app(
            'url' if is_url else 'file', target if is_url else str(Path(target).resolve()))
    return (bundle, expected) if bundle else None


def select_new_window(before_ids, items, bundle, title_fragments):
    candidates = [item for item in items if str(item['window-id']) not in before_ids
                  and item['app-bundle-id'] == bundle
                  and all(fragment.casefold() in item.get('window-title', '').casefold()
                          for fragment in title_fragments)]
    # Never choose an arbitrary window when more than one matches.
    return candidates[0] if len(candidates) == 1 else None


def command_for(kind, args, routed):
    if kind == 'open':
        return ['/usr/bin/open', *([] if '-g' in args or not routed else ['-g']), *args]
    real = os.environ.get('AGENT_REAL_CODE') or '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code'
    return [real, *(['--new-window'] if routed and '--new-window' not in args and '-n' not in args else []), *args]


def open_target(args):
    skip = False
    targets = []
    for arg in args:
        if skip:
            skip = False
        elif arg in ['-a', '-b']:
            skip = True
        elif not arg.startswith('-'):
            targets.append(arg)
    return targets[0]


def launch(kind, args, bundle):
    target = open_target(args) if kind == 'open' else None
    if target and bundle == 'com.microsoft.VSCode':
        return subprocess.call(command_for('code', [target], True), timeout=15)
    if target and bundle == 'com.google.Chrome':
        # Ask Chrome for a new window explicitly instead of reusing a user's tab.
        url = target if urlparse(target).scheme else Path(target).resolve().as_uri()
        return subprocess.call(['/usr/bin/osascript', str(ROOT / 'agent-workspace-new-window.applescript'), 'chrome', url], timeout=15)
    if target and bundle == 'com.apple.finder':
        directory = Path(target).resolve().parent if '-R' in args else Path(target).resolve()
        return subprocess.call(['/usr/bin/osascript', str(ROOT / 'agent-workspace-new-window.applescript'), 'finder', str(directory)], timeout=15)
    return subprocess.call(command_for(kind, args, True), timeout=15)


def route(kind, args, target, origin_id, origin_pid):
    bundle, fragments = target
    before = windows()
    if not origin_workspace(before, origin_id, origin_pid):
        warn('origin window is gone; request not opened. Restart the agent in a live Ghostty window.')
        return 75
    before_ids = {str(item['window-id']) for item in before}
    status = launch(kind, args, bundle)
    if status:
        return status
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        items = windows()
        destination = origin_workspace(items, origin_id, origin_pid)
        if destination is None:
            warn('origin window closed while opening; no window moved.')
            return 75
        candidate = select_new_window(before_ids, items, bundle, fragments)
        if candidate:
            subprocess.run(['aerospace', 'move-node-to-workspace', destination,
                            '--window-id', str(candidate['window-id'])], check=True, timeout=4)
            return 0
        time.sleep(0.2)
    warn('no uniquely identifiable new window; existing windows left in place.')
    return 75


def main():
    kind, *args = sys.argv[1:]
    if kind not in ['open', 'code']:
        return 2
    origin_id = os.environ.get('AGENT_ORIGIN_WINDOW_ID', '')
    origin_pid = os.environ.get('AGENT_ORIGIN_APP_PID', '')
    if not origin_id.isdigit() or not origin_pid.isdigit():
        return subprocess.call(command_for(kind, args, False))
    try:
        target = request_target(kind, args)
    except (subprocess.SubprocessError, OSError):
        target = None
    if not target or target[0] in EXCLUDED:
        return subprocess.call(command_for(kind, args, False))
    state = Path.home() / 'Library/Caches/agent-workspace'
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Serialize agent requests so two helpers cannot claim each other's new windows.
    with (state / 'open.lock').open('a') as lock:
        deadline = time.monotonic() + 15
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    warn('another open request is busy; retry this request.')
                    return 75
                time.sleep(0.1)
        try:
            return route(kind, args, target, origin_id, origin_pid)
        except (subprocess.SubprocessError, OSError, ValueError, KeyError) as error:
            warn(f'window routing failed: {error}; request was not retried.')
            return 1


if __name__ == '__main__':
    sys.exit(main())
