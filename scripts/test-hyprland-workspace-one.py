#!/usr/bin/env python3
"""Exercise startup and recovery through the external Hyprland IPC boundary."""
import copy
import importlib.util
import json
from pathlib import Path
import shlex
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('workspace_one', Path(__file__).with_name('hyprland-workspace-one.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Hyprland:
    """A compositor double; application, readiness and placement code stay real."""
    def __init__(self):
        self.now = 0
        self.ready_at = 1
        self.windows = []
        self.launches = []
        self.pending = []
        self.fail_clients = 0
        self.fail_after_launch = False
        self.lose_launch_reply = False
        self.reject_launch = False
        self.fail_launch_connection = False
        self.fail_placement = 0
        self.delay = 0
        self.floated_at_launch = False
        self.backend = 'caelestia'
        self.commands = []
        self.active_workspace = 3
        self.active_window = '0x999'
        self.monitor = dict(name='DP-1', width=1920, height=1080, scale=1,
                            reserved=[10, 44, 10, 10], disabled=False, focused=True)

    def window(self, name, floating=False, workspace=1):
        return dict(address={'pomoru': '0x1', 'calendar': '0x2', 'music': '0x3'}[name],
                    mapped=True, hidden=False, floating=floating,
                    workspace={'id': workspace, 'name': str(workspace)},
                    monitor=0, at=[28, 62], size=[920, 483],
                    **({'class': 'chrome-calendar.notion.com__-Default', 'title': 'Notion Calendar'}
                       if name == 'calendar' else
                       {'class': 'com.dotfiles.' + name, 'title': 'Starting...'}))

    def output(self, args, **kwargs):
        if args[0].endswith('ubuntu-desktop-shell.sh'):
            return self.backend
        assert args[0] == 'hyprctl', args
        args = args[1:]
        self.commands.append(args)
        if args == ['-j', 'monitors']:
            return json.dumps([self.monitor])
        if args == ['-j', 'workspaces']:
            return json.dumps([{'id': 1, 'monitor': 'DP-1'}])
        if args == ['-j', 'layers']:
            names = (['caelestia-background', 'caelestia-topbar']
                     if self.backend == 'caelestia' else ['dms:bar'])
            layers = [dict(namespace=n, w=1920, h=44) for n in names] if self.now >= self.ready_at else []
            return json.dumps({'DP-1': {'levels': {'2': layers}}})
        if args == ['-j', 'clients']:
            if self.fail_clients:
                self.fail_clients -= 1
                raise subprocess.CalledProcessError(1, args)
            for when, name in list(self.pending):
                if self.now >= when:
                    self.windows.append(self.window(name, floating=self.floated_at_launch))
                    self.pending.remove((when, name))
            return json.dumps(self.windows)
        if args[0] == '--batch':
            replies = []
            for command in args[1].split(';'):
                replies.append(self.output(['hyprctl', *shlex.split(command)]))
            return '\n'.join(replies)
        if args[:2] == ['dispatch', 'exec']:
            command = args[2]
            if self.fail_launch_connection:
                self.fail_launch_connection = False
                raise subprocess.CalledProcessError(4, args, output="Couldn't connect to test socket. (4)")
            if self.reject_launch:
                self.reject_launch = False
                return 'Failed to start process'
            self.launches.append((self.now, command))
            if 'calendar.notion.com' in command:
                name = 'calendar'
            elif 'pomoru' in command:
                name = 'pomoru'
            else:
                name = 'music'
            self.pending.append((self.now + self.delay, name))
            self.floated_at_launch = 'float]' in command or '; float;' in command
            if 'workspace 1 silent' not in command:
                raise AssertionError('Applications must target workspace 1 silently')
            if 'no_initial_focus on' not in command:
                self.active_window = name
            if self.fail_after_launch:
                self.fail_after_launch = False
                self.fail_clients = 1
            if self.lose_launch_reply:
                failure = self.lose_launch_reply
                self.lose_launch_reply = False
                if failure == 'read':
                    raise subprocess.CalledProcessError(6, args, output="Couldn't read (6)")
                raise subprocess.TimeoutExpired(args, 10)
            return 'ok'
        if args[0] == 'dispatch':
            command, arg = args[1:]
            if command in ('workspace', 'focuswindow'):
                raise AssertionError('Startup must not change workspace or focus')
            if self.fail_placement:
                self.fail_placement -= 1
                return 'Window not found'
            address = arg.rsplit('address:', 1)[-1]
            window = next(w for w in self.windows if w['address'] == address)
            if command == 'settiled':
                window['floating'] = False
                # Hyprland 0.53 moves a newly tiled floating window to the
                # monitor's active workspace. Recovery must move it back.
                window['workspace']['id'] = self.active_workspace
            elif command == 'movetoworkspacesilent':
                window['workspace']['id'] = int(arg.split(',')[0])
            else:
                raise AssertionError('Unexpected dispatcher: ' + command)
            return 'ok'
        raise AssertionError('Unexpected IPC: ' + repr(args))

    def sleep(self, seconds):
        self.now += seconds


class StartupTests(unittest.TestCase):
    def setUp(self):
        self.hypr = Hyprland()
        self.patchers = [patch.object(m.subprocess, 'check_output', side_effect=self.hypr.output),
                         patch.object(m.time, 'monotonic', side_effect=lambda: self.hypr.now),
                         patch.object(m.time, 'sleep', side_effect=self.hypr.sleep)]
        for patcher in self.patchers:
            patcher.start()
            self.addCleanup(patcher.stop)

    def assert_ready(self):
        self.assertEqual(len(self.hypr.windows), 3)
        self.assertTrue(all(not w['floating'] and w['workspace']['id'] == 1
                            for w in self.hypr.windows))
        self.assertEqual(self.hypr.active_workspace, 3)
        self.assertEqual(self.hypr.active_window, '0x999')

    def test_cold_login_waits_for_shell_and_opens_tiled_without_focus(self):
        self.hypr.ready_at = 5
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 3)
        self.assertTrue(all(when >= 5 for when, _ in self.hypr.launches))
        self.assertTrue(all('; tile;' in command for _, command in self.hypr.launches))

    def test_slow_window_after_sixty_seconds_does_not_leave_floating_windows(self):
        self.hypr.delay = 65
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 3)

    def test_existing_layout_is_preserved_without_launching(self):
        self.hypr.windows = [self.hypr.window(n) for n in ('pomoru', 'calendar', 'music')]
        original = copy.deepcopy(self.hypr.windows)
        m.start()
        self.assertEqual(self.hypr.windows, original)
        self.assertEqual(self.hypr.launches, [])

    def test_floating_windows_are_repaired_on_workspace_one_without_focus(self):
        self.hypr.windows = [self.hypr.window(n, floating=True) for n in ('pomoru', 'calendar', 'music')]
        m.start()
        self.assert_ready()
        self.assertEqual(self.hypr.launches, [])

    def test_transient_placement_error_is_retried(self):
        self.hypr.windows = [self.hypr.window(n, floating=True) for n in ('pomoru', 'calendar', 'music')]
        self.hypr.fail_placement = 1
        m.start()
        self.assert_ready()
        self.assertEqual(self.hypr.launches, [])

    def test_transient_ipc_error_does_not_abort_or_duplicate_apps(self):
        self.hypr.fail_clients = 1
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 3)

    def test_lost_exec_reply_does_not_launch_the_same_app_twice(self):
        self.hypr.lose_launch_reply = True
        self.hypr.delay = 2
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 3)

    def test_read_failure_after_exec_acceptance_does_not_duplicate_apps(self):
        self.hypr.lose_launch_reply = 'read'
        self.hypr.delay = 2
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 3)

    def test_connection_failure_before_exec_acceptance_is_retried(self):
        self.hypr.fail_launch_connection = True
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 3)

    def test_rejected_exec_is_retried(self):
        self.hypr.reject_launch = True
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 3)

    def test_ipc_failure_after_launch_does_not_duplicate_existing_apps(self):
        self.hypr.fail_after_launch = True
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 3)

    def test_desktop_timeout_does_not_launch_apps(self):
        self.hypr.ready_at = 1000
        with self.assertRaisesRegex(RuntimeError, 'desktop'):
            m.start()
        self.assertEqual(self.hypr.launches, [])

    def test_disabled_monitor_does_not_count_as_ready(self):
        self.hypr.monitor['disabled'] = True
        with self.assertRaisesRegex(RuntimeError, 'desktop'):
            m.start()
        self.assertEqual(self.hypr.launches, [])

    def test_dms_fallback_waits_for_its_own_bar(self):
        self.hypr.backend = 'dms'
        m.start()
        self.assert_ready()

    def test_identifies_new_app_ids_before_titles_change(self):
        self.assertEqual(m.identify(self.hypr.window('pomoru')), 'pomoru')
        self.assertEqual(m.identify(self.hypr.window('music')), 'music')
        self.assertIsNone(m.identify({'class': 'com.mitchellh.ghostty', 'title': 'work'}))


if __name__ == '__main__':
    unittest.main()
