#!/usr/bin/env python3
"""Deterministic backend tests; no desktop session or sleeps required."""
import concurrent.futures
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('timer', Path(__file__).with_name('ubuntu-break-timer.py'))
timer = importlib.util.module_from_spec(SPEC)
if SPEC.loader and SPEC.origin and Path(SPEC.origin).exists():
    SPEC.loader.exec_module(timer)


class TimerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.backend = timer.Timer(Path(self.tmp.name), timer.DEFAULTS)

    def test_manual_phases_survive_restart(self):
        self.assertEqual(self.backend.run('start-work', 100)['remaining_seconds'], 1800)
        other = timer.Timer(Path(self.tmp.name), timer.DEFAULTS)
        self.assertEqual(other.run('status', 1900)['state'], 'wait-break')
        self.assertEqual(other.run('toggle', 1900)['state'], 'break')
        self.assertEqual(other.run('status', 2080)['state'], 'wait-work')
        self.assertEqual(other.run('toggle', 2080)['state'], 'work')

    def test_toggle_early_and_stop(self):
        for state in ('work', 'break', 'work'):
            self.assertEqual(self.backend.run('toggle', 100)['state'], state)
        self.assertEqual(self.backend.run('stop', 100)['state'], 'off')

    def test_snooze_extends_current_phase_and_waiting(self):
        self.backend.run('start-work', 100)
        self.assertEqual(self.backend.run('snooze', 200)['remaining_seconds'], 1880)
        self.backend.run('status', 2080)
        self.assertEqual(self.backend.run('snooze', 2080)['remaining_seconds'], 180)
        self.assertEqual(self.backend.run('status', 2260)['state'], 'wait-break')

    def test_status_queues_effects_and_concurrent_workers_claim_once(self):
        self.backend.run('start-work', 100)
        self.backend.run('status', 1840)
        self.backend.run('status', 1900)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            batches = list(pool.map(lambda _: self.backend.claim_events(), range(16)))
        events = [event for batch in batches for event in batch]
        self.assertEqual([e['kind'] for e in events], ['start', 'warning', 'complete'])
        self.assertEqual(self.backend.claim_events(), [])

    def test_expired_phase_does_not_emit_stale_warning(self):
        self.backend.run('start-work', 100)
        self.backend.claim_events()
        self.backend.run('status', 2000)
        self.assertEqual([e['kind'] for e in self.backend.claim_events()], ['complete'])

    def test_auto_start_uses_current_time_after_suspend(self):
        backend = timer.Timer(Path(self.tmp.name), dict(timer.DEFAULTS, auto_start_break=True))
        backend.run('start-work', 100)
        self.assertEqual(backend.run('status', 10000)['remaining_seconds'], 180)

    def test_cli_isolated_xdg_override_and_private_state(self):
        root = Path(self.tmp.name)
        config = root / 'config/dotfiles'
        config.mkdir(parents=True)
        (config / 'break-timer.json').write_text(json.dumps({'work_minutes': 1}))
        env = dict(os.environ, XDG_CONFIG_HOME=str(root / 'config'), XDG_STATE_HOME=str(root / 'state'))
        command = [sys.executable, str(Path(__file__).with_name('ubuntu-break-timer.py'))]
        started = subprocess.run(command + ['start-work', '--now', '100'], env=env, capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(started.stdout)['remaining_seconds'], 60)
        expired = subprocess.run(command + ['status', '--now', '160'], env=env, capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(expired.stdout)['state'], 'wait-break')
        self.assertEqual((root / 'state/dotfiles/break-timer.json').stat().st_mode & 0o777, 0o600)
        self.assertEqual((root / 'state/dotfiles').stat().st_mode & 0o777, 0o700)

    def test_corrupt_state_and_config(self):
        self.backend.directory.joinpath('break-timer.json').write_text('{bad')
        self.assertEqual(self.backend.run('status', 100)['state'], 'off')
        self.backend.directory.joinpath('break-timer.json').write_text(json.dumps({'state': 'work', 'deadline': 'oops'}))
        self.assertEqual(self.backend.run('status', 100)['state'], 'off')
        for patch in ({'work_minutes': True}, {'break_minutes': -1}, {'warning_seconds': float('nan')}, {'auto_start_work': 1}):
            with self.assertRaises(ValueError):
                timer.validate_config(dict(timer.DEFAULTS, **patch))


if __name__ == '__main__':
    unittest.main()
