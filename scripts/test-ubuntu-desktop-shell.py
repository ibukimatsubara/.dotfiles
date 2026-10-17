#!/usr/bin/env python3
"""Exercise shell selection and IPC without touching the running desktop."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
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


if __name__ == '__main__':
    unittest.main()
