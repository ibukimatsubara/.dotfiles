#!/usr/bin/env python3
"""Remap the four buttons of a Kensington SlimBlade Pro without losing clicks or drag."""

from __future__ import annotations

import argparse
import asyncio
from dataclasses import dataclass
import enum
import errno
import fcntl
import logging
import os
from pathlib import Path
import signal
import stat
import string
import sys
import time
import tomllib

LOG = logging.getLogger('kensington-mouse')
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / 'platforms/ubuntu/kensington-mouse.toml'

EV_SYN = 0
EV_KEY = 1
EV_REL = 2
SYN_REPORT = 0
SYN_DROPPED = 3
REL_X = 0
REL_Y = 1

BTN_LEFT = 272
BTN_RIGHT = 273
BTN_MIDDLE = 274
KEY_ESC = 1
KEY_ENTER = 28

BUTTON_NAMES = ('top_left', 'top_right', 'bottom_left', 'bottom_right')
BOTTOM_CLICKS = {'bottom_left': BTN_LEFT, 'bottom_right': BTN_RIGHT}
SINGLE_ACTIONS = {'top_left': 'focus_left', 'top_right': 'focus_right'}
PAIR_ACTIONS = {
    frozenset(('top_left', 'bottom_left')): 'workspace_previous',
    frozenset(('top_right', 'bottom_right')): 'workspace_next',
    frozenset(('top_left', 'top_right')): 'voice_toggle',
    frozenset(('bottom_left', 'bottom_right')): 'middle_click',
    frozenset(('top_left', 'bottom_right')): 'enter',
    frozenset(('top_right', 'bottom_left')): 'escape',
}
COMMAND_ACTIONS = ('focus_left', 'focus_right', 'workspace_previous', 'workspace_next', 'voice_toggle')

POINTER_NAME = 'Dotfiles Kensington Pointer'
KEYBOARD_NAME = 'Dotfiles Kensington Keyboard'
SELF_NAMES = frozenset((POINTER_NAME, KEYBOARD_NAME))
VIRTUAL_VENDOR = 0x6473
VIRTUAL_POINTER_PRODUCT = 0x0001
VIRTUAL_KEYBOARD_PRODUCT = 0x0002

SCAN_INTERVAL = 1.0
SESSION_INTERVAL = 0.5
COMMAND_TIMEOUT = 5.0
STARTUP_DRAIN_LIMIT = 65536


@dataclass(frozen=True)
class Emit:
    type: int
    code: int
    value: int


@dataclass(frozen=True)
class Invoke:
    action: str


class _State(enum.Enum):
    IDLE = 'idle'
    PENDING = 'pending'
    HELD = 'held'
    DRAIN = 'drain'


