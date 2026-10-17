#!/usr/bin/env python3
"""Apply Ubuntu bar styling without changing the macOS preset or unrelated preferences."""
import argparse
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
CURRENT = CONFIG / 'desktop-theme/current'


def merge(settings, style, layout=False):
    result = copy.deepcopy(settings)
    bars = result.get('barConfigs', [])
    if not bars:
        raise ValueError('No DMS bar configuration to style')
    result.update(style['settings'])
    bar = bars[0]
    bar.update(style['bar'])
    if layout:
        bar.update(leftWidgets=['dotfilesBreakTimer', 'workspaceSwitcher'],
                   centerWidgets=['music'],
                   rightWidgets=['dotfilesCodexUsage', 'cpuUsage', 'memUsage',
                                 'systemTray', 'notificationButton', 'controlCenterButton', 'clock'])
    return result


def ipc(*args):
    output = subprocess.check_output(['dms', 'ipc', 'call', *args], text=True, timeout=5)
    return json.loads(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layout', action='store_true', help='Also adopt the macOS widget arrangement')
    parser.add_argument('--generation', type=Path, default=CURRENT, help='Pinned generated theme directory')
    args = parser.parse_args()
    style = json.loads((args.generation / 'ubuntu-style.json').read_text())
    path = CONFIG / 'DankMaterialShell/settings.json'
    if path.is_symlink():
        raise ValueError('DMS preferences must be a mutable file, not a symlink')
    live = bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')) and 'Hyprland' in os.environ.get('XDG_CURRENT_DESKTOP', '').split(':')
    # DMS IPC intentionally rejects arrays on settings.set. Merge its fresh
    # snapshot and let its supported settings-file watcher reload the bar array.
    settings = ipc('settings', 'dump') if live else json.loads(path.read_text())
    updated = merge(settings, style, args.layout)
    if updated == settings:
        return
    backup = path.with_suffix('.json.before-macos-style')
    if not backup.exists():
        shutil.copy2(path, backup)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as stream:
        json.dump(updated, stream, indent=2)
        stream.write('\n')
        temporary = Path(stream.name)
    temporary.chmod(path.stat().st_mode & 0o777)
    os.replace(temporary, path)
    if live:
        # Verify that the running bar consumed our external file update.
        for _ in range(30):
            if ipc('settings', 'get', 'barConfigs') == updated['barConfigs']:
                return
            time.sleep(0.1)
        raise RuntimeError('DMS did not reload the updated bar configuration')


if __name__ == '__main__':
    main()
