#!/usr/bin/env python3
"""Match macOS Ghostty navigation while retaining tmux/editor Ctrl keys."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess


def ipc(*args):
    result = subprocess.run(['hyprctl', *args], check=True, capture_output=True, text=True, timeout=3)
    return result.stdout


def focus_target(window, clients, key):
    axis = 0 if key in ('h', 'l') else 1
    other = 1 - axis
    sign = -1 if key in ('h', 'k') else 1
    center = [window['at'][i] + window['size'][i] / 2 for i in (0, 1)]
    candidates = [c for c in clients if c.get('mapped', True) and not c.get('hidden')
                  and not c.get('floating') and c.get('address') != window['address']
                  and c.get('workspace', {}).get('id') == window.get('workspace', {}).get('id')]
    if not candidates:
        return None
    def position(c):
        return c['at'][axis] + c['size'][axis] / 2
    def perpendicular(c):
        return abs(c['at'][other] + c['size'][other] / 2 - center[other])
    def gap(c):
        return max(0, window['at'][other] - c['at'][other] - c['size'][other],
                   c['at'][other] - window['at'][other] - window['size'][other])
    forward = [c for c in candidates if sign * (position(c) - center[axis]) > 0]
    if forward:
        return min(forward, key=lambda c: (gap(c) > 0, abs(position(c) - center[axis]), perpendicular(c)))
    # At an edge, wrap to the opposite edge on the same row/column.
    return min(candidates, key=lambda c: (gap(c) > 0, sign * position(c), perpendicular(c)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('key', choices=list('hjklui'))
    parser.add_argument('--passthrough-modifiers', type=str.upper, choices=('CTRL', 'SUPER'),
                        default='CTRL',
                        help='modifier forwarded by sendshortcut passthroughs (default: %(default)s)')
    arguments = parser.parse_args()
    key = arguments.key
    # Forward the modifier that triggered navigation so swapped Ctrl/Super keys
    # reach the focused client before Ghostty's reverse remapping.
    modifier = arguments.passthrough_modifiers
    window = json.loads(ipc('-j', 'activewindow'))
    if window.get('class', '').lower() not in ('com.mitchellh.ghostty', 'ghostty'):
        ipc('dispatch', 'sendshortcut', f'{modifier},{key.upper()},')
        return
    # Layer-shell launchers retain the underlying window in activewindow IPC.
    # Preserve search/editing keys while a launcher owns keyboard focus.
    selection = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'dotfiles/desktop-shell'
    try:
        backend = selection.read_text().strip()
    except OSError:
        backend = 'dms'
    if backend == 'caelestia':
        try:
            helper = Path(__file__).with_name('ubuntu-desktop-shell.sh')
            opened = subprocess.run([str(helper), 'launcher-open'], capture_output=True, timeout=0.5)
            if opened.returncode == 0:
                ipc('dispatch', 'sendshortcut', f'{modifier},{key.upper()},')
                return
        except (OSError, subprocess.TimeoutExpired):
            pass
    if shutil.which('vicinae'):
        try:
            opened = subprocess.run(['vicinae', 'state', 'open'], capture_output=True, timeout=0.25)
            if opened.returncode == 0:
                ipc('dispatch', 'sendshortcut', f'{modifier},{key.upper()},')
                return
        except (OSError, subprocess.TimeoutExpired):
            pass
    if key in 'ui':
        if window.get('title', '').startswith('[tmux] '):
            ipc('dispatch', 'sendshortcut', f'{modifier},{key.upper()},')
        else:
            ipc('dispatch', 'workspace', 'e-1' if key == 'u' else 'e+1')
        return
    target = focus_target(window, json.loads(ipc('-j', 'clients')), key)
    if target:
        ipc('dispatch', 'focuswindow', 'address:' + target['address'])


if __name__ == '__main__':
    main()
