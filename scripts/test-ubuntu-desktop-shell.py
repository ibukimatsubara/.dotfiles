#!/usr/bin/env python3
"""Exercise shell selection and IPC without touching the running desktop."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent


class ShellTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / 'config'),
                        PATH=str(self.bin) + ':' + os.environ['PATH'])
        for name in ('dms', 'caelestia', 'qs', 'vicinae'):
            p = self.bin / name
            p.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv))\n')
            p.chmod(0o755)

    def run_shell(self, *args):
        return subprocess.run(['bash', str(ROOT / 'scripts/ubuntu-desktop-shell.sh'), *args],
                              env=self.env, capture_output=True, text=True, timeout=5)

    def select(self, backend):
        p = Path(self.env['XDG_CONFIG_HOME']) / 'dotfiles/desktop-shell'
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(backend + '\n')

    def test_default_keeps_dms_and_its_existing_launcher(self):
        result = self.run_shell('current')
        self.assertEqual((result.returncode, result.stdout.strip()), (0, 'dms'))
        result = self.run_shell('launcher')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)[1:], ['toggle'])

    def test_caelestia_routes_launcher_and_settings(self):
        self.select('caelestia')
        for action, args in [('launcher', ['shell', 'drawers', 'toggle', 'launcher']),
                             ('spotlight', ['shell', 'drawers', 'toggle', 'launcher']),
                             ('settings', ['shell', 'nexus', 'open'])]:
            result = self.run_shell(action)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)[1:], args)

    def test_invalid_selection_cannot_execute_arbitrary_commands(self):
        self.select('echo unexpected')
        self.assertNotEqual(self.run_shell('run').returncode, 0)

    def test_select_is_persistent_and_reversible(self):
        for backend in ('caelestia', 'dms'):
            result = self.run_shell('select', backend)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.run_shell('current').stdout.strip(), backend)
        self.assertNotEqual(self.run_shell('select', 'unknown').returncode, 0)
        self.assertEqual(self.run_shell('current').stdout.strip(), 'dms')

    def test_recovery_can_replace_a_damaged_selection(self):
        self.select('broken')
        result = self.run_shell('select', 'dms')
        self.assertEqual(result.returncode, 0, result.stderr)
        selection = Path(self.env['XDG_CONFIG_HOME']) / 'dotfiles/desktop-shell'
        selection.write_text('caelestia')
        result = self.run_shell('current')
        self.assertEqual((result.returncode, result.stdout.strip()), (0, 'caelestia'))

    def test_run_starts_desk_notes_alongside_selected_shell(self):
        log = self.home / 'launches.jsonl'
        recorder = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
entry = {
    'bin': Path(sys.argv[0]).name,
    'args': sys.argv[1:],
    'display': os.environ.get('DISPLAY'),
    'xauthority': os.environ.get('XAUTHORITY'),
    'ld_library_path': os.environ.get('LD_LIBRARY_PATH'),
    'qml_import_path': os.environ.get('QML_IMPORT_PATH'),
}
with open(os.environ['SHELL_TEST_LOG'], 'a') as f:
    f.write(json.dumps(entry) + '\\n')
'''
        for name in ('dms', 'qs'):
            p = self.bin / name
            p.write_text(recorder)
            p.chmod(0o755)
        self.env.pop('LD_LIBRARY_PATH', None)
        self.env.pop('QML_IMPORT_PATH', None)
        self.env.update(
            SHELL_TEST_LOG=str(log),
            DISPLAY=':42',
            XAUTHORITY='/test/xauth',
        )
        expected_desk_notes = str((ROOT / 'platforms/ubuntu/quickshell/desk-notes').resolve())
        for backend, expected_shell in (('dms', ('dms', ['run'])), ('caelestia', ('qs', ['-c', 'caelestia', '-n']))):
            with self.subTest(backend=backend):
                if log.exists():
                    log.unlink()
                notes_dir = self.home / '.config/desk-notes'
                if notes_dir.exists():
                    notes_dir.rmdir()
                self.select(backend)
                result = self.run_shell('run')
                self.assertEqual(result.returncode, 0, result.stderr)
                deadline = time.monotonic() + 3
                entries = []
                while time.monotonic() < deadline:
                    if log.exists():
                        entries = [json.loads(line) for line in log.read_text().splitlines() if line]
                        if len(entries) >= 2:
                            break
                    time.sleep(0.05)
                self.assertTrue(notes_dir.is_dir())
                desk_notes = [
                    e for e in entries
                    if e['bin'] == 'qs' and len(e['args']) == 3 and e['args'][0] == '-p' and e['args'][2] == '-n'
                ]
                self.assertEqual(len(desk_notes), 1, entries)
                self.assertEqual(str(Path(desk_notes[0]['args'][1]).resolve()), expected_desk_notes)
                self.assertIsNone(desk_notes[0]['display'])
                self.assertIsNone(desk_notes[0]['xauthority'])
                self.assertIsNone(desk_notes[0]['ld_library_path'])
                self.assertIsNone(desk_notes[0]['qml_import_path'])
                shell_entries = [e for e in entries if e != desk_notes[0]]
                self.assertEqual(len(shell_entries), 1, entries)
                self.assertEqual((shell_entries[0]['bin'], shell_entries[0]['args']), expected_shell)

    def wait_for(self, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.05)
        self.fail('Timed out waiting for desktop shell child processes')

    def read_jsonl(self, path):
        if not path.exists():
            return []
        return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]

    def kill_group(self, proc):
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        if proc.poll() is None:
            proc.wait(timeout=5)

    def test_run_waits_for_desk_notes_and_survives_repeated_term(self):
        self.select('dms')
        events = self.home / 'term-events.jsonl'
        stopped_marker = self.home / 'desk-notes-clean-exit'
        (self.bin / 'qs').write_text('''#!/usr/bin/env python3
import json, os, signal, time
from pathlib import Path
with Path(os.environ['TEST_EVENTS']).open('a') as f:
    f.write(json.dumps({'label': 'desk-notes', 'pid': os.getpid()}) + '\\n')
stopped = False
signal.signal(signal.SIGTERM, lambda *_: globals().update(stopped=True))
while not stopped:
    time.sleep(0.05)
time.sleep(0.25)
Path(os.environ['TEST_STOPPED_MARKER']).write_text('clean')
''')
        (self.bin / 'qs').chmod(0o755)
        (self.bin / 'dms').write_text('''#!/usr/bin/env python3
import json, os, signal, time
from pathlib import Path
with Path(os.environ['TEST_EVENTS']).open('a') as f:
    f.write(json.dumps({'label': 'dms', 'pid': os.getpid()}) + '\\n')
stopped = False
signal.signal(signal.SIGTERM, lambda *_: globals().update(stopped=True))
while not stopped:
    time.sleep(0.05)
''')
        (self.bin / 'dms').chmod(0o755)
        env = dict(self.env, TEST_EVENTS=str(events), TEST_STOPPED_MARKER=str(stopped_marker))
        proc = subprocess.Popen(['bash', str(ROOT / 'scripts/ubuntu-desktop-shell.sh'), 'run'],
                                env=env, start_new_session=True,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            self.wait_for(lambda: len(self.read_jsonl(events)) >= 2)
            records = {r['label']: r for r in self.read_jsonl(events)}
            os.killpg(proc.pid, signal.SIGTERM)
            time.sleep(0.05)
            os.killpg(proc.pid, signal.SIGTERM)
            proc.wait(timeout=3)
            self.assertTrue(stopped_marker.exists(),
                            'runner exited before desk-notes finished shutting down')
            for rec in records.values():
                with self.assertRaises(ProcessLookupError):
                    os.kill(rec['pid'], 0)
        finally:
            self.kill_group(proc)

    def test_run_keeps_shell_running_and_avoids_signaling_exited_desk_notes(self):
        self.select('dms')
        pid_file = self.home / 'early-qs.pid'
        dms_ready = self.home / 'dms-ready'
        trace_file = self.home / 'runner.trace'
        (self.bin / 'qs').write_text('''#!/usr/bin/env python3
import os, sys
from pathlib import Path
Path(os.environ['TEST_PID_FILE']).write_text(str(os.getpid()))
sys.exit(0)
''')
        (self.bin / 'qs').chmod(0o755)
        (self.bin / 'dms').write_text('''#!/usr/bin/env python3
import os, signal, sys, time
from pathlib import Path
deadline = time.monotonic() + 2
while not Path(os.environ['TEST_PID_FILE']).exists() and time.monotonic() < deadline:
    time.sleep(0.05)
Path(os.environ['TEST_DMS_READY']).write_text('ready')
stopped = False
signal.signal(signal.SIGTERM, lambda *_: globals().update(stopped=True))
while not stopped:
    time.sleep(0.05)
sys.exit(0)
''')
        (self.bin / 'dms').chmod(0o755)
        env = dict(self.env, TEST_PID_FILE=str(pid_file), TEST_DMS_READY=str(dms_ready))
        with trace_file.open('w') as trace:
            proc = subprocess.Popen(['bash', '-x', str(ROOT / 'scripts/ubuntu-desktop-shell.sh'), 'run'],
                                    env=env, start_new_session=True,
                                    stdout=subprocess.DEVNULL, stderr=trace)
            try:
                self.wait_for(lambda: dms_ready.exists())
                time.sleep(0.25)
                self.assertIsNone(proc.poll(), 'shell runner exited when desk-notes exited early')
                os.killpg(proc.pid, signal.SIGTERM)
                proc.wait(timeout=5)
            finally:
                self.kill_group(proc)
        exited_pid = pid_file.read_text().strip()
        self.assertNotIn(f'kill -TERM -- {exited_pid}', trace_file.read_text())

    def test_run_kills_stubborn_desk_notes_after_shell_exits(self):
        self.select('dms')
        pid_file = self.home / 'stubborn-qs.pid'
        exiting_marker = self.home / 'dms-exiting'
        (self.bin / 'qs').write_text('''#!/usr/bin/env python3
import os, signal, time
from pathlib import Path
signal.signal(signal.SIGTERM, signal.SIG_IGN)
Path(os.environ['TEST_PID_FILE']).write_text(str(os.getpid()))
while True:
    time.sleep(1)
''')
        (self.bin / 'qs').chmod(0o755)
        (self.bin / 'dms').write_text('''#!/usr/bin/env python3
import os, sys, time
from pathlib import Path
deadline = time.monotonic() + 2
while not Path(os.environ['TEST_PID_FILE']).exists() and time.monotonic() < deadline:
    time.sleep(0.05)
Path(os.environ['TEST_EXITING_MARKER']).write_text('exiting')
sys.exit(42)
''')
        (self.bin / 'dms').chmod(0o755)
        env = dict(self.env, TEST_PID_FILE=str(pid_file), TEST_EXITING_MARKER=str(exiting_marker))
        proc = subprocess.Popen(['bash', str(ROOT / 'scripts/ubuntu-desktop-shell.sh'), 'run'],
                                env=env, start_new_session=True,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            self.wait_for(lambda: exiting_marker.exists())
            exit_code = proc.wait(timeout=2.8)
            self.assertEqual(exit_code, 42)
            qs_pid = int(pid_file.read_text())
            with self.assertRaises(ProcessLookupError):
                os.kill(qs_pid, 0)
        finally:
            self.kill_group(proc)

    def test_run_starts_shell_even_when_notes_path_is_a_file(self):
        self.select('dms')
        notes_parent = self.home / '.config'
        notes_parent.mkdir(parents=True, exist_ok=True)
        (notes_parent / 'desk-notes').write_text('not a directory')
        events = self.home / 'bad-dir-events.jsonl'
        (self.bin / 'qs').write_text('''#!/usr/bin/env python3
import json, os
from pathlib import Path
with Path(os.environ['TEST_EVENTS']).open('a') as f:
    f.write(json.dumps({'label': 'desk-notes', 'pid': os.getpid()}) + '\\n')
''')
        (self.bin / 'qs').chmod(0o755)
        (self.bin / 'dms').write_text('''#!/usr/bin/env python3
import json, os, signal, time
from pathlib import Path
with Path(os.environ['TEST_EVENTS']).open('a') as f:
    f.write(json.dumps({'label': 'dms', 'pid': os.getpid()}) + '\\n')
stopped = False
signal.signal(signal.SIGTERM, lambda *_: globals().update(stopped=True))
while not stopped:
    time.sleep(0.05)
''')
        (self.bin / 'dms').chmod(0o755)
        env = dict(self.env, TEST_EVENTS=str(events))
        proc = subprocess.Popen(['bash', str(ROOT / 'scripts/ubuntu-desktop-shell.sh'), 'run'],
                                env=env, start_new_session=True,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            self.wait_for(lambda: len(self.read_jsonl(events)) >= 1)
            time.sleep(0.2)
            labels = [r['label'] for r in self.read_jsonl(events)]
            self.assertEqual(labels, ['dms'])
            os.killpg(proc.pid, signal.SIGTERM)
            proc.wait(timeout=3)
        finally:
            self.kill_group(proc)


if __name__ == '__main__':
    unittest.main()
