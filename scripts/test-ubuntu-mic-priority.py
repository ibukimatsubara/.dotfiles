#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest
import json
import os
import subprocess
import tempfile

class MicTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('mic', Path(__file__).with_name('ubuntu-mic-priority.py'))
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)

    def source(self, ident, name, **props):
        return {'id': ident, 'type': 'PipeWire:Interface:Node', 'info': {'props': {'media.class': 'Audio/Source', 'node.name': name, **props}}}

    def test_sources_exclude_sink_monitors(self):
        nodes = [self.source(1, 'input'), self.source(2, 'output.monitor'), self.source(3, 'monitor', **{'device.class': 'monitor'}), self.source(4, 'virtual', **{'media.class': 'Audio/Source/Virtual'})]
        self.assertEqual([s['name'] for s in self.mod.sources(nodes)], ['input'])

    def test_ordered_preferences_and_no_implicit_fallback(self):
        nodes = self.mod.sources([self.source(1, 'built-in'), self.source(2, 'usb-input')])
        self.assertEqual(self.mod.choose(nodes, ['usb-*', '*'])['id'], 2)
        self.assertIsNone(self.mod.choose(nodes, []))
        self.assertIsNone(self.mod.choose(nodes, ['missing']))

    def test_metadata_avoids_duplicate_change_and_replug_selects_new_id(self):
        data = [self.source(7, 'usb-input'), {'type': 'PipeWire:Interface:Metadata', 'props': {'metadata.name': 'default'}, 'metadata': [{'key': 'default.audio.source', 'value': '{"name":"usb-input"}'}]}]
        self.assertEqual(self.mod.plan(data, ['usb-*'])['status'], 'unchanged')
        self.assertEqual(self.mod.plan([self.source(9, 'usb-input')], ['usb-*'])['target']['id'], 9)
        self.assertEqual(self.mod.plan([], ['usb-*'])['status'], 'no-match')

    def test_cli_dry_run_and_apply_use_only_explicit_target(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dump = root / 'pw-dump'
            dump.write_text("#!/bin/sh\ncat <<'JSON'\n" + json.dumps([self.source(9, 'test-input')]) + "\nJSON\n")
            dump.chmod(0o755)
            wpctl = root / 'wpctl'
            wpctl.write_text('#!/bin/sh\necho "$*" > "$MIC_CALL"\n')
            wpctl.chmod(0o755)
            config = root / 'config.json'
            config.write_text('{"preferred_sources":["test-*"]}')
            env = {**os.environ, 'PATH': str(root) + os.pathsep + os.environ['PATH'], 'MIC_CALL': str(root / 'call')}
            command = ['python3', str(Path(__file__).with_name('ubuntu-mic-priority.py')), '--once', '--config', str(config)]
            dry = subprocess.run(command + ['--dry-run'], env=env, capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(dry.stdout)['status'], 'would-select')
            self.assertFalse((root / 'call').exists())
            subprocess.run(command, env=env, capture_output=True, text=True, check=True)
            self.assertEqual((root / 'call').read_text().strip(), 'set-default 9')

if __name__ == '__main__':
    unittest.main()
