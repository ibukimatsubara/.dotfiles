#!/usr/bin/env python3
"""Exercise Linux opt-in and rollback without starting real user services."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent


class SetupTests(unittest.TestCase):
    def test_linux_enable_disable_and_failure(self):
        with tempfile.TemporaryDirectory(prefix='metrics setup ') as temp:
            root = Path(temp)
            config = root / 'config/mibuki-metrics'
            config.mkdir(parents=True)
            sample = json.loads((REPO / 'scripts/mibuki-metrics.config.example.json').read_text())
            sample['services'][0]['analytics'].update(project_id='test-project', dataset_id='analytics_123')
            (config / 'config.json').write_text(json.dumps(sample))
            binary = root / 'bin'
            binary.mkdir()
            systemctl = binary / 'systemctl'
            systemctl.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> "$HOME/calls"\n[[ "$*" != *"enable --now"* || "${FAIL_ENABLE:-0}" != 1 ]]\n')
            systemctl.chmod(0o755)
            env = {**os.environ, 'HOME': str(root), 'XDG_CONFIG_HOME': str(root / 'config'),
                   'PATH': str(binary) + ':' + os.environ['PATH']}
            def run(flag, **extra):
                return subprocess.run(['bash', str(REPO / 'scripts/setup-mibuki-metrics.sh'), flag],
                                      env={**env, **extra}, capture_output=True, text=True)
            result = run('--enable')
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertTrue((config / 'enabled').exists())
            units = root / 'config/systemd/user'
            timer = (units / 'mibuki-metrics.timer').read_text()
            self.assertIn('OnCalendar=daily', timer)
            self.assertIn('Persistent=true', timer)
            self.assertNotIn('OnUnitActiveSec=', timer)
            self.assertNotIn('OnStartupSec=', timer)
            self.assertIn('mibuki-metrics.sh', (units / 'mibuki-metrics.service').read_text())
            self.assertIn('--user enable --now mibuki-metrics.timer', (root / 'calls').read_text())
            self.assertEqual(run('--disable').returncode, 0)
            self.assertFalse((config / 'enabled').exists())
            self.assertTrue((config / 'config.json').exists())
            result = run('--enable', FAIL_ENABLE='1')
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((config / 'enabled').exists())


if __name__ == '__main__':
    unittest.main()
