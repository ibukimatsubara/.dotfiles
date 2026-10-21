#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

class UsageTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('usage', Path(__file__).with_name('codex-usage.py'))
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)

    def record(self, name, timestamp, primary=58, secondary=10, limits=None):
        file = self.home / 'sessions/2026/10/17' / name
        file.parent.mkdir(parents=True, exist_ok=True)
        limits = limits or {'primary': {'used_percent': primary, 'window_minutes': 300, 'resets_at': 1792250000}, 'secondary': {'used_percent': secondary, 'window_minutes': 10080}}
        event = {'timestamp': timestamp, 'payload': {'rate_limits': {'limit_id': 'codex', **limits}}}
        file.write_text('private conversation\n' + json.dumps(event) + '\n{bad\n')

    def test_missing_is_unavailable(self):
        self.assertEqual(self.mod.snapshot(self.home, now=1792231200)['label'], '--')

    def test_freshest_snapshot_uses_weekly_window(self):
        self.record('a.jsonl', '2026-10-17T10:00:00Z', 99, 20)
        self.record('b.jsonl', '2026-10-17T09:00:00Z', 10, 70)
        result = self.mod.snapshot(self.home, now=1792231200)
        self.assertEqual(result['label'], '80%')
        self.assertEqual(result['remaining_percent'], 80)
        self.assertFalse(result['stale'])
        self.assertNotIn('private', json.dumps(result))

    def test_weekly_window_as_primary(self):
        self.record('a.jsonl', '2026-10-17T10:00:00Z', limits={'primary': {'used_percent': 67.0, 'window_minutes': 10080, 'resets_at': 1792600000}, 'secondary': None})
        self.assertEqual(self.mod.snapshot(self.home, now=1792231200)['label'], '33%')

    def test_passed_reset_is_full(self):
        self.record('a.jsonl', '2026-10-17T10:00:00Z', limits={'primary': {'used_percent': 67.0, 'window_minutes': 10080, 'resets_at': 1792230000}})
        result = self.mod.snapshot(self.home, now=1792231200)
        self.assertEqual(result['label'], '100%')
        self.assertIn('reset since snapshot', result['tooltip'])

    def test_stale_snapshot_is_explicit(self):
        self.record('a.jsonl', '2026-10-17T10:00:00Z', 20, 90)
        result = self.mod.snapshot(self.home, now=1792404000)
        self.assertTrue(result['available'])
        self.assertTrue(result['stale'])
        self.assertEqual(result['label'], '10%')
        self.assertIn('Stale', result['tooltip'])

    def test_only_five_hour_window_is_unavailable(self):
        self.record('a.jsonl', '2026-10-17T10:00:00Z', limits={'primary': {'used_percent': 10, 'window_minutes': 300}})
        self.assertFalse(self.mod.snapshot(self.home, now=1792231200)['available'])

    def test_malformed_windows_are_skipped(self):
        self.record('a.jsonl', '2026-10-17T10:00:00Z', 10, 'secret')
        self.assertFalse(self.mod.snapshot(self.home, now=1792231200)['available'])

if __name__ == '__main__':
    unittest.main()