class ChordEngine:
    """Turn physical four-button input into ordered output effects."""

    def __init__(self, buttons, hold_ms=120):
        if set(buttons) != set(BUTTON_NAMES):
            raise ValueError('buttons must name exactly top_left, top_right, bottom_left and bottom_right')
        codes = list(buttons.values())
        if any(type(code) is not int for code in codes) or len(set(codes)) != len(codes):
            raise ValueError('button codes must be unique integers')
        if type(hold_ms) not in (int, float) or hold_ms < 0:
            raise ValueError('hold_ms must be a non-negative number')
        self._buttons = dict(buttons)
        self._names = {code: name for name, code in self._buttons.items()}
        self._hold = hold_ms / 1000.0
        self._state = _State.IDLE
        self._pressed = {}
        self._single = None
        self._pair = None
        self._partial = False
        self._started = 0.0
        self._held = None

    def feed(self, type, code, value, now):
        name = self._names.get(code)
        if type == EV_KEY and name is not None:
            if value == 1:
                return self._press(name, code, now)
            if value == 0:
                return self._release(name, code)
            return []
        if (type == EV_REL and code in (REL_X, REL_Y) and value != 0
                and self._single_bottom()):
            self._state = _State.HELD
            self._held = self._single
            return [Emit(EV_KEY, BOTTOM_CLICKS[self._held], 1), Emit(type, code, value)]
        return [Emit(type, code, value)]

    def tick(self, now):
        if self._single_bottom() and now - self._started >= self._hold:
            self._state = _State.HELD
            self._held = self._single
            return [Emit(EV_KEY, BOTTOM_CLICKS[self._held], 1)]
        return []

    def hold_deadline(self):
        return self._started + self._hold if self._single_bottom() else None

    def reset(self):
        effects = []
        if self._state is _State.HELD and self._held is not None:
            effects.append(Emit(EV_KEY, BOTTOM_CLICKS[self._held], 0))
        self._state = _State.DRAIN if self._pressed else _State.IDLE
        self._single = None
        self._pair = None
        self._partial = False
        self._started = 0.0
        self._held = None
        return effects

    def _single_bottom(self):
        return (self._state is _State.PENDING and self._pair is None
                and self._single in BOTTOM_CLICKS and len(self._pressed) == 1)

    def _press(self, name, code, now):
        if self._state is _State.IDLE:
            self._state = _State.PENDING
            self._pressed = {code: name}
            self._single = name
            self._pair = None
            self._partial = False
            self._started = now
            return []
        if self._state is _State.PENDING:
            if code in self._pressed:
                return []
            if self._pair is not None and self._partial:
                self._state = _State.DRAIN
            self._pressed[code] = name
            if self._state is _State.PENDING:
                if self._pair is None and len(self._pressed) == 2:
                    self._pair = frozenset(self._pressed.values())
                    self._single = None
                elif len(self._pressed) >= 3:
                    self._state = _State.DRAIN
        elif self._state is _State.HELD:
            if code not in self._pressed:
                self._pressed[code] = name
        elif self._state is _State.DRAIN:
            if code not in self._pressed:
                self._pressed[code] = name
        return []

    def _release(self, name, code):
        if self._state is _State.IDLE or code not in self._pressed:
            return []
        self._pressed.pop(code)
        if self._state is _State.PENDING:
            if self._pair is None:
                self._state = _State.IDLE
                self._single = None
                if name in BOTTOM_CLICKS:
                    code = BOTTOM_CLICKS[name]
                    return [Emit(EV_KEY, code, 1), Emit(EV_KEY, code, 0)]
                return [Invoke(SINGLE_ACTIONS[name])]
            if self._pressed:
                self._partial = True
                return []
            action = PAIR_ACTIONS.get(self._pair)
            self._state = _State.IDLE
            self._single = None
            self._pair = None
            self._partial = False
            return [Invoke(action)] if action is not None else []
        if self._state is _State.HELD:
            if name != self._held:
                return []
            self._held = None
            self._state = _State.DRAIN if self._pressed else _State.IDLE
            return [Emit(EV_KEY, BOTTOM_CLICKS[name], 0)]
        if self._state is _State.DRAIN and not self._pressed:
            self._state = _State.IDLE
        return []


class ConfigError(ValueError):
    pass


class DeviceError(RuntimeError):
    pass


@dataclass(frozen=True)
class Config:
    path: Path
    vendor: int
    product: int
    hold_ms: int
    buttons: dict
    commands: dict


@dataclass(frozen=True)
class DeviceInfo:
    path: str
    name: str
    vendor: int
    product: int
    keys: tuple
    mode: int
    uid: int
    gid: int
    readable: bool
    writable: bool


def _table(data, key, config_path):
    value = data.get(key)
    if not isinstance(value, dict):
        raise ConfigError(f'{config_path}: [{key}] table is required')
    return value


def _integer(value, label, low, high, config_path):
    if type(value) is not int or not low <= value <= high:
        raise ConfigError(f'{config_path}: {label} must be an integer between {low} and {high}')
    return value


