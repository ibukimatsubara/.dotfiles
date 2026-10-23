#!/usr/bin/env python3
"""Open the daily dashboard after the desktop is ready, in a fixed tile layout."""
import configparser
import fcntl
import json
import logging
import os
from pathlib import Path
import shlex
import struct
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


def ipc_ok(*commands):
    result = ipc('--batch', '; '.join(commands))
    if any(line.strip() != 'ok' for line in result.splitlines() if line.strip()):
        raise RuntimeError(f'Hyprland batch: {result}')


def clients():
    return json.loads(ipc('-j', 'clients'))


def identify(client):
    cls, title = client.get('class', ''), client.get('title', '')
    if cls == 'zen':
        return 'browser'
    # Keep recognizing windows opened by earlier versions of this helper.
    if cls in ('com.dotfiles.pomoru', 'dotfiles-pomoru'):
        return 'pomoru'
    if cls in ('com.dotfiles.music', 'dotfiles-music'):
        return 'music'
    if cls == 'com.dotfiles.status':
        return 'status'
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
    """Repair only unfinished placement; preserve existing tiles."""
    for client in windows.values():
        address = client['address']
        if client.get('floating'):
            # In Hyprland 0.53, settiled moves a floating window to the active
            # workspace. Move it back in the same IPC batch, without focusing it.
            ipc_ok(f'dispatch settiled address:{address}',
                   f'dispatch movetoworkspacesilent 1,address:{address}')
        elif client['workspace']['id'] != 1:
            dispatch('movetoworkspacesilent', f'1,address:{address}')


# Dwindle splits the focused tile toward the preselected side. Anchoring each
# launch on pomoru yields: browser | (pomoru / music) | status.
ORDER = ('pomoru', 'browser', 'status', 'music')
SPLITS = {'browser': 'l', 'status': 'r', 'music': 'd'}
# One third for the browser column; dwindle sizes the first child as ratio / 2.
BROWSER_RATIO = 0.667
# Zen restores its last session on startup, so a cold launch with only the URL
# adds a tab to the restored window instead of opening a second window.
BROWSER_URL = 'https://chatgpt.com/dots/home'
ZEN_CONFIG = Path.home() / '.config/zen'
STATUS_BOARD = Path.home() / 'Mibuki/mibuki-status-board'
# Stop waiting for an app that never maps so the remaining tiles still open.
LAUNCH_WAIT = 20


def lz4_block(src):
    """Decode one LZ4 block; Zen stores its session as mozlz4."""
    dst, i = bytearray(), 0
    while i < len(src):
        token = src[i]
        i += 1
        length = token >> 4
        if length == 15:
            while src[i] == 255:
                length += 255
                i += 1
            length += src[i]
            i += 1
        dst += src[i:i + length]
        i += length
        if i >= len(src):
            break
        offset = src[i] | src[i + 1] << 8
        i += 2
        length = token & 15
        if length == 15:
            while src[i] == 255:
                length += 255
                i += 1
            length += src[i]
            i += 1
        for _ in range(length + 4):
            dst.append(dst[-offset])
    return bytes(dst)


def read_mozlz4(path):
    data = path.read_bytes()
    if data[:8] != b'mozLz40\0':
        raise ValueError(f'Not a mozlz4 file: {path}')
    decoded = lz4_block(data[12:])
    if len(decoded) != struct.unpack('<I', data[8:12])[0]:
        raise ValueError(f'Truncated mozlz4 file: {path}')
    return json.loads(decoded)


def zen_session_urls():
    """Return the current URL of every tab Zen will restore on its next start."""
    installs = configparser.ConfigParser(interpolation=None)
    installs.read(ZEN_CONFIG / 'installs.ini')
    profile = ZEN_CONFIG / next(section['Default'] for section in installs.values() if 'Default' in section)
    # The order Firefox restores from: a clean shutdown, then crash recovery.
    candidates = [profile / 'sessionstore.jsonlz4', profile / 'sessionstore-backups/recovery.jsonlz4',
                  profile / 'sessionstore-backups/recovery.baklz4']
    session = next((path for path in candidates if path.exists()), candidates[0])
    tabs = [tab for window in read_mozlz4(session).get('windows', [])
            for tab in window.get('tabs', [])]
    zen_sessions = profile / 'zen-sessions.jsonlz4'
    if zen_sessions.exists():
        tabs += read_mozlz4(zen_sessions).get('tabs', [])
    urls = set()
    for tab in tabs:
        entries = tab.get('entries') or [{}]
        urls.add(entries[min(max(tab.get('index', len(entries)), 1), len(entries)) - 1].get('url', ''))
    return urls


def browser_command(command, zen_running):
    if zen_running:
        # A running Zen would add the URL as a tab without a window.
        # Its process owns the new window, so the exec rules do not
        # apply; it opens on the focused Space 1 and arrange() moves
        # it there if it lands elsewhere.
        return [*command, '--new-window', BROWSER_URL]
    try:
        # Restoring a session that already has the page would duplicate the
        # tab on every login, so only pass the URL when it is missing.
        if any(url.startswith(BROWSER_URL) for url in zen_session_urls()):
            return command
    except Exception as error:  # A malformed session must not stop the dashboard.
        logging.warning('Could not read the Zen session; opening %s: %s', BROWSER_URL, error)
    return [*command, BROWSER_URL]


