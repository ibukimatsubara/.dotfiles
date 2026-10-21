#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

NOW = 1792231200


class UsageTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('usage', Path(__file__).with_name('claude-usage.py'))
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.file = Path(self.tmp.name) / 'rate-limits.json'

    def write(self, seven_day, captured_at=NOW - 60):
        self.file.write_text(json.dumps({'captured_at': captured_at, 'rate_limits': {
            'five_hour': {'used_percentage': 90, 'resets_at': NOW + 600}, 'seven_day': seven_day}}))

    def test_missing_is_unavailable(self):
        result = self.mod.snapshot(self.file, now=NOW)
        self.assertFalse(result['available'])
        self.assertEqual(result['label'], '--')

    def test_weekly_remaining(self):
        self.write({'used_percentage': 12.4, 'resets_at': NOW + 86400})
        result = self.mod.snapshot(self.file, now=NOW)
        self.assertEqual(result['label'], '88%')
        self.assertFalse(result['stale'])
        self.assertIn('resets', result['tooltip'])

    def test_passed_reset_is_full(self):
        self.write({'used_percentage': 80, 'resets_at': NOW - 1})
        self.assertEqual(self.mod.snapshot(self.file, now=NOW)['label'], '100%')

    def test_stale_snapshot_keeps_value(self):
        self.write({'used_percentage': 40, 'resets_at': NOW + 86400}, captured_at=NOW - 7200)
        result = self.mod.snapshot(self.file, now=NOW)
        self.assertTrue(result['stale'])
        self.assertEqual(result['label'], '60%')
        self.assertIn('Stale', result['tooltip'])

    def test_malformed_snapshot_is_unavailable(self):
        self.write({'used_percentage': 'secret'})
        self.assertFalse(self.mod.snapshot(self.file, now=NOW)['available'])
        self.file.write_text('{bad')
        self.assertFalse(self.mod.snapshot(self.file, now=NOW)['available'])

if __name__ == '__main__':
    unittest.main()
