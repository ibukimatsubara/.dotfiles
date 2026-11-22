#!/usr/bin/env python3
"""Print physical key presses, clicks and wheel turns as JSON lines for the keycast overlay.

Reads /dev/input directly (the user must be in the input group). Each line is
{"text": "Ctrl+Shift+T", "time": "12:34:56.789"} using the kernel's event time.
"""
import json
import os
from pathlib import Path
import re
import selectors
import socket
import struct
import subprocess
import sys
import time

EVENT = struct.Struct('llHHi')
EV_KEY, EV_REL = 1, 2
REL_HWHEEL, REL_WHEEL = 6, 8
# Modifiers are shown as a prefix of the next key, or alone when released unused.
MODIFIERS = {29: 'Ctrl', 97: 'Ctrl', 42: 'Shift', 54: 'Shift', 56: 'Alt', 100: 'AltGr', 125: 'Super', 126: 'Super'}
ORDER = ['Ctrl', 'Super', 'Alt', 'AltGr', 'Shift']
NAMES = {
    'ESC': 'Esc', 'BACKSPACE': '⌫', 'TAB': 'Tab', 'ENTER': '⏎', 'KPENTER': '⏎', 'SPACE': 'Space',
    'CAPSLOCK': 'Caps', 'UP': '↑', 'DOWN': '↓', 'LEFT': '←', 'RIGHT': '→', 'PAGEUP': 'PgUp',
    'PAGEDOWN': 'PgDn', 'DELETE': 'Del', 'INSERT': 'Ins', 'MINUS': '-', 'EQUAL': '=',
    'LEFTBRACE': '[', 'RIGHTBRACE': ']', 'SEMICOLON': ';', 'APOSTROPHE': "'", 'GRAVE': '`',
    'BACKSLASH': '\\', 'BTN_MOUSE': 'Click L', 'COMMA': ',', 'DOT': '.', 'SLASH': '/', 'BTN_LEFT': 'Click L',
    'BTN_RIGHT': 'Click R', 'BTN_MIDDLE': 'Click M', 'BTN_SIDE': 'Click Back', 'BTN_EXTRA': 'Click Fwd',
}


def key_names():
    # Kernel names such as KEY_A or BTN_LEFT, from the installed UAPI header.
    names = {}
    header = Path('/usr/include/linux/input-event-codes.h').read_text()
    for name, code in re.findall(r'#define\s+((?:KEY|BTN)_\w+)\s+(0x[0-9a-fA-F]+|\d+)\b', header):
        names.setdefault(int(code, 0), name)
    return names


def label(code, names):
    name = names.get(code, str(code))
    short = name[4:] if name.startswith('KEY_') else name
    return NAMES.get(short, NAMES.get(name, short.capitalize() if len(short) > 1 else short))