def scan(baseline, state):
    found = {}
    current = clients()
    # Release a claimed browser that closed so a replacement can be claimed.
    if state.get('browser') not in {c['address'] for c in current}:
        state['browser'] = None
    for client in current:
        name = identify(client)
        if not name or not client.get('mapped', True):
            continue
        if name == 'browser':
            # Reuse a browser already on workspace 1. Otherwise only the first
            # Zen window opened by this run's launch is the dashboard tile;
            # other Zen windows stay unclaimed.
            if client['address'] in baseline:
                if client['workspace']['id'] != 1:
                    continue
            elif state.get('browser') is None and 'browser' in state['launched']:
                state['browser'] = client['address']
            elif client['address'] != state.get('browser'):
                continue
        found.setdefault(name, client)
    return found


def finish(existing, state, prior_focus, complete):
    """Size a freshly built layout, then hand focus back to the user."""
    # Clear a direction left pending by an app that never mapped, so it cannot
    # redirect the next window the user opens.
    batch = ['dispatch layoutmsg preselect x']
    browser = existing.get('browser', {}).get('address')
    if complete and browser and not state['late']:
        batch += [f'dispatch focuswindow address:{browser}',
                  f'dispatch splitratio exact {BROWSER_RATIO}']
    ours = {c['address'] for c in existing.values()}
    alive = {c['address'] for c in clients()}
    if prior_focus and prior_focus not in ours and prior_focus in alive:
        batch.append(f'dispatch focuswindow address:{prior_focus}')
    elif browser:
        batch.append(f'dispatch focuswindow address:{browser}')
    ipc_ok(*batch)


def start():
    wait_for_desktop()
    commands = {
        'pomoru': [str(SCRIPTS / 'ubuntu-app-launch.sh'), 'ghostty',
                   '--class=com.dotfiles.pomoru', '-e', 'pomoru'],
        'browser': [str(SCRIPTS / 'ubuntu-app-launch.sh'), 'zen'],
        # Fall back to a shell in the board's directory after quitting it.
        # Ghostty ignores --working-directory for -e commands, so cd first.
        'status': [str(SCRIPTS / 'ubuntu-app-launch.sh'), 'ghostty', '--class=com.dotfiles.status', '-e', 'zsh', '-c',
                   f'cd {shlex.quote(str(STATUS_BOARD))} && ./mibuki-status-board; exec zsh'],
        'music': [str(SCRIPTS / 'ubuntu-app-launch.sh'), 'ghostty',
                  '--class=com.dotfiles.music', '-e', str(SCRIPTS / 'music-player.sh')],
    }
    state = {'launched': {}, 'late': set(), 'browser': None}
    existing = {}
    built = False
    try:
        build(commands, state, existing)
        built = True
    finally:
        # Focus moved only if something was launched; hand it back even when
        # an app never appeared and the build timed out.
        if state['launched']:
            restore(state, built)


def restore(state, built):
    complete = built and set(state['launched']) == set(ORDER)
    for attempt in range(3):
        try:
            existing = scan(state.get('baseline', set()), state)
            finish(existing, state, state.get('prior_focus'), complete)
            return
        except IPC_ERRORS as error:
            logging.warning('Restoring focus after startup will retry: %s', error)
            time.sleep(0.5)
        except Exception:
            # Keep the startup error that is already propagating.
            logging.exception('Could not restore focus after startup')
            return


def build(commands, state, existing):
    launched = state['launched']
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        try:
            if 'baseline' not in state:
                snapshot = clients()
                baseline = {c['address'] for c in snapshot}
                state['zen_running'] = any(identify(c) == 'browser' for c in snapshot)
                state['prior_focus'] = json.loads(ipc('-j', 'activewindow') or '{}').get('address')
                state['baseline'] = baseline
            # Re-read addresses on every pass: a client can close or be replaced
            # while Zen or a terminal application is still starting.
            existing.clear()
            existing.update(scan(state['baseline'], state))
            if len(existing) == len(ORDER) and all(c['workspace']['id'] == 1 and not c.get('floating')
                                                   for c in existing.values()):
                logging.info('Space 1 dashboard ready' + ('' if launched else '; preserving current tile layout'))
                return
            arrange(existing)
            # Open one app at a time: each tile must split the anchor before
            # the next app maps, or dwindle picks the split target itself.
            # Another window mapping in that gap can still take the split.
            now = time.monotonic()
            state['late'] |= {n for n, when in launched.items() if n not in existing and now - when >= LAUNCH_WAIT}
            waiting = any(n not in existing and now - when < LAUNCH_WAIT for n, when in launched.items())
            name = None if waiting else next((n for n in ORDER if n not in existing and n not in launched), None)
            if name is not None:
                if name != 'pomoru' and 'pomoru' in existing:
                    ipc_ok(f'dispatch focuswindow address:{existing["pomoru"]["address"]}',
                           f'dispatch layoutmsg preselect {SPLITS[name]}')
                # A timeout can lose the reply after exec was accepted. Mark it
                # pending before dispatch so the next pass waits for the window
                # instead of starting a duplicate.
                command = commands[name]
                if name == 'browser':
                    command = browser_command(command, state['zen_running'])
                launched[name] = now
                try:
                    dispatch('exec', '[workspace 1 silent; tile; no_initial_focus on] '
                             + shlex.join(command))
                except subprocess.CalledProcessError as error:
                    # hyprctl 0.53 exits 1-4 before writing the request
                    # (socket setup, missing instance, connection failure).
                    # Exit 6 means reading the reply failed after submission.
                    if error.returncode in (1, 2, 3, 4):
                        del launched[name]
                    raise
                except (OSError, RuntimeError):
                    # The local client could not run, or Hyprland explicitly
                    # rejected exec: these failures are safe to resubmit.
                    del launched[name]
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