def load_config(path=None):
    config_path = Path(path) if path is not None else DEFAULT_CONFIG
    with config_path.open('rb') as handle:
        data = tomllib.load(handle)
    device = _table(data, 'device', config_path)
    gesture = _table(data, 'gesture', config_path)
    buttons = _table(data, 'buttons', config_path)
    commands = _table(data, 'commands', config_path)

    vendor = _integer(device.get('vendor'), 'device.vendor', 0, 0xffff, config_path)
    product = _integer(device.get('product'), 'device.product', 0, 0xffff, config_path)
    hold_ms = _integer(gesture.get('hold_ms'), 'gesture.hold_ms', 0, 2**31 - 1, config_path)

    missing_buttons = set(BUTTON_NAMES) - set(buttons)
    extra_buttons = set(buttons) - set(BUTTON_NAMES)
    if missing_buttons or extra_buttons:
        raise ConfigError(f'{config_path}: [buttons] must contain exactly {", ".join(BUTTON_NAMES)}')
    button_codes = {
        name: _integer(buttons[name], f'buttons.{name}', 1, 0x2ff, config_path)
        for name in BUTTON_NAMES
    }
    if len(set(button_codes.values())) != len(button_codes):
        raise ConfigError(f'{config_path}: [buttons] codes must be unique')

    missing_commands = set(COMMAND_ACTIONS) - set(commands)
    extra_commands = set(commands) - set(COMMAND_ACTIONS)
    if missing_commands or extra_commands:
        raise ConfigError(f'{config_path}: [commands] must contain exactly {", ".join(COMMAND_ACTIONS)}')
    command_lines = {}
    for action in COMMAND_ACTIONS:
        raw = commands[action]
        if not isinstance(raw, list) or not raw:
            raise ConfigError(f'{config_path}: commands.{action} must be a non-empty argv list')
        argv = []
        for index, item in enumerate(raw):
            if not isinstance(item, str) or not item:
                raise ConfigError(f'{config_path}: commands.{action}[{index}] must be a non-empty string')
            expanded = os.path.expanduser(os.path.expandvars(item))
            if not expanded:
                raise ConfigError(f'{config_path}: commands.{action}[{index}] expanded to an empty string')
            argv.append(expanded)
        command_lines[action] = argv

    return Config(
        path=config_path,
        vendor=vendor,
        product=product,
        hold_ms=hold_ms,
        buttons=button_codes,
        commands=command_lines,
    )


def _keyboard_letters(ecodes):
    return {ecodes.ecodes[f'KEY_{letter}'] for letter in string.ascii_uppercase}


def _match_reason(evdev, config, device, capabilities):
    ecodes = evdev.ecodes
    if device.name in SELF_NAMES:
        return 'this is one of our own virtual devices'
    if device.info.vendor != config.vendor or device.info.product != config.product:
        return f'vendor/product is {device.info.vendor:04x}:{device.info.product:04x}'
    relative = set(capabilities.get(ecodes.EV_REL, ()))
    if ecodes.REL_X not in relative or ecodes.REL_Y not in relative:
        return 'missing REL_X/REL_Y pointer capabilities'
    keys = set(capabilities.get(ecodes.EV_KEY, ()))
    missing = set(config.buttons.values()) - keys
    if missing:
        return 'missing configured buttons ' + ', '.join(str(code) for code in sorted(missing))
    if ecodes.EV_ABS in capabilities:
        return 'has EV_ABS, so it is not the mouse interface'
    letters = keys & _keyboard_letters(ecodes)
    if letters:
        return 'exposes keyboard letters'
    return None


def _permission_text(info):
    return (f'mode={stat.S_IMODE(info.mode):04o} uid={info.uid} gid={info.gid} '
            f'readable={"yes" if info.readable else "no"} '
            f'writable={"yes" if info.writable else "no"}')