def swapped_keyboards():
    # Mirror Hyprland's ctrl:swap_lwin_lctl so the overlay shows what the desktop received.
    try:
        devices = json.loads(subprocess.run(['hyprctl', '-j', 'devices'], capture_output=True, text=True, timeout=5).stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return set()
    return {k['name'] for k in devices.get('keyboards', []) if 'ctrl:swap_lwin_lctl' in k.get('options', '')}


def devices():
    # Physical keyboards (they have KEY_A) and pointers with a wheel or left button.
    found = {}
    for block in Path('/proc/bus/input/devices').read_text().split('\n\n'):
        name = re.search(r'^N: Name="(.*)"$', block, re.M)
        node = re.search(r'\bevent(\d+)\b', block)
        if not name or not node or name.group(1).startswith('ydotoold'):
            continue
        keys = re.search(r'^B: KEY=(.*)$', block, re.M)
        rel = re.search(r'^B: REL=(\w+)$', block, re.M)
        bits = 0
        for word in (keys.group(1).split() if keys else []):
            bits = (bits << 64) | int(word, 16)
        if bits >> 30 & 1 or bits >> 0x110 & 1 or (rel and int(rel.group(1), 16) >> REL_WHEEL & 1):
            found['/dev/input/event' + node.group(1)] = name.group(1).lower().replace(' ', '-')
    return found


def emit(text, seconds, micros):
    stamp = time.strftime('%H:%M:%S', time.localtime(seconds)) + '.%03d' % (micros // 1000)
    print(json.dumps({'text': text, 'time': stamp}, ensure_ascii=False), flush=True)


def screen_locked(lock_path=None, proc_root=Path('/proc'), uid=None, hypr_socket=None):
    # flock would take an unlocked file and make hyprlock's flock -n fail. Match the hold instead.
    if uid is None:
        uid = os.getuid()
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    if lock_path is None and runtime:
        lock_path = Path(runtime) / 'dotfiles-hyprlock.lock'
    if hypr_socket is None:
        sig = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
        if runtime and sig:
            hypr_socket = Path(runtime) / 'hypr' / sig / '.socket.sock'
    # Hyprland owns ext-session-lock-v1, so a live socket covers hyprlock and DMS; scan /proc only if it is unreachable.
    hypr_socket_ok = False
    if hypr_socket is not None:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.settimeout(0.2)
                sock.connect(os.fspath(hypr_socket))
                sock.sendall(b'locked')
                reply = sock.recv(64).strip(b'\x00\r\n\t ')
        except OSError:
            reply = None
        if reply == b'true':
            return True
        hypr_socket_ok = reply == b'false'
    if lock_path is not None:
        try:
            st = Path(lock_path).stat()
        except OSError:
            st = None
        if st is not None:
            token = f'{os.major(st.st_dev):02x}:{os.minor(st.st_dev):02x}:{st.st_ino}'
            try:
                locks = Path('/proc/locks').read_text()
            except OSError:
                locks = ''
            for line in locks.splitlines():
                parts = line.split()
                if len(parts) >= 6 and parts[1] == 'FLOCK' and parts[5] == token:
                    return True
    if hypr_socket_ok:
        return False
    try:
        entries = proc_root.iterdir()
    except OSError:
        return False
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            # Another session's hyprlock is not this screen.
            if entry.stat().st_uid != uid:
                continue
            # comm is capped at 15 bytes and may end mid-codepoint.
            comm = (entry / 'comm').read_bytes().strip()
        except OSError:
            continue
        if comm == b'hyprlock':
            return True
    return False


def drain_handles(handles):
    dead = []
    for handle in handles:
        while True:
            try:
                chunk = handle.read(EVENT.size * 64)
            except BlockingIOError:
                break
            except OSError:
                dead.append(handle)
                break
            # FileIO.read returns None, not BlockingIOError, when a non-blocking fd would block.
            if not chunk:
                break
    return dead


def has_displayable_event(data):
    for offset in range(0, len(data) - len(data) % EVENT.size, EVENT.size):
        _, _, kind, code, value = EVENT.unpack_from(data, offset)
        if kind == EV_KEY or (kind == EV_REL and code in (REL_WHEEL, REL_HWHEEL) and value):
            return True
    return False


class EventState:
    def __init__(self, names):
        self.names = names
        self.held = set()
        self.pending = None  # A modifier combination pressed with no other key yet.
        self.locked = False
        self.unlocked_at = None

    def sync_lock(self, locked, now=None):
        locked = bool(locked)
        unlocked = self.locked and not locked
        if locked and not self.locked:
            self.held.clear()
            self.pending = None
            print(json.dumps({'clear': True}), flush=True)
        elif unlocked:
            self.held.clear()
            self.pending = None
            self.unlocked_at = time.time() if now is None else now
        self.locked = locked
        return unlocked

    def process_handle(self, handle, device, swapped, locked):
        data = handle.read(EVENT.size * 64) or b''
        if locked:
            self.held.clear()
            self.pending = None
            return
        self.apply(data, device, swapped)

    def apply(self, data, device, swapped):
        for offset in range(0, len(data) - len(data) % EVENT.size, EVENT.size):
            seconds, micros, kind, code, value = EVENT.unpack_from(data, offset)
            # Kernel time can predate unlock; ignore those so a password cannot replay.
            if self.unlocked_at is not None and seconds + micros / 1_000_000 <= self.unlocked_at:
                continue
            if kind == EV_REL and code in (REL_WHEEL, REL_HWHEEL) and value:
                arrow = ('↑' if value > 0 else '↓') if code == REL_WHEEL else ('→' if value > 0 else '←')
                for _ in range(abs(value)):
                    emit('Wheel ' + arrow, seconds, micros)
                continue
            if kind != EV_KEY:
                continue
            if device in swapped and code in (29, 125):
                code = 154 - code
            modifier = MODIFIERS.get(code)
            if modifier:
                if value == 1:
                    self.held.add(modifier)
                    self.pending = set(self.held)
                elif value == 0:
                    if self.pending and modifier in self.pending:
                        emit('+'.join(m for m in ORDER if m in self.pending), seconds, micros)
                    self.held.discard(modifier)
                    self.pending = None
                continue
            if value == 0:
                continue
            self.pending = None
            text = label(code, self.names)
            prefix = [m for m in ORDER if m in self.held]
            if len(text) == 1 and text.isalpha():
                # Letters read as typed: lowercase, or uppercase with Shift alone.
                if prefix == ['Shift']:
                    prefix = []
                elif not prefix:
                    text = text.lower()
            # Held-key repeats print the same text, which the overlay counts as ×N.
            emit('+'.join(prefix + [text]), seconds, micros)


def main():
    names = key_names()
    state = EventState(names)
    selector = selectors.DefaultSelector()
    opened = {}
    rescan = 0
    swapped = set()
    next_lock_check = 0

    def close_dead(handles):
        for handle in handles:
            selector.unregister(handle)
            opened.pop(handle.name, None)
            handle.close()

    while True:
        now_mono = time.monotonic()
        if now_mono >= next_lock_check:
            if state.sync_lock(screen_locked()):
                close_dead(drain_handles(list(opened.values())))
            next_lock_check = now_mono + 0.25
        if now_mono >= rescan:
            swapped = swapped_keyboards()
            for path, device in devices().items():
                if path not in opened:
                    try:
                        handle = open(path, 'rb', buffering=0)
                    except OSError as error:
                        print('keycast: ' + str(error), file=sys.stderr, flush=True)
                        continue
                    os.set_blocking(handle.fileno(), False)
                    opened[path] = handle
                    selector.register(handle, selectors.EVENT_READ, device)
            rescan = time.monotonic() + 3
        for key, _ in selector.select(timeout=0.25):
            handle, device = key.fileobj, key.data
            try:
                data = handle.read(EVENT.size * 64) or b''
            except OSError:
                # Unplugged: forget it and pick it up again on the next rescan.
                close_dead([handle])
                continue
            # Pointer motion is not shown; asking Hyprland on every batch pegs a core.
            if not state.locked and not has_displayable_event(data):
                continue
            if state.sync_lock(screen_locked()):
                close_dead(drain_handles(list(opened.values())))
            if state.locked:
                continue
            state.apply(data, device, swapped)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
