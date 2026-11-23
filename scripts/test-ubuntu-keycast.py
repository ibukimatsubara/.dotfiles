#!/usr/bin/env python3
"""Verify keycast lock suppression and managed IPC toggle."""
import fcntl
import importlib.util
import io
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import tempfile
import threading
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
EVENTS_PATH = ROOT / 'scripts/keycast-events.py'
TOGGLE_SCRIPT = ROOT / 'scripts/ubuntu-keycast.sh'


def load_keycast_events():
    spec = importlib.util.spec_from_file_location('keycast_events', EVENTS_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def pack_key_event(code, value, seconds=1700000000, micros=123000):
    return struct.pack('llHHi', seconds, micros, 1, code, value)


def pack_rel_event(code, value, seconds=1700000000, micros=123000):
    return struct.pack('llHHi', seconds, micros, 2, code, value)


class KeycastEventsLockTests(unittest.TestCase):
    def setUp(self):
        self.mod = load_keycast_events()
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.tmp = Path(self.temp.name)

    def test_screen_locked_detects_active_flock_and_release(self):
        lock_file = self.tmp / 'dotfiles-hyprlock.lock'
        fake_proc = self.tmp / 'empty-proc'
        fake_proc.mkdir()
        self.assertFalse(self.mod.screen_locked(lock_path=lock_file, proc_root=fake_proc, hypr_socket=False))
        with lock_file.open('w') as handle:
            self.assertFalse(self.mod.screen_locked(lock_path=lock_file, proc_root=fake_proc, hypr_socket=False))
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertTrue(self.mod.screen_locked(lock_path=lock_file, proc_root=fake_proc, hypr_socket=False))
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
            self.assertFalse(self.mod.screen_locked(lock_path=lock_file, proc_root=fake_proc, hypr_socket=False))

    def test_screen_locked_detects_hyprlock_process_in_proc(self):
        fake_proc = self.tmp / 'proc'
        pid_dir = fake_proc / '424242'
        pid_dir.mkdir(parents=True)
        (pid_dir / 'comm').write_text('hyprlock\n')
        missing_lock = self.tmp / 'missing.lock'
        self.assertTrue(self.mod.screen_locked(lock_path=missing_lock, proc_root=fake_proc, hypr_socket=False))
        (pid_dir / 'comm').write_text('ghostty\n')
        self.assertFalse(self.mod.screen_locked(lock_path=missing_lock, proc_root=fake_proc, hypr_socket=False))

    def test_screen_locked_fails_closed_when_hyprland_socket_query_fails(self):
        fake_proc = self.tmp / 'empty-proc'
        fake_proc.mkdir()
        missing_lock = self.tmp / 'missing.lock'
        missing_sock = self.tmp / 'unreachable.sock'
        self.assertTrue(self.mod.screen_locked(lock_path=missing_lock, proc_root=fake_proc, hypr_socket=missing_sock))

        bad_sock = self.tmp / 'eof.sock'
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(str(bad_sock))
        server.listen(2)
        server.settimeout(2)
        stop = threading.Event()

        def serve_eof():
            while not stop.is_set():
                try:
                    conn, _ = server.accept()
                except OSError:
                    break
                with conn:
                    conn.recv(64)

        thread = threading.Thread(target=serve_eof, daemon=True)
        thread.start()
        self.addCleanup(lambda: (stop.set(), server.close(), thread.join(timeout=2)))
        self.assertTrue(self.mod.screen_locked(lock_path=missing_lock, proc_root=fake_proc, hypr_socket=bad_sock))

    def test_screen_locked_detects_hyprland_socket_lock_without_hyprlock(self):
        sock_path = self.tmp / 'hypr.sock'
        fake_proc = self.tmp / 'empty-proc'
        fake_proc.mkdir()
        missing_lock = self.tmp / 'missing.lock'
        reply = [b'true']
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(str(sock_path))
        server.listen(4)
        server.settimeout(2)
        stop = threading.Event()

        def serve():
            while not stop.is_set():
                try:
                    conn, _ = server.accept()
                except OSError:
                    break
                with conn:
                    req = conn.recv(64)
                    if req == b'locked':
                        conn.sendall(reply[0])

        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        self.addCleanup(lambda: (stop.set(), server.close(), thread.join(timeout=2)))

        self.assertTrue(self.mod.screen_locked(lock_path=missing_lock, proc_root=fake_proc, hypr_socket=sock_path))
        reply[0] = b'false'
        self.assertFalse(self.mod.screen_locked(lock_path=missing_lock, proc_root=fake_proc, hypr_socket=sock_path))

    def test_screen_locked_ignores_non_utf8_proc_comm(self):
        fake_proc = self.tmp / 'proc-utf8'
        bad_dir = fake_proc / '100001'
        bad_dir.mkdir(parents=True)
        # Kernel truncates /proc/<pid>/comm at 15 bytes, which can split a multibyte UTF-8 sequence.
        (bad_dir / 'comm').write_bytes('あいうえおか'.encode('utf-8')[:14] + b'\n')
        missing_lock = self.tmp / 'missing.lock'
        self.assertFalse(self.mod.screen_locked(lock_path=missing_lock, proc_root=fake_proc, hypr_socket=False))
        good_dir = fake_proc / '100002'
        good_dir.mkdir()
        (good_dir / 'comm').write_bytes(b'hyprlock\n')
        self.assertTrue(self.mod.screen_locked(lock_path=missing_lock, proc_root=fake_proc, hypr_socket=False))

    def test_locked_events_are_drained_and_clear_is_emitted_once(self):
        read_fd, write_fd = os.pipe()
        os.set_blocking(read_fd, False)
        self.addCleanup(os.close, write_fd)
        handle = os.fdopen(read_fd, 'rb', buffering=0)
        self.addCleanup(handle.close)

        names = {30: 'KEY_A', 31: 'KEY_S', 32: 'KEY_D', 28: 'KEY_ENTER', 29: 'KEY_LEFTCTRL'}
        out = io.StringIO()
        state = self.mod.EventState(names=names)

        with mock.patch('sys.stdout', out):
            os.write(write_fd, pack_key_event(30, 1, seconds=1700000000))
            state.process_handle(handle, 'kb', set(), locked=False)

            os.write(write_fd, pack_key_event(29, 1, seconds=1700000001)
                     + pack_key_event(31, 1, seconds=1700000001)
                     + pack_key_event(28, 1, seconds=1700000001))
            state.sync_lock(True)
            state.sync_lock(True)
            state.process_handle(handle, 'kb', set(), locked=True)

            # Pipe must be drained during lock so unlock cannot replay password events.
            with self.assertRaises(BlockingIOError):
                os.read(read_fd, 64)

            state.sync_lock(False, now=1700000002.0)
            os.write(write_fd, pack_key_event(32, 1, seconds=1700000003))
            state.process_handle(handle, 'kb', set(), locked=False)

        emitted = [json.loads(line) for line in out.getvalue().splitlines() if line.strip()]
        self.assertEqual([e.get('text') for e in emitted if 'text' in e], ['a', 'd'])
        clears = [e for e in emitted if e.get('clear') is True]
        self.assertEqual(len(clears), 1, emitted)

    def test_unlock_drops_events_queued_before_unlock(self):
        read_fd, write_fd = os.pipe()
        os.set_blocking(read_fd, False)
        self.addCleanup(os.close, write_fd)
        handle = os.fdopen(read_fd, 'rb', buffering=0)
        self.addCleanup(handle.close)

        names = {30: 'KEY_A', 32: 'KEY_D'}
        out = io.StringIO()
        state = self.mod.EventState(names=names)

        with mock.patch('sys.stdout', out):
            state.sync_lock(True)
            # Event arrives while locked, then screen unlocks before the reader wakes up.
            os.write(write_fd, pack_key_event(30, 1, seconds=1700000010, micros=500000))
            unlocked = state.sync_lock(False, now=1700000011.0)
            self.assertTrue(unlocked)
            self.mod.drain_handles([handle])
            # Even if a late event carries a pre-unlock timestamp, apply must skip it.
            state.apply(pack_key_event(30, 1, seconds=1700000010, micros=900000), 'kb', set())
            os.write(write_fd, pack_key_event(32, 1, seconds=1700000012, micros=0))
            state.process_handle(handle, 'kb', set(), locked=False)

        emitted = [json.loads(line) for line in out.getvalue().splitlines() if line.strip()]
        self.assertEqual([e.get('text') for e in emitted if 'text' in e], ['d'])
        self.assertEqual([e for e in emitted if e.get('clear') is True], [{'clear': True}])

    def test_pointer_motion_only_batch_is_not_displayable(self):
        motion = pack_rel_event(0, 5) + pack_rel_event(1, -3)
        wheel = pack_rel_event(8, 1)
        key = pack_key_event(30, 1)
        self.assertFalse(self.mod.has_displayable_event(motion))
        self.assertTrue(self.mod.has_displayable_event(wheel))
        self.assertTrue(self.mod.has_displayable_event(key))
        self.assertTrue(self.mod.has_displayable_event(motion + key))

    def test_main_drops_locked_queued_key_and_avoids_polling_on_motion(self):
        read_fd, write_fd = os.pipe()
        os.set_blocking(read_fd, False)
        self.addCleanup(os.close, write_fd)
        dev_path = '/dev/input/event99'
        unplug_path = '/dev/input/event98'
        lock_state = {'locked': True, 'calls': 0}
        now = int(time.time())

        class UnpluggingHandle:
            def __init__(self, name):
                self.name = name
                self.closed = False

            def fileno(self):
                return 999

            def read(self, _size):
                if self.closed:
                    raise ValueError('I/O operation on closed file')
                raise OSError('No such device')

            def close(self):
                self.closed = True

        def fake_screen_locked(*args, **kwargs):
            lock_state['calls'] += 1
            return lock_state['locked']

        def fake_open(path, mode='rb', buffering=0):
            if path == dev_path:
                handle = os.fdopen(read_fd, 'rb', buffering=0)
                self.addCleanup(handle.close)
                return handle
            if path == unplug_path:
                return UnpluggingHandle(path)
            return open(path, mode, buffering=buffering)

        out = io.StringIO()
        step = {'n': 0}

        class FakeSelector:
            def __init__(self):
                self.keys = {}

            def register(self, fileobj, events, data):
                self.keys[fileobj] = mock.Mock(fileobj=fileobj, data=data)

            def unregister(self, fileobj):
                self.keys.pop(fileobj, None)

            def select(self, timeout=None):
                step['n'] += 1
                ordered = list(self.keys.values())
                kb_key = next(k for k in ordered if k.data == 'kb')
                unplug_key = next((k for k in ordered if k.data == 'unplug'), None)
                if step['n'] == 1:
                    # Key typed while locked must be dropped without emitting.
                    os.write(write_fd, pack_key_event(31, 1, seconds=now - 3))
                    return [(kb_key, 1)]
                if step['n'] == 2:
                    # Unlock coincides with an unplugged device in the same select() batch.
                    os.write(write_fd, pack_key_event(30, 1, seconds=now - 2))
                    lock_state['locked'] = False
                    return [(kb_key, 1), (unplug_key, 1)]
                if 3 <= step['n'] <= 22:
                    # 20 pointer motion bursts while unlocked should not poll screen_locked per burst.
                    os.write(write_fd, pack_rel_event(0, 1, seconds=now + 5))
                    return [(kb_key, 1)]
                if step['n'] == 23:
                    os.write(write_fd, pack_key_event(32, 1, seconds=now + 10))
                    return [(kb_key, 1)]
                raise KeyboardInterrupt

        orig_set_blocking = os.set_blocking
        with (
            mock.patch.object(self.mod, 'key_names', return_value={30: 'KEY_A', 31: 'KEY_S', 32: 'KEY_D'}),
            mock.patch.object(self.mod, 'devices', return_value={dev_path: 'kb', unplug_path: 'unplug'}),
            mock.patch.object(self.mod, 'swapped_keyboards', return_value=set()),
            mock.patch.object(self.mod, 'screen_locked', side_effect=fake_screen_locked),
            mock.patch.object(self.mod.selectors, 'DefaultSelector', FakeSelector),
            mock.patch.object(self.mod.os, 'set_blocking', lambda fd, flag: None if fd == 999 else orig_set_blocking(fd, flag)),
            mock.patch('builtins.open', side_effect=fake_open),
            mock.patch('sys.stdout', out),
        ):
            try:
                self.mod.main()
            except KeyboardInterrupt:
                pass

        emitted = [json.loads(line) for line in out.getvalue().splitlines() if line.strip()]
        self.assertEqual([e.get('text') for e in emitted if 'text' in e], ['d'], emitted)
        self.assertEqual([e for e in emitted if e.get('clear') is True], [{'clear': True}], emitted)
        self.assertLess(lock_state['calls'], 10, f"polled screen_locked too often on motion: {lock_state['calls']}")


class KeycastToggleScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.log = self.home / 'qs-calls.jsonl'
        qs = self.bin / 'qs'
        qs.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
entry = {
    'args': sys.argv[1:],
    'display': os.environ.get('DISPLAY'),
    'xauthority': os.environ.get('XAUTHORITY'),
}
with Path(os.environ['TEST_LOG']).open('a') as f:
    f.write(json.dumps(entry) + '\\n')
''')
        qs.chmod(0o755)
        self.env = dict(
            os.environ,
            HOME=str(self.home),
            PATH=f"{self.bin}:{os.environ['PATH']}",
            DISPLAY=':42',
            XAUTHORITY='/test/xauth',
            TEST_LOG=str(self.log),
        )

    def test_toggle_uses_ipc_without_killing_or_spawning_unmanaged_qs(self):
        result = subprocess.run(['bash', str(TOGGLE_SCRIPT)], env=self.env,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.log.read_text().splitlines() if line.strip()]
        self.assertEqual(len(calls), 1, calls)
        expected_config = str((ROOT / 'platforms/ubuntu/quickshell/keycast').resolve())
        args = calls[0]['args']
        self.assertEqual(args[:2], ['ipc', '-p'], calls)
        self.assertEqual(str(Path(args[2]).resolve()), expected_config)
        self.assertEqual(args[3:], ['call', 'keycast', 'toggle'])
        self.assertIsNone(calls[0]['display'])
        self.assertIsNone(calls[0]['xauthority'])


if __name__ == '__main__':
    unittest.main()
