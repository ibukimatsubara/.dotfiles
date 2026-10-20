#!/usr/bin/env python3
"""Forward a paste shortcut that suits the focused window.

Ghostty maps SHIFT+Insert to its own native paste action, so image payloads in
Ghostty are delivered to the terminal CLI as a temporary PNG file path: the
clipboard is switched to text/plain holding that path, SHIFT+Insert is
dispatched, and the original clipboard image is restored as soon as the
terminal has read the path. Codex recognises the bracketed image path and
attaches the file. Every other situation keeps the ordinary CTRL+V paste.
"""
import json
import os
import subprocess
import sys
import tempfile
import time

GHOSTTY_CLASSES = {'com.mitchellh.ghostty', 'ghostty'}
IMAGE_TYPE = 'image/png'
TEXT_TYPE = 'text/plain'
CMD_TIMEOUT = 3
# Time allowed for the asynchronous terminal paste to read the path.
PASTE_SETTLE_SECONDS = 0.25


def run(args, stdin_data=b''):
    """Run a helper command with a bounded timeout, never raising."""
    try:
        return subprocess.run(args, input=stdin_data, capture_output=True,
                              timeout=CMD_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return None


def succeeded(result):
    return result is not None and result.returncode == 0


def active_window_class():
    """Return the lowercased class of the active window, or None."""
    result = run(['hyprctl', '-j', 'activewindow'])
    if not succeeded(result):
        return None
    try:
        window = json.loads(result.stdout)
    except ValueError:
        return None
    if not isinstance(window, dict):
        return None
    window_class = window.get('class')
    if not isinstance(window_class, str):
        return None
    return window_class.strip().lower()


def clipboard_types():
    """Return the advertised clipboard MIME types, or None on failure."""
    result = run(['wl-paste', '--list-types'])
    if not succeeded(result):
        return None
    text = result.stdout.decode('utf-8', 'replace')
    return [line.strip().lower() for line in text.splitlines()
            if line.strip()]


def read_clipboard(mime):
    """Return the raw clipboard bytes for one MIME type, or None."""
    result = run(['wl-paste', '--type', mime])
    if not succeeded(result):
        return None
    return result.stdout


def write_clipboard(mime, data):
    """Replace the clipboard with raw bytes of one MIME type.

    Real wl-copy forks a persistent clipboard-owner process that inherits its
    parent's stdout/stderr. Capturing those pipes would make us wait for the
    owner (and eventually time out) even though the copy already succeeded, so
    wl-copy's output is detached instead: its binary stdin is still fed via
    input (which already sets up the stdin pipe), and only the short-lived
    parent process is bounded by CMD_TIMEOUT.
    """
    try:
        result = subprocess.run(['wl-copy', '--type', mime], input=data,
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL,
                                timeout=CMD_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return False
    return result.returncode == 0


def save_image(png):
    """Write the PNG to a private temp file that outlives this script."""
    handle, path = tempfile.mkstemp(prefix='sofle-paste-', suffix='.png')
    try:
        os.fchmod(handle, 0o600)
    except OSError:
        pass
    with os.fdopen(handle, 'wb') as stream:
        stream.write(png)
    return path


def send_shortcut(shortcut):
    """Dispatch one Hyprland shortcut, returning True on success."""
    return succeeded(
        run(['hyprctl', 'dispatch', 'sendshortcut', shortcut]))


def clipboard_still_has_path(path):
    """True when the clipboard text is exactly the temporary path."""
    current = read_clipboard(TEXT_TYPE)
    if not current:
        return False
    # wl-paste may append a trailing newline to text payloads.
    return current.rstrip(b'\r\n') == path.encode('utf-8', 'replace')


def restore_image(png, path):
    """Put the original image back unless the user copied something new."""
    if not clipboard_still_has_path(path):
        return False
    return write_clipboard(IMAGE_TYPE, png)


def paste_image():
    """Try the Ghostty image route; return True when it handled the paste."""
    types = clipboard_types()
    if not types or IMAGE_TYPE not in types:
        return False
    png = read_clipboard(IMAGE_TYPE)
    if not png:
        return False
    try:
        path = save_image(png)
    except OSError:
        return False
    if not write_clipboard(TEXT_TYPE, path.encode('utf-8', 'replace')):
        return False
    dispatched = send_shortcut('SHIFT,Insert,')
    # Let the terminal finish its asynchronous read of the clipboard path.
    time.sleep(PASTE_SETTLE_SECONDS)
    restore_image(png, path)
    if not dispatched:
        send_shortcut('CTRL,V,')
    return True


def main():
    if (active_window_class() in GHOSTTY_CLASSES and paste_image()):
        return 0
    send_shortcut('CTRL,V,')
    return 0


if __name__ == '__main__':
    sys.exit(main())
