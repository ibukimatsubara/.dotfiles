#!/usr/bin/env python3
"""Exercise crash recovery, duplicate prevention and compositor shutdown."""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest

SCRIPT = Path(__file__).with_name('ubuntu-desktop-watch.py')


class WatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, XDG_RUNTIME_DIR=str(self.home),
                        XDG_STATE_HOME=str(self.home / 'state'),
                        HYPRLAND_INSTANCE_SIGNATURE='watch-test',
                        PATH=str(self.bin) + ':' + os.environ['PATH'])
        self.stub('hyprctl', '#!/bin/sh\ntest ! -f "$XDG_RUNTIME_DIR/stopped"\n')
        self.command = self.bin / 'shell'
        self.stub('shell', '''#!/bin/sh
printf '%s\n' "$$" >> "$XDG_RUNTIME_DIR/starts"
if [ ! -f "$XDG_RUNTIME_DIR/crashed" ]; then
 touch "$XDG_RUNTIME_DIR/crashed"
 exit 42
fi
exec sleep 120
''')

    def stub(self, name, source):
        target = self.bin / name
        target.write_text(source)
        target.chmod(0o755)

    def launch(self):
        process = subprocess.Popen(['python3', str(SCRIPT), '--', str(self.command)],
                                   env=self.env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(self.stop, process)
        return process

    def stop(self, process):
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=8)

    def wait_for(self, predicate, timeout=9):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.05)
        self.fail('Timed out waiting for supervisor')

    def starts(self):
        path = self.home / 'starts'
        return path.read_text().splitlines() if path.exists() else []

    def test_recovers_crash_and_rejects_duplicate_watcher(self):
        process = self.launch()
        self.wait_for(lambda: len(self.starts()) >= 2)
        self.assertIsNone(process.poll())
        duplicate = self.launch()
        self.assertEqual(duplicate.wait(timeout=3), 0)
        self.assertEqual(len(self.starts()), 2)
        child = int(self.starts()[-1])
        process.terminate()
        process.wait(timeout=8)
        with self.assertRaises(ProcessLookupError):
            os.kill(child, 0)
        self.assertEqual(len(self.starts()), 2)

    def test_ipc_failure_does_not_stop_a_live_compositor(self):
        compositor = subprocess.Popen(['sleep', '120'])
        self.addCleanup(self.stop, compositor)
        directory = self.home / 'hypr' / 'watch-test'
        directory.mkdir(parents=True)
        (directory / 'hyprland.lock').write_text(str(compositor.pid) + '\nwayland-test\n')
        self.stub('hyprctl', '#!/bin/sh\nexit 1\n')
        (self.home / 'crashed').touch()
        process = self.launch()
        self.wait_for(lambda: len(self.starts()) == 1, timeout=3)
        time.sleep(1)
        self.assertIsNone(process.poll())
        compositor.terminate()
        compositor.wait(timeout=3)
        self.assertEqual(process.wait(timeout=8), 0)

    def test_compositor_exit_stops_shell_without_restart(self):
        (self.home / 'crashed').touch()
        process = self.launch()
        self.wait_for(lambda: len(self.starts()) == 1)
        (self.home / 'stopped').touch()
        self.assertEqual(process.wait(timeout=8), 0)
        self.assertEqual(len(self.starts()), 1)
        with self.assertRaises(ProcessLookupError):
            os.kill(int(self.starts()[0]), 0)


if __name__ == '__main__':
    unittest.main()
