#!/usr/bin/env python3
"""Apply shared desktop colors and rotate wallpapers inside a Hyprland session."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
CURRENT = CONFIG / 'desktop-theme/current'
DATA = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
STATE = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state'))
# Caelestia wallpapers to cycle through; images stay outside the repository.
ROTATION = Path(__file__).resolve().parent.parent / 'platforms/ubuntu/caelestia/wallpapers.json'


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Mutable settings must never point into the managed repository.
    if path.is_symlink():
        raise ValueError('Refusing to overwrite symlinked mutable settings: ' + str(path))
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(content)
            stream.close()
            if path.exists():
                os.chmod(temporary, path.stat().st_mode & 0o777)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def update_json(path, update):
    data = json.loads(path.read_text()) if path.exists() else {}
    update(data)
    if path.exists() and not path.with_suffix(path.suffix + '.before-desktop-theme').exists():
        shutil.copy2(path, path.with_suffix(path.suffix + '.before-desktop-theme'))
    atomic_write(path, json.dumps(data, indent=2) + '\n')


def in_session():
    return bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'))


def desktop_shell():
    try:
        return (CONFIG / 'dotfiles/desktop-shell').read_text().strip()
    except FileNotFoundError:
        return 'dms'


def command(*args):
    result = subprocess.run(args, check=True, capture_output=True, text=True, timeout=10)
    if 'ERROR:' in result.stdout or 'SETTINGS_SET_FAILURE' in result.stdout or 'SETTINGS_INVALID_KEY' in result.stdout:
        raise ValueError(result.stdout.strip())
    return result.stdout.strip()


def ipc(*args):
    return command('dms', 'ipc', 'call', *args)


def rotation():
    try:
        data = json.loads(ROTATION.read_text())
    except FileNotFoundError:
        return 3600, []
    if type(data['rotation_seconds']) is not int or data['rotation_seconds'] < 60:
        raise ValueError('Wallpaper rotation must be at least 60 seconds')
    # Paths are home-relative so other machines can fetch the same images.
    # Caelestia records resolved paths, so compare against resolved entries.
    paths = [(Path.home() / p).resolve() for p in data['wallpapers']]
    return data['rotation_seconds'], [str(p) for p in paths if p.is_file()]


def wallpaper():
    if not in_session():
        raise ValueError('Wallpaper control requires a Hyprland session')
    if desktop_shell() != 'caelestia':
        ipc('wallpaper', 'next')
        return
    paths = rotation()[1]
    if not paths:
        command('caelestia', 'wallpaper', '-r')
        return
    try:
        current = str(Path((STATE / 'caelestia/wallpaper/path.txt').read_text().strip()).resolve())
    except FileNotFoundError:
        current = ''
    following = paths.index(current) + 1 if current in paths else 0
    command('caelestia', 'wallpaper', '-f', paths[following % len(paths)])


def apply():
    # Resolve one immutable generation so a concurrent publish cannot mix colors.
    generation = CURRENT.resolve(strict=True)
    theme = json.loads((generation / 'theme.json').read_text())
    dms_file = str(generation / 'dms-theme.json')
    if not Path(dms_file).is_file():
        raise ValueError('Regenerate the shared desktop theme first')
    vicinae_theme = DATA / 'vicinae/themes/dotfiles-desktop.toml'
    atomic_write(vicinae_theme, (generation / 'vicinae-theme.toml').read_text())
    atomic_write(CONFIG / 'dotfiles/hypr/theme.conf', (generation / 'hyprland.conf').read_text())
    if in_session():
        if desktop_shell() == 'caelestia':
            # Leave the wallpaper to the rotation list when one is configured.
            if not rotation()[1]:
                command('caelestia', 'wallpaper', '-f', theme['wallpapers'][0]['path'])
            command('hyprctl', 'reload')
            return
        ipc('settings', 'set', 'customThemeFile', dms_file)
        ipc('settings', 'set', 'currentThemeName', 'custom')
        # Vicinae rescans directory changes after a 50ms debounce.
        for attempt in range(5):
            try:
                command('vicinae', 'theme', 'set', 'dotfiles-desktop')
                break
            except subprocess.CalledProcessError:
                if attempt == 4:
                    raise
                time.sleep(0.2)
        ipc('wallpaper', 'set', theme['wallpapers'][0]['path'])
        if (generation / 'ubuntu-style.json').is_file():
            command(sys.executable, str(Path(__file__).with_name('ubuntu-desktop-style.py')), '--generation', str(generation))
        command('hyprctl', 'reload')
        return

    # Logged out: only persist user-owned configuration for the next session.
    def dms_settings(data):
        data.update(customThemeFile=dms_file, currentThemeName='custom')
    update_json(CONFIG / 'DankMaterialShell/settings.json', dms_settings)

    def vicinae_settings(data):
        for mode in ('dark', 'light'):
            data.setdefault('theme', {}).setdefault(mode, {})['name'] = 'dotfiles-desktop'
    update_json(CONFIG / 'vicinae/vicinae.json', vicinae_settings)
    if (generation / 'ubuntu-style.json').is_file():
        command(sys.executable, str(Path(__file__).with_name('ubuntu-desktop-style.py')), '--generation', str(generation))



def watch(poll):
    if not in_session():
        raise ValueError('Theme watcher requires a Hyprland session')
    state = CONFIG / 'desktop-theme'
    state.mkdir(parents=True, exist_ok=True)
    with (state / '.ubuntu-watch.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        previous = None
        deadline = 0
        while in_session():
            try:
                # Stop when this compositor instance has exited.
                command('hyprctl', 'version')
            except (OSError, subprocess.SubprocessError):
                return
            try:
                generation = CURRENT.resolve(strict=True)
                theme = json.loads((generation / 'theme.json').read_text())
                now = time.monotonic()
                if generation != previous:
                    apply()
                    previous = generation
                    deadline = now + theme['rotation_seconds']
                elif now >= deadline:
                    wallpaper()
                    deadline = now + theme['rotation_seconds']
            except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
                print('ubuntu-theme: ' + str(error), file=sys.stderr, flush=True)
            time.sleep(poll)


def rotate(poll):
    if not in_session():
        raise ValueError('Wallpaper rotation requires a Hyprland session')
    state = CONFIG / 'desktop-theme'
    state.mkdir(parents=True, exist_ok=True)
    with (state / '.ubuntu-rotate.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        # Keep the wallpaper Caelestia restored at login for one full interval.
        deadline = None
        while in_session():
            try:
                command('hyprctl', 'version')
            except (OSError, subprocess.SubprocessError):
                return
            try:
                if deadline is None:
                    deadline = time.monotonic() + rotation()[0]
                elif time.monotonic() >= deadline:
                    wallpaper()
                    deadline = time.monotonic() + rotation()[0]
            except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
                print('ubuntu-theme: ' + str(error), file=sys.stderr, flush=True)
                deadline = time.monotonic() + 60
            time.sleep(poll)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['apply', 'wallpaper', 'watch', 'rotate'])
    parser.add_argument('--poll', type=int, default=15, help='Watcher polling interval, at least 5 seconds')
    args = parser.parse_args()
    if args.poll < 5:
        parser.error('--poll must be at least 5')
    if args.action in ('watch', 'rotate'):
        globals()[args.action](args.poll)
    else:
        globals()[args.action]()


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print('ubuntu-theme: ' + str(error), file=sys.stderr)
        sys.exit(1)