def _inspect_device(config, path, strict):
    evdev = _evdev()
    try:
        details = os.stat(path)
    except OSError as error:
        if strict:
            raise DeviceError(f'{path}: cannot stat device: {error.strerror or error}') from error
        return None
    readable = os.access(path, os.R_OK)
    writable = os.access(path, os.W_OK)
    try:
        device = evdev.InputDevice(path)
    except OSError as error:
        if strict:
            raise DeviceError(
                f'{path}: cannot open device: {error.strerror or error} '
                f'(mode={stat.S_IMODE(details.st_mode):04o} uid={details.st_uid} gid={details.st_gid} '
                f'readable={"yes" if readable else "no"} writable={"yes" if writable else "no"})'
            ) from error
        return None
    try:
        capabilities = device.capabilities(verbose=False)
    except OSError as error:
        if strict:
            raise DeviceError(f'{path}: cannot read device capabilities: {error.strerror or error}') from error
        return None
    try:
        reason = _match_reason(evdev, config, device, capabilities)
        if reason is not None:
            if strict:
                raise DeviceError(f'{path}: does not match the configured mouse: {reason}')
            return None
        return DeviceInfo(
            path=str(path),
            name=device.name,
            vendor=device.info.vendor,
            product=device.info.product,
            keys=tuple(sorted(capabilities.get(evdev.ecodes.EV_KEY, ()))),
            mode=details.st_mode,
            uid=details.st_uid,
            gid=details.st_gid,
            readable=readable,
            writable=writable,
        )
    finally:
        device.close()


def scan_devices(config, device_path=None):
    evdev = _evdev()
    paths = [str(device_path)] if device_path is not None else evdev.list_devices()
    matches = []
    for path in paths:
        try:
            info = _inspect_device(config, path, strict=device_path is not None)
        except DeviceError:
            if device_path is not None:
                raise
            LOG.debug('skipping %s: inspect failed', path, exc_info=True)
            continue
        if info is not None:
            matches.append(info)
    return matches


def _evdev():
    try:
        import evdev
    except ImportError as error:
        raise RuntimeError('evdev is required at runtime; use the dependency environment') from error
    return evdev


def session_socket():
    signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    if not signature:
        return None
    return Path(f'/run/user/{os.getuid()}/hypr/{signature}/.socket.sock')


def session_valid():
    path = session_socket()
    return path is not None and path.exists()


class RuntimeLock:
    def __init__(self):
        runtime_dir = os.environ.get('XDG_RUNTIME_DIR') or f'/run/user/{os.getuid()}'
        self.path = Path(runtime_dir) / 'dotfiles-kensington-mouse.lock'
        self.fd = None

    def acquire(self):
        if not self.path.parent.is_dir():
            raise RuntimeError(f'{self.path.parent} is not available for the process lock')
        try:
            fd = os.open(self.path, os.O_CREAT | os.O_RDWR | os.O_CLOEXEC, 0o600)
        except OSError as error:
            raise RuntimeError(f'cannot open process lock {self.path}: {error.strerror or error}') from error
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            os.close(fd)
            if error.errno in (errno.EACCES, errno.EAGAIN):
                raise RuntimeError(f'another remapper holds {self.path}') from error
            raise RuntimeError(f'cannot acquire process lock {self.path}: {error.strerror or error}') from error
        try:
            os.fchmod(fd, 0o600)
            os.ftruncate(fd, 0)
            os.write(fd, f'{os.getpid()}\n'.encode())
        except OSError as error:
            os.close(fd)
            raise RuntimeError(f'cannot initialize process lock {self.path}: {error.strerror or error}') from error
        self.fd = fd

    def release(self):
        if self.fd is None:
            return
        fd = self.fd
        self.fd = None
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        except OSError:
            pass
        finally:
            os.close(fd)


def _pointer_events(evdev, capabilities):
    ecodes = evdev.ecodes
    events = {}
    for event_type, codes in capabilities.items():
        if event_type in (ecodes.EV_SYN, ecodes.EV_FF, ecodes.EV_FF_STATUS) or not codes:
            continue
        events[event_type] = [int(code) for code in codes]
    keys = set(events.get(ecodes.EV_KEY, ()))
    keys.update((BTN_LEFT, BTN_RIGHT, BTN_MIDDLE))
    events[ecodes.EV_KEY] = sorted(keys)
    relative = set(events.get(ecodes.EV_REL, ()))
    relative.update((ecodes.REL_X, ecodes.REL_Y))
    events[ecodes.EV_REL] = sorted(relative)
    return events


