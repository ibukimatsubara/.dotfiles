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

    def record(self, name, timestamp, primary=58, secondary=10):
        file = self.home / 'sessions/2026/10/17' / name
        file.parent.mkdir(parents=True, exist_ok=True)
        event = {'timestamp': timestamp, 'payload': {'rate_limits': {'limit_id': 'codex', 'primary': {'used_percent': primary, 'window_minutes': 300, 'resets_at': 1792250000}, 'secondary': {'used_percent': secondary, 'window_minutes': 10080}}}}
        file.write_text('private conversation\n' + json.dumps(event) + '\n{bad\n')

    def test_missing_is_unavailable(self):
        self.assertEqual(self.mod.snapshot(self.home, now=1792231200)['label'], '--')

    def test_freshest_snapshot_and_tightest_window(self):
        self.record('a.jsonl', '2026-10-17T10:00:00Z')
        self.record('b.jsonl', '2026-10-17T09:00:00Z', 99)
        result = self.mod.snapshot(self.home, now=1792231200)
        self.assertEqual(result['label'], '42%')
        self.assertEqual(result['remaining_percent'], 42)
        self.assertFalse(result['stale'])
        self.assertNotIn('private', json.dumps(result))

    def test_stale_snapshot_is_explicit(self):
        self.record('a.jsonl', '2026-10-17T10:00:00Z', 20, 90)
        result = self.mod.snapshot(self.home, now=1792404000)
        self.assertTrue(result['available'])
        self.assertTrue(result['stale'])
        self.assertEqual(result['label'], '10% stale')

    def test_malformed_windows_are_skipped(self):
        self.record('a.jsonl', '2026-10-17T10:00:00Z', 'secret', 90)
        self.assertFalse(self.mod.snapshot(self.home, now=1792231200)['available'])

if __name__ == '__main__':
    unittest.main()
