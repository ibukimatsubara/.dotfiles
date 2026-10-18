#!/usr/bin/env python3
"""Exercise crash recovery, monitor changes and compositor shutdown."""
import json
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

    def write_monitors(self, monitors):
        temporary = self.home / 'monitors.tmp'
        temporary.write_text(json.dumps(monitors))
        temporary.replace(self.home / 'monitors.json')

    def monitor_queries(self):
        path = self.home / 'monitor-queries'
        return path.read_text().splitlines() if path.exists() else []

    def watch_monitors(self, initial_ipc_failure=False):
        monitors = [{'name': 'DP-1', 'x': 0, 'y': 0, 'width': 1920, 'height': 1080,
                     'scale': 1, 'transform': 0, 'disabled': False, 'focused': True,
                     'refreshRate': 60, 'activeWorkspace': {'id': 5, 'name': '5'}}]
        self.write_monitors(monitors)
        self.stub('hyprctl', '''#!/bin/sh
test ! -f "$XDG_RUNTIME_DIR/stopped" || exit 1
if [ -f "$XDG_RUNTIME_DIR/initial-ipc-failure" ]; then
 rm "$XDG_RUNTIME_DIR/initial-ipc-failure"
 exit 1
fi
if [ "$#" = 2 ] && [ "$1" = dispatch ] && [ "$2" = forcerendererreload ]; then
 test ! -f "$XDG_RUNTIME_DIR/reload-fails" || exit 1
 printf 'reload\\n' >> "$XDG_RUNTIME_DIR/reloads"
 printf 'ok\\n'
 exit 0
fi
test "$#" = 2 && test "$1" = -j && test "$2" = monitors || exit 2
monitor_snapshot="$(cat "$XDG_RUNTIME_DIR/monitors.json")"
printf '%s\\n' "$monitor_snapshot"
printf '%s\\n' "$monitor_snapshot" >> "$XDG_RUNTIME_DIR/monitor-queries"
''')
        (self.home / 'crashed').touch()
        if initial_ipc_failure:
            (self.home / 'initial-ipc-failure').touch()
        process = self.launch()
        self.wait_for(lambda: len(self.starts()) == 1)
        return process, monitors

    def wait_for_monitor_queries(self, count=3):
        previous = len(self.monitor_queries())
        self.wait_for(lambda: len(self.monitor_queries()) >= previous + count)

    def test_monitor_replacement_restarts_shell_once_after_layout_settles(self):
        process, monitors = self.watch_monitors()
        old_child = int(self.starts()[0])
        monitors[0].update(name='HDMI-A-1', x=1920, width=3440, height=1440)
        self.write_monitors(monitors)
        self.wait_for(lambda: json.dumps(monitors) in self.monitor_queries())
        self.assertEqual(len(self.starts()), 1)
        monitors[0]['x'] = 0
        self.write_monitors(monitors)
        self.wait_for(lambda: len(self.starts()) == 2)
        self.assertEqual((self.home / 'reloads').read_text().splitlines(), ['reload'])
        with self.assertRaises(ProcessLookupError):
            os.kill(old_child, 0)
        # Workspace, focus and usage changes must not restart the shell.
        monitors[0].update(activeWorkspace={'id': 3, 'name': '3'}, focused=False)
        self.write_monitors(monitors)
        self.wait_for_monitor_queries()
        self.assertEqual(len(self.starts()), 2)
        self.assertEqual((self.home / 'reloads').read_text().splitlines(), ['reload'])
        self.assertIsNone(process.poll())

    def test_resolution_scale_position_and_rotation_changes_restart_shell(self):
        process, monitors = self.watch_monitors()
        for starts, change in enumerate(({'width': 3440, 'height': 1440},
                                        {'scale': 1.25}, {'x': 100, 'y': 50},
                                        {'transform': 1}), start=2):
            with self.subTest(change=change):
                monitors[0].update(change)
                self.write_monitors(monitors)
                self.wait_for(lambda: len(self.starts()) == starts)
        self.assertIsNone(process.poll())

    def test_disconnect_waits_for_valid_output_before_restarting_shell(self):
        process, monitors = self.watch_monitors()
        self.write_monitors([])
        self.wait_for_monitor_queries()
        self.assertEqual(len(self.starts()), 1)
        (self.home / 'monitors.json').write_text('invalid JSON')
        self.wait_for_monitor_queries()
        self.assertEqual(len(self.starts()), 1)
        self.assertIsNone(process.poll())
        # Reconnecting the same display must also recreate its surfaces.
        self.write_monitors(monitors)
        self.wait_for(lambda: len(self.starts()) == 2)
        self.wait_for_monitor_queries()
        self.assertEqual(len(self.starts()), 2)

    def test_invalid_monitor_data_does_not_stop_or_restart_shell(self):
        process, monitors = self.watch_monitors()
        for response in ({'monitors': []}, [None], [{}],
                         [dict(monitors[0], width=None)], [dict(monitors[0], scale=0)]):
            with self.subTest(response=response):
                self.write_monitors(response)
                self.wait_for_monitor_queries()
                self.assertIsNone(process.poll())
                self.assertEqual(len(self.starts()), 1)
        self.write_monitors(monitors)
        self.wait_for_monitor_queries()
        self.assertEqual(len(self.starts()), 1)

    def test_failed_reload_keeps_shell_running_until_retry_succeeds(self):
        process, monitors = self.watch_monitors()
        failure = self.home / 'reload-fails'
        failure.touch()
        monitors[0]['width'] = 2560
        self.write_monitors(monitors)
        self.wait_for_monitor_queries(count=8)
        self.assertIsNone(process.poll())
        self.assertEqual(len(self.starts()), 1)
        failure.unlink()
        self.wait_for(lambda: len(self.starts()) == 2)
        self.assertEqual((self.home / 'reloads').read_text().splitlines(), ['reload'])

    def test_monitor_change_is_recovered_even_if_shell_crashes(self):
        process, monitors = self.watch_monitors()
        monitors[0].update(name='HDMI-A-1', width=3440, height=1440)
        self.write_monitors(monitors)
        os.kill(int(self.starts()[0]), signal.SIGKILL)
        self.wait_for(lambda: (self.home / 'reloads').exists())
        self.wait_for(lambda: len(self.starts()) >= 2)
        self.assertIsNone(process.poll())
        self.assertEqual((self.home / 'reloads').read_text().splitlines(), ['reload'])

    def test_initial_ipc_failure_does_not_hide_early_monitor_change(self):
        process, monitors = self.watch_monitors(initial_ipc_failure=True)
        old_child = int(self.starts()[0])
        monitors[0].update(name='HDMI-A-1', width=3440, height=1440)
        self.write_monitors(monitors)
        self.wait_for(lambda: len(self.starts()) == 2)
        self.assertEqual((self.home / 'reloads').read_text().splitlines(), ['reload'])
        with self.assertRaises(ProcessLookupError):
            os.kill(old_child, 0)
        self.wait_for_monitor_queries()
        self.assertEqual(len(self.starts()), 2)
        self.assertIsNone(process.poll())

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
