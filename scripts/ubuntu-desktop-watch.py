#!/usr/bin/env python3
"""Restart the desktop shell while its Hyprland session exists."""
import fcntl
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
import time


def session_alive():
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
    while not stopped.is_set() and session_alive():
        started = time.monotonic()
        logging.info('Starting desktop shell')
        try:
            child = subprocess.Popen(command, start_new_session=True)
        except OSError:
            logging.exception('Cannot start desktop shell')
        else:
            try:
                while child.poll() is None and not stopped.wait(0.5):
                    if not session_alive():
                        stopped.set()
            finally:
                stop_child(child)
            if stopped.is_set():
                break
            logging.warning('Desktop shell exited (status %s)', child.returncode)
        if time.monotonic() - started >= 60:
            delay = 2
        logging.info('Retrying in %s seconds', delay)
        if stopped.wait(delay):
            break
        delay = min(delay * 2, 30)
    logging.info('Desktop shell supervision stopped')


def main():
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    signature = os.environ['HYPRLAND_INSTANCE_SIGNATURE']
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'dotfiles'
    state.mkdir(parents=True, exist_ok=True)
    handler = RotatingFileHandler(state / 'desktop-shell-watch.log', maxBytes=256 * 1024, backupCount=2)
    logging.basicConfig(level=logging.INFO, handlers=[handler],
                        format='%(asctime)s %(levelname)s %(message)s')
    command = [str(Path(__file__).with_name('ubuntu-desktop-shell.sh')), 'run']
    # An alternate command allows integration tests with a real child process.
    if len(sys.argv) > 1:
        if sys.argv[1] != '--' or len(sys.argv) < 3:
            raise SystemExit('Usage: ubuntu-desktop-watch.py [-- command ...]')
        command = sys.argv[2:]
    stopped = threading.Event()
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, lambda *_: stopped.set())
    with (runtime / f'dotfiles-desktop-watch-{signature}.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        supervise(command, stopped)


if __name__ == '__main__':
    main()
