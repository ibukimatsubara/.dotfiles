#!/usr/bin/env python3
"""Verify keycast lock suppression and managed IPC toggle."""
import fcntl
import importlib.util
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
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
        self.assertFalse(self.mod.screen_locked(lock_path=lock_file, proc_root=fake_proc))
        with lock_file.open('w') as handle:
            self.assertFalse(self.mod.screen_locked(lock_path=lock_file, proc_root=fake_proc))
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertTrue(self.mod.screen_locked(lock_path=lock_file, proc_root=fake_proc))
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
            self.assertFalse(self.mod.screen_locked(lock_path=lock_file, proc_root=fake_proc))

    def test_screen_locked_detects_hyprlock_process_in_proc(self):
        fake_proc = self.tmp / 'proc'
        pid_dir = fake_proc / '424242'
        pid_dir.mkdir(parents=True)
        (pid_dir / 'comm').write_text('hyprlock\n')
        missing_lock = self.tmp / 'missing.lock'
        self.assertTrue(self.mod.screen_locked(lock_path=missing_lock, proc_root=fake_proc))
        (pid_dir / 'comm').write_text('ghostty\n')
        self.assertFalse(self.mod.screen_locked(lock_path=missing_lock, proc_root=fake_proc))

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
            os.write(write_fd, pack_key_event(30, 1))
            state.process_handle(handle, 'kb', set(), locked=False)

            os.write(write_fd, pack_key_event(29, 1) + pack_key_event(31, 1) + pack_key_event(28, 1))
            state.sync_lock(True)
            state.sync_lock(True)
            state.process_handle(handle, 'kb', set(), locked=True)

            # Pipe must be drained during lock so unlock cannot replay password events.
            with self.assertRaises(BlockingIOError):
                os.read(read_fd, 64)

            state.sync_lock(False)
            os.write(write_fd, pack_key_event(32, 1))
            state.process_handle(handle, 'kb', set(), locked=False)

        emitted = [json.loads(line) for line in out.getvalue().splitlines() if line.strip()]
        self.assertEqual([e.get('text') for e in emitted if 'text' in e], ['a', 'd'])
        clears = [e for e in emitted if e.get('clear') is True]
        self.assertEqual(len(clears), 1, emitted)


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