def _keyboard_events(evdev):
    return {evdev.ecodes.EV_KEY: list(range(1, 256))}


def _click(device, code):
    device.write(EV_KEY, code, 1)
    device.syn()
    device.write(EV_KEY, code, 0)
    device.syn()


class ActionWorker:
    """Run Invoke effects in order, off the pointer transfer path."""

    def __init__(self, config, pointer, keyboard):
        self.config = config
        self.pointer = pointer
        self.keyboard = keyboard
        self.queue = asyncio.Queue()
        self.task = None

    def start(self):
        if self.task is None or self.task.done():
            self.task = asyncio.create_task(self._run())

    def submit(self, action):
        self.start()
        self.queue.put_nowait(action)

    def cancel_pending(self):
        while True:
            try:
                self.queue.get_nowait()
            except asyncio.QueueEmpty:
                break
        task = self.task
        self.task = None
        if task is not None and not task.done():
            task.cancel()
        return task

    async def shutdown(self):
        task = self.cancel_pending()
        if task is not None:
            await asyncio.gather(task, return_exceptions=True)

    async def _run(self):
        while True:
            action = await self.queue.get()
            try:
                await self._execute(action)
            except asyncio.CancelledError:
                raise
            except Exception:
                LOG.exception('Invoke %s failed', action)

    async def _execute(self, action):
        if action == 'middle_click':
            _click(self.pointer, BTN_MIDDLE)
        elif action == 'enter':
            _click(self.keyboard, KEY_ENTER)
        elif action == 'escape':
            _click(self.keyboard, KEY_ESC)
        else:
            await self._command(action)

    async def _command(self, action):
        argv = self.config.commands[action]
        process = await asyncio.create_subprocess_exec(
            *argv,
            stdin=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.PIPE,
        )
        try:
            try:
                _, stderr = await asyncio.wait_for(process.communicate(), timeout=COMMAND_TIMEOUT)
            except asyncio.TimeoutError:
                await self._terminate(process)
                LOG.error('Invoke %s timed out after %.0fs', action, COMMAND_TIMEOUT)
                return
            if process.returncode:
                detail = stderr.decode(errors='replace').strip()
                LOG.error('Invoke %s exited %s%s', action, process.returncode, f': {detail}' if detail else '')
        except asyncio.CancelledError:
            await self._terminate(process)
            raise

    async def _terminate(self, process):
        if process.returncode is not None:
            return
        try:
            process.kill()
        except ProcessLookupError:
            pass
        except Exception as error:
            LOG.debug('cannot kill command: %s', error)
        try:
            await process.wait()
        except ProcessLookupError:
            pass
        except Exception as error:
            LOG.debug('cannot wait for command: %s', error)


