#!/usr/bin/env python3
"""Recover the desktop shell from crashes and monitor layout changes."""
import fcntl
import json
import logging
from logging.handlers import RotatingFileHandler
import math
import os
import select
from pathlib import Path
import signal
import subprocess
import sys
import threading
import time

SESSION_PIDFD = None


def monitor_layout():
    try:
        monitors = json.loads(subprocess.check_output(
            ['hyprctl', '-j', 'monitors'], text=True, stderr=subprocess.DEVNULL, timeout=2))
        if not isinstance(monitors, list) or any(not isinstance(m, dict) for m in monitors):
            return None
        layout = []
        for monitor in monitors:
            if type(monitor.get('disabled', False)) is not bool:
                return None
            if monitor.get('disabled'):
                continue
            name = monitor['name']
            geometry = (monitor['x'], monitor['y'], monitor['width'], monitor['height'],
                        monitor.get('scale', 1))
            transform = monitor.get('transform', 0)
            if not isinstance(name, str) or not name:
                return None
            if any(type(value) not in (int, float) or not math.isfinite(value) for value in geometry):
                return None
            if any(value <= 0 for value in geometry[2:]) or type(transform) is not int or not 0 <= transform <= 7:
                return None
            layout.append((name, *geometry, transform))
        return tuple(sorted(layout))
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError, OverflowError):
        # Invalid IPC must not be mistaken for a disconnected monitor.
        return None


def refresh_monitor_layout():
    try:
        # Reapply live monitor rules; a full config reload would discard runtime
        # scale/resolution changes made with `hyprctl keyword monitor`.
        result = subprocess.check_output(['hyprctl', 'dispatch', 'forcerendererreload'], text=True,
                                         stderr=subprocess.DEVNULL, timeout=5)
        if result.strip() == 'ok':
            return True
    except (OSError, subprocess.SubprocessError):
        pass
    logging.warning('Monitor refresh failed; keeping the shell and retrying')
    return False


def session_alive():
    if SESSION_PIDFD is not None:
        # A slow compositor can time out IPC while its session is still alive.
        # pidfds also avoid confusing a reused PID with the original session.
        return not select.select([SESSION_PIDFD], [], [], 0)[0]
    try:
        result = subprocess.run(['hyprctl', '-j', 'monitors'], stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, timeout=5)
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def stop_child(child):
    # Each shell owns a process group, including any helpers it spawned.
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        child.wait(timeout=3)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    child.wait()


def supervise(command, stopped):
    delay = 2
    # Keep monitor recovery state when a hotplug also crashes the shell.
    layout = monitor_layout()
    # An unknown initial layout needs settled recovery before it becomes the baseline.
    pending_layout = None
    pending_since = time.monotonic()
    next_layout_check = pending_since + 1
    while not stopped.is_set() and session_alive():
        started = time.monotonic()
        layout_changed = False
        logging.info('Starting desktop shell')
        try:
            child = subprocess.Popen(command, start_new_session=True)
        except OSError:
            logging.exception('Cannot start desktop shell')
        else:
            try:
                while child.poll() is None and not stopped.wait(0.5):
                    if not session_alive():
                        logging.info('Hyprland process ended; stopping desktop shell')
                        stopped.set()
                        break
                    now = time.monotonic()
                    if now < next_layout_check:
                        continue
                    next_layout_check = now + 1
                    observed = monitor_layout()
                    if observed is None:
                        pending_layout = None
                    elif not observed:
                        # A temporary zero-output state needs recovery even
                        # when the same display reconnects at the same position.
                        layout = ()
                        pending_layout = None
                    elif observed == layout:
                        pending_layout = None
                    elif observed != pending_layout:
                        pending_layout = observed
                        pending_since = now
                    elif now - pending_since >= 1 and refresh_monitor_layout():
                        logging.info('Monitor layout settled; recreating desktop surfaces')
                        layout = observed
                        pending_layout = None
                        layout_changed = True
                        break
            finally:
                stop_child(child)
            if stopped.is_set():
                break
            if layout_changed:
                delay = 2
                continue
            logging.warning('Desktop shell exited (status %s)', child.returncode)
        if time.monotonic() - started >= 60:
            delay = 2
        logging.info('Retrying in %s seconds', delay)
        if stopped.wait(delay):
            break
        delay = min(delay * 2, 30)
    logging.info('Desktop shell supervision stopped')


def main():
    global SESSION_PIDFD
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    signature = os.environ['HYPRLAND_INSTANCE_SIGNATURE']
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'dotfiles'
    state.mkdir(parents=True, exist_ok=True)
    handler = RotatingFileHandler(state / 'desktop-shell-watch.log', maxBytes=256 * 1024, backupCount=2)
    logging.basicConfig(level=logging.INFO, handlers=[handler],
                        format='%(asctime)s %(levelname)s %(message)s')
    session_lock = runtime / 'hypr' / signature / 'hyprland.lock'
    if session_lock.exists():
        try:
            session_info = session_lock.read_text().splitlines()
            pid = int(session_info[0])
            SESSION_PIDFD = os.pidfd_open(pid)
            if len(session_info) > 1:
                os.environ['WAYLAND_DISPLAY'] = session_info[1]
        except ProcessLookupError:
            logging.info('Hyprland already exited')
            return 1 if sys.argv[1:] == ['--check-session'] else 0
    if sys.argv[1:] == ['--check-session']:
        return 0 if SESSION_PIDFD is not None and session_alive() else 1
    command = [str(Path(__file__).with_name('ubuntu-desktop-shell.sh')), 'run']
    # An alternate command allows integration tests with a real child process.
    if len(sys.argv) > 1:
        if sys.argv[1] != '--' or len(sys.argv) < 3:
            raise SystemExit('Usage: ubuntu-desktop-watch.py [-- command ...]')
        command = sys.argv[2:]
    stopped = threading.Event()
    def request_stop(signum, _frame):
        logging.info('Received signal %s; stopping supervision', signum)
        stopped.set()

    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, request_stop)
    with (runtime / f'dotfiles-desktop-watch-{signature}.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        supervise(command, stopped)


if __name__ == '__main__':
    sys.exit(main())
