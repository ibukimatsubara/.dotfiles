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


ADDRESSES = {'pomoru': '0x1', 'status': '0x2', 'music': '0x3', 'browser': '0x4'}
DASHBOARD = ('pomoru', 'browser', 'status', 'music')


class Hyprland:
    """A compositor double; application, readiness and placement code stay real."""
    def __init__(self):
        self.now = 0
        self.ready_at = 1
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
        self.preselect = None
        self.never = set()
        self.extra_browser = False
        self.splits = []
        self.ratios = {}
        # The user's own window, focused on another workspace during login.
        self.windows = [dict(address='0x999', mapped=True, hidden=False, floating=False,
                             workspace={'id': 3, 'name': '3'}, monitor=0, at=[0, 0], size=[1, 1],
                             **{'class': 'com.mitchellh.ghostty', 'title': 'work'})]
        self.monitor = dict(name='DP-1', width=1920, height=1080, scale=1,
                            reserved=[10, 44, 10, 10], disabled=False, focused=True)

    def window(self, name, floating=False, workspace=1):
        return dict(address=ADDRESSES[name],
                    mapped=True, hidden=False, floating=floating,
                    workspace={'id': workspace, 'name': str(workspace)},
                    monitor=0, at=[28, 62], size=[920, 483],
                    **({'class': 'com.dotfiles.status', 'title': '~/Mibuki/mibuki-status-board'}
                       if name == 'status' else
                       {'class': 'zen', 'title': 'ChatGPT — Zen Browser'}
                       if name == 'browser' else
                       {'class': 'com.dotfiles.' + name, 'title': 'Starting...'}))

    def name_of(self, address):
        return next((name for name, a in ADDRESSES.items() if a == address), address)

    def output(self, args, **kwargs):
        if args[0].endswith('ubuntu-desktop-shell.sh'):
            return self.backend
        assert args[0] == 'hyprctl', args
        args = args[1:]
        self.commands.append(args)
        if args == ['-j', 'monitors']:
            return json.dumps([self.monitor])
        if args == ['-j', 'activewindow']:
            return json.dumps({'address': self.active_window} if self.active_window else {})
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
                    # Dwindle splits the focused tile on the same workspace
                    # toward the preselected side.
                    focused = next((w for w in self.windows if w['address'] == self.active_window), None)
                    target = (self.name_of(focused['address'])
                              if focused and focused['workspace']['id'] == 1 and not focused['floating'] else None)
                    self.splits.append((name, target, self.preselect))
                    self.preselect = None
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
            if 'mibuki-status-board' in command:
                name = 'status'
            elif 'ubuntu-app-launch.sh zen' in command:
                name = 'browser'
            elif 'pomoru' in command:
                name = 'pomoru'
            else:
                name = 'music'
            if name not in self.never:
                self.pending.append((self.now + self.delay, name))
            if name == 'browser' and self.extra_browser:
                # Session restore maps another browser window first.
                restored = self.window('browser')
                restored['address'] = '0x60'
                self.windows.append(restored)
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
            command, arg = args[1], ' '.join(args[2:])
            if command == 'workspace':
                raise AssertionError('Startup must not switch workspaces directly')
            if command == 'layoutmsg':
                verb, value = arg.split(' ', 1)
                if verb != 'preselect':
                    raise AssertionError('Unexpected layoutmsg: ' + arg)
                self.preselect = value if value in 'lrud' else None
                return 'ok'
            if command == 'splitratio':
                self.ratios[self.name_of(self.active_window)] = arg
                return 'ok'
            if self.fail_placement:
                self.fail_placement -= 1
                return 'Window not found'
            address = arg.rsplit('address:', 1)[-1]
            window = next(w for w in self.windows if w['address'] == address)
            if command == 'focuswindow':
                self.active_window = address
                self.active_workspace = window['workspace']['id']
            elif command == 'settiled':
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
                         patch.object(m.time, 'sleep', side_effect=self.hypr.sleep),
                         # Never read the real Zen profile from tests.
                         patch.object(m, 'zen_session_urls', side_effect=lambda: self.session_urls)]
        self.session_urls = {'about:blank'}
        for patcher in self.patchers:
            patcher.start()
            self.addCleanup(patcher.stop)

    def dashboard(self):
        return [w for w in self.hypr.windows if w['address'] in ADDRESSES.values()]

    def assert_ready(self):
        self.assertEqual(len(self.dashboard()), 4)
        self.assertTrue(all(not w['floating'] and w['workspace']['id'] == 1
                            for w in self.dashboard()))
        self.assertEqual(self.hypr.active_workspace, 3)
        self.assertEqual(self.hypr.active_window, '0x999')

    def test_cold_login_waits_for_shell_and_opens_tiled(self):
        self.hypr.ready_at = 5
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 4)
        self.assertTrue(all(when >= 5 for when, _ in self.hypr.launches))
        self.assertTrue(all('; tile;' in command for _, command in self.hypr.launches))

    def test_cold_login_builds_browser_pomoru_music_status_columns(self):
        self.hypr.delay = 2
        m.start()
        # browser | (pomoru / music) | status, built by splitting pomoru.
        self.assertEqual(self.hypr.splits, [('pomoru', None, None), ('browser', 'pomoru', 'l'),
                                            ('status', 'pomoru', 'r'), ('music', 'pomoru', 'd')])
        self.assertEqual(self.hypr.ratios, {'browser': f'exact {m.BROWSER_RATIO}'})
        self.assert_ready()

    def test_without_prior_focus_the_browser_is_focused(self):
        self.hypr.active_window = None
        m.start()
        self.assertEqual(self.hypr.active_window, ADDRESSES['browser'])

    def test_zen_window_elsewhere_is_left_alone(self):
        other = self.hypr.window('browser', workspace=5)
        other['address'] = '0x50'
        self.hypr.windows.append(other)
        m.start()
        self.assertEqual(other['workspace']['id'], 5)
        # Zen is already running elsewhere: ask it for a window, not a tab.
        browser = next(command for _, command in self.hypr.launches if 'chatgpt.com' in command)
        self.assertIn('zen --new-window https://chatgpt.com/dots/home', browser)
        self.assert_ready()

    def test_cold_zen_opens_the_url_without_a_second_window(self):
        m.start()
        browser = next(command for _, command in self.hypr.launches if 'chatgpt.com' in command)
        self.assertIn('zen https://chatgpt.com/dots/home', browser)

    def test_late_apps_do_not_block_the_rest_or_resize_an_unexpected_split(self):
        self.hypr.delay = 25
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 4)
        self.assertEqual(self.hypr.ratios, {})

    def test_app_that_never_maps_still_restores_focus_and_clears_preselect(self):
        self.hypr.never = {'music'}
        with self.assertRaisesRegex(RuntimeError, 'music: not detected'):
            m.start()
        self.assertEqual(self.hypr.active_window, '0x999')
        self.assertEqual(self.hypr.active_workspace, 3)
        self.assertIsNone(self.hypr.preselect)
        self.assertEqual(self.hypr.ratios, {})

    def test_session_restored_browser_window_is_not_claimed_twice(self):
        # Restored windows still tile on Space 1 (documented); only one is claimed.
        self.hypr.extra_browser = True
        self.hypr.delay = 2
        m.start()
        self.assertEqual(len([w for w in self.hypr.windows if w['class'] == 'zen']), 2)
        self.assertEqual(len(self.hypr.launches), 4)
        self.assertEqual(self.hypr.active_window, '0x999')

    def test_restored_session_with_the_page_does_not_add_another_tab(self):
        self.session_urls = {'https://chatgpt.com/dots/home'}
        m.start()
        browser = next(command for _, command in self.hypr.launches if 'ubuntu-app-launch.sh zen' in command)
        self.assertTrue(browser.endswith('ubuntu-app-launch.sh zen'))
        self.assert_ready()

    def test_unreadable_session_still_opens_the_page(self):
        for error in (OSError('missing'), TypeError('tabs is null')):
            with patch.object(m, 'zen_session_urls', side_effect=error):
                command = m.browser_command(['launch', 'zen'], zen_running=False)
            self.assertEqual(command, ['launch', 'zen', m.BROWSER_URL])

    def test_status_board_falls_back_to_a_shell_in_its_directory(self):
        m.start()
        status = next(command for _, command in self.hypr.launches if 'mibuki-status-board' in command)
        self.assertTrue(status.endswith(
            "ghostty --class=com.dotfiles.status -e zsh -c 'cd " + str(m.STATUS_BOARD)
            + " && ./mibuki-status-board; exec zsh'"))

    def test_mozlz4_decoder_expands_back_references(self):
        # Literals "abc" then a 6-byte match at offset 3.
        self.assertEqual(m.lz4_block(bytes([0x32]) + b'abc' + bytes([3, 0])), b'abcabcabc')

    def test_closed_browser_claim_is_released_for_a_replacement(self):
        self.hypr.extra_browser = True
        self.hypr.delay = 2
        real = self.hypr.output

        def close_restored(args, **kwargs):
            # The first Zen window (e.g. a crash-restore page) closes.
            if args[1:] == ['-j', 'clients'] and any(w['address'] == '0x4' for w in self.hypr.windows):
                self.hypr.windows = [w for w in self.hypr.windows if w['address'] != '0x60']
            return real(args, **kwargs)
        with patch.object(m.subprocess, 'check_output', side_effect=close_restored):
            m.start()
        self.assert_ready()

    def test_focus_restore_retries_after_ipc_failure(self):
        self.hypr.delay = 2
        real = self.hypr.output
        failed = []

        def flaky(args, **kwargs):
            if args[:2] == ['hyprctl', '--batch'] and 'preselect x' in args[2] and not failed:
                failed.append(args)
                raise subprocess.CalledProcessError(1, args)
            return real(args, **kwargs)
        with patch.object(m.subprocess, 'check_output', side_effect=flaky):
            m.start()
        self.assertTrue(failed)
        self.assertEqual(self.hypr.active_window, '0x999')

    def test_slow_windows_do_not_leave_floating_windows(self):
        self.hypr.delay = 15
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 4)

    def test_existing_layout_is_preserved_without_launching(self):
        self.hypr.windows += [self.hypr.window(n) for n in DASHBOARD]
        original = copy.deepcopy(self.hypr.windows)
        m.start()
        self.assertEqual(self.hypr.windows, original)
        self.assertEqual(self.hypr.launches, [])
        self.assertFalse(any('focuswindow' in ' '.join(c) for c in self.hypr.commands))

    def test_floating_windows_are_repaired_on_workspace_one_without_focus(self):
        self.hypr.windows += [self.hypr.window(n, floating=True) for n in DASHBOARD]
        m.start()
        self.assert_ready()
        self.assertEqual(self.hypr.launches, [])

    def test_transient_placement_error_is_retried(self):
        self.hypr.windows += [self.hypr.window(n, floating=True) for n in DASHBOARD]
        self.hypr.fail_placement = 1
        m.start()
        self.assert_ready()
        self.assertEqual(self.hypr.launches, [])

    def test_transient_ipc_error_does_not_abort_or_duplicate_apps(self):
        self.hypr.fail_clients = 1
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 4)

    def test_lost_exec_reply_does_not_launch_the_same_app_twice(self):
        self.hypr.lose_launch_reply = True
        self.hypr.delay = 2
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 4)

    def test_read_failure_after_exec_acceptance_does_not_duplicate_apps(self):
        self.hypr.lose_launch_reply = 'read'
        self.hypr.delay = 2
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 4)

    def test_connection_failure_before_exec_acceptance_is_retried(self):
        self.hypr.fail_launch_connection = True
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 4)

    def test_rejected_exec_is_retried(self):
        self.hypr.reject_launch = True
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 4)

    def test_ipc_failure_after_launch_does_not_duplicate_existing_apps(self):
        self.hypr.fail_after_launch = True
        m.start()
        self.assert_ready()
        self.assertEqual(len(self.hypr.launches), 4)

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
        self.assertEqual(m.identify(self.hypr.window('browser')), 'browser')
        self.assertIsNone(m.identify({'class': 'com.mitchellh.ghostty', 'title': 'work'}))


if __name__ == '__main__':
    unittest.main()