class Remapper:
    def __init__(self, config, device_path):
        self.config = config
        self.mapped = frozenset(config.buttons.values())
        self.device_path = str(device_path) if device_path is not None else None
        self.stop = asyncio.Event()
        self.detach = asyncio.Event()
        self.detach_reason = 'stopped'
        self.device = None
        self.pointer = None
        self.keyboard = None
        self.worker = None
        self.engine = None
        self.blocked = set()
        self.frame = []
        self.discard_input = False
        self.reader_installed = False
        self.timer = None
        self.session_task = None
        self.scan_warned = False

    def request_stop(self):
        self.detach_reason = 'stopped'
        self.stop.set()
        self.detach.set()

    async def run(self):
        lock = RuntimeLock()
        try:
            lock.acquire()
        except RuntimeError as error:
            LOG.error('%s', error)
            return 1
        try:
            if not await self._wait_for_session():
                return 0
            first_scan = True
            while not self.stop.is_set():
                if not session_valid():
                    LOG.info('Hyprland session ended')
                    return 0
                try:
                    matches = await asyncio.to_thread(scan_devices, self.config, self.device_path)
                except DeviceError as error:
                    LOG.error('%s', error)
                    if first_scan:
                        return 1
                    if not session_valid():
                        return 0
                    await self._wait(SCAN_INTERVAL)
                    continue
                if not matches:
                    if not self.scan_warned:
                        LOG.info('no matching Kensington mouse yet; waiting')
                        self.scan_warned = True
                    await self._wait(SCAN_INTERVAL)
                    continue
                if len(matches) > 1:
                    paths = ', '.join(info.path for info in matches)
                    LOG.error('multiple matching devices (%s); refusing to choose one', paths)
                    return 1
                first_scan = False
                self.scan_warned = False
                try:
                    await self._run_attachment(matches[0])
                except DeviceError as error:
                    LOG.error('%s', error)
                    if not session_valid():
                        return 0
                    if self.device_path is not None:
                        return 1
                    await self._wait(SCAN_INTERVAL)
                    continue
                if self.stop.is_set():
                    break
                if not session_valid():
                    return 0
                await self._wait(SCAN_INTERVAL)
            return 0
        finally:
            lock.release()

    async def _wait_for_session(self):
        if session_valid():
            return True
        LOG.info('waiting for a valid Hyprland session')
        while not self.stop.is_set():
            await self._wait(SCAN_INTERVAL)
            if session_valid():
                return True
        return False

    async def _wait(self, seconds):
        try:
            await asyncio.wait_for(self.stop.wait(), timeout=seconds)
        except asyncio.TimeoutError:
            pass

    async def _run_attachment(self, info):
        if self.stop.is_set() or not session_valid():
            return
        evdev = _evdev()
        physical = None
        pointer = None
        keyboard = None
        grabbed = False
        self.engine = ChordEngine(self.config.buttons, self.config.hold_ms)
        self.detach = asyncio.Event()
        self.detach_reason = 'connection ended'
        self.blocked = set()
        self.frame = []
        self.discard_input = False
        try:
            try:
                physical = evdev.InputDevice(info.path)
            except OSError as error:
                raise DeviceError(f'cannot open {info.path}: {error.strerror or error}') from error
            capabilities = physical.capabilities(verbose=False)
            reason = _match_reason(evdev, self.config, physical, capabilities)
            if reason is not None:
                raise DeviceError(f'{info.path} no longer matches the configured mouse: {reason}')
            if self.stop.is_set() or not session_valid():
                return
            try:
                pointer = evdev.UInput(
                    _pointer_events(evdev, capabilities),
                    name=POINTER_NAME,
                    vendor=VIRTUAL_VENDOR,
                    product=VIRTUAL_POINTER_PRODUCT,
                    version=1,
                    bustype=evdev.ecodes.BUS_USB,
                    phys='dotfiles-kensington-pointer',
                )
                keyboard = evdev.UInput(
                    _keyboard_events(evdev),
                    name=KEYBOARD_NAME,
                    vendor=VIRTUAL_VENDOR,
                    product=VIRTUAL_KEYBOARD_PRODUCT,
                    version=1,
                    bustype=evdev.ecodes.BUS_USB,
                    phys='dotfiles-kensington-keyboard',
                )
            except Exception as error:
                raise DeviceError(f'cannot create virtual outputs: {error}') from error
            LOG.info('virtual outputs ready: %s / %s', pointer.device, keyboard.device)
            if self.stop.is_set() or not session_valid():
                return
            try:
                physical.grab()
            except OSError as error:
                raise DeviceError(
                    f'cannot exclusively grab {info.path}: {error.strerror or error} '
                    f'({_permission_text(info)})'
                ) from error
            grabbed = True
            if self.stop.is_set() or not session_valid():
                return
            self.device = physical
            self.pointer = pointer
            self.keyboard = keyboard
            self.worker = ActionWorker(self.config, pointer, keyboard)
            self.worker.start()
            self._drain_initial()
            loop = asyncio.get_running_loop()
            loop.add_reader(physical.fd, self._on_readable)
            self.reader_installed = True
            self.session_task = asyncio.create_task(self._monitor_session())
            LOG.info('attached %s (%s)', info.path, info.name)
            await self.detach.wait()
            LOG.info('detaching %s: %s', info.path, self.detach_reason)
        except DeviceError:
            raise
        except OSError as error:
            raise DeviceError(f'{info.path}: device setup failed: {error.strerror or error}') from error
        finally:
            await self._teardown(physical, pointer, keyboard, grabbed)

    def _drain_initial(self):
        for _ in range(STARTUP_DRAIN_LIMIT):
            if self.device.read_one() is None:
                break
        try:
            active = self.device.active_keys()
        except OSError:
            active = []
        self.blocked = set(active) & self.mapped
        self.frame.clear()

    async def _monitor_session(self):
        while True:
            await asyncio.sleep(SESSION_INTERVAL)
            if not session_valid():
                self.detach_reason = 'Hyprland session ended'
                self.detach.set()
                return

    def _on_readable(self):
        if self.device is None or self.detach.is_set():
            return
        try:
            while True:
                event = self.device.read_one()
                if event is None:
                    break
                self._handle_event(event.type, event.code, event.value)
        except OSError as error:
            self.detach_reason = f'input read failed: {error}'
            self.detach.set()
        except Exception:
            LOG.exception('input processing failed')
            self.detach_reason = 'input processing failed'
            self.detach.set()

    def _handle_event(self, event_type, code, value):
        if self.discard_input:
            if event_type == EV_SYN and code == SYN_REPORT:
                self.discard_input = False
                try:
                    active = self.device.active_keys()
                except OSError:
                    active = []
                self.blocked = set(active) & self.mapped
            return
        if event_type == EV_SYN:
            if code == SYN_DROPPED:
                effects = self.engine.reset()
                self.engine = ChordEngine(self.config.buttons, self.config.hold_ms)
                self._write_emit_effects(effects)
                if self.worker is not None:
                    self.worker.cancel_pending()
                self.frame.clear()
                self.blocked = set()
                self.discard_input = True
                self._schedule_hold_timer()
            elif code == SYN_REPORT:
                self._process_frame()
            return
        self.frame.append((event_type, code, value))

    def _consume_blocked(self, code, value):
        if code not in self.mapped:
            return False
        if code in self.blocked:
            if value == 0:
                self.blocked.discard(code)
            return True
        if self.blocked:
            if value == 1:
                self.blocked.add(code)
            return True
        return False

    def _process_frame(self):
        if not self.frame:
            return
        mapped = []
        passthrough = []
        for event_type, code, value in self.frame:
            if event_type == EV_KEY and code in self.mapped:
                mapped.append((event_type, code, value))
            else:
                passthrough.append((event_type, code, value))
        self.frame.clear()
        now = time.monotonic()
        effects = []
        for event_type, code, value in mapped:
            if self._consume_blocked(code, value):
                continue
            effects.extend(self.engine.feed(event_type, code, value, now))
        for event_type, code, value in passthrough:
            if event_type == EV_KEY and self._consume_blocked(code, value):
                continue
            effects.extend(self.engine.feed(event_type, code, value, now))
        self._write_effects(effects)
        self._schedule_hold_timer()

    def _schedule_hold_timer(self):
        if self.timer is not None:
            self.timer.cancel()
            self.timer = None
        if self.device is None or self.detach.is_set() or self.engine is None:
            return
        deadline = self.engine.hold_deadline()
        if deadline is not None:
            self.timer = asyncio.get_running_loop().call_at(deadline, self._on_tick)

    def _on_tick(self):
        self.timer = None
        if self.device is None or self.detach.is_set():
            return
        try:
            effects = self.engine.tick(time.monotonic())
            self._write_emit_effects(effects)
        except OSError as error:
            self.detach_reason = f'virtual output failed: {error}'
            self.detach.set()
            return
        except Exception:
            LOG.exception('timer processing failed')
            self.detach_reason = 'timer processing failed'
            self.detach.set()
            return
        self._schedule_hold_timer()

    def _write_emit_effects(self, effects):
        for effect in effects:
            if isinstance(effect, Emit):
                self._write_emit(effect)

    def _write_emit(self, effect, device=None):
        target = device if device is not None else self.pointer
        if target is None or effect.type == EV_SYN:
            return
        target.write(effect.type, effect.code, effect.value)
        target.syn()

    def _write_effects(self, effects):
        for effect in effects:
            if isinstance(effect, Emit):
                self._write_emit(effect)
            else:
                LOG.info('Invoke %s', effect.action)
                if self.worker is not None:
                    self.worker.submit(effect.action)

    async def _teardown(self, physical, pointer, keyboard, grabbed):
        loop = asyncio.get_running_loop()
        if self.timer is not None:
            self.timer.cancel()
            self.timer = None
        if self.reader_installed and physical is not None:
            loop.remove_reader(physical.fd)
            self.reader_installed = False
        if self.session_task is not None:
            self.session_task.cancel()
            await asyncio.gather(self.session_task, return_exceptions=True)
            self.session_task = None
        if self.engine is not None and pointer is not None:
            try:
                for effect in self.engine.reset():
                    self._write_emit(effect, pointer)
            except Exception:
                LOG.exception('failed to release virtual held outputs')
        self.engine = None
        if self.worker is not None:
            await self.worker.shutdown()
            self.worker = None
        if physical is not None:
            if grabbed:
                try:
                    physical.ungrab()
                except OSError as error:
                    LOG.debug('ungrab failed: %s', error)
            try:
                physical.close()
            except OSError as error:
                LOG.debug('physical close failed: %s', error)
        if keyboard is not None:
            try:
                keyboard.close()
            except OSError as error:
                LOG.debug('keyboard close failed: %s', error)
        if pointer is not None:
            try:
                pointer.close()
            except OSError as error:
                LOG.debug('pointer close failed: %s', error)
        self.device = None
        self.pointer = None
        self.keyboard = None
        self.blocked.clear()
        self.frame.clear()
        self.discard_input = False


def check(config, device_path):
    try:
        matches = scan_devices(config, device_path)
    except (DeviceError, RuntimeError) as error:
        LOG.error('%s', error)
        return 1
    if not matches:
        LOG.error('no matching physical Kensington mouse found%s',
                  f' at {device_path}' if device_path is not None else '')
        return 1
    if len(matches) > 1:
        LOG.error('multiple matching devices found: %s', ', '.join(info.path for info in matches))
        return 1
    info = matches[0]
    print(f'config: {config.path}')
    print(f'device: {info.path}')
    print(f'name: {info.name}')
    print(f'id: {info.vendor:04x}:{info.product:04x}')
    print(f'permissions: {_permission_text(info)}')
    print('buttons: ' + ' '.join(f'{name}={config.buttons[name]}' for name in BUTTON_NAMES))
    return 0


async def _run(config, device_path):
    remapper = Remapper(config, device_path)
    loop = asyncio.get_running_loop()
    for signum in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(signum, remapper.request_stop)
    return await remapper.run()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=DEFAULT_CONFIG,
                        help=f'TOML config (default: {DEFAULT_CONFIG})')
    parser.add_argument('--check', action='store_true',
                        help='validate config, report matching device permissions and button codes')
    parser.add_argument('--device', type=Path,
                        help='verify or run against this specific event device')
    arguments = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
    try:
        config = load_config(arguments.config)
    except (OSError, tomllib.TOMLDecodeError, ConfigError) as error:
        LOG.error('invalid config: %s', error)
        return 1
    if arguments.check:
        return check(config, arguments.device)
    try:
        return asyncio.run(_run(config, arguments.device))
    except RuntimeError as error:
        LOG.error('%s', error)
        return 1
    except KeyboardInterrupt:
        return 0


if __name__ == '__main__':
    sys.exit(main())
