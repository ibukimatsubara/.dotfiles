#!/usr/bin/env python3
"""Check startup reuse and layout ordering without launching applications."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('workspace_one', Path(__file__).with_name('hyprland-workspace-one.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class StartupTests(unittest.TestCase):
    def test_existing_windows_are_reused(self):
        clients = [dict(address=str(i), workspace={'id': 1}, **data) for i, data in enumerate([
            {'class': 'com.mitchellh.ghostty', 'title': 'pomoru'},
            {'class': 'com.mitchellh.ghostty', 'title': 'Song | cliamp'},
            {'class': 'chrome-calendar.notion.com__-Default', 'title': 'Calendar'},
        ])]
        with patch.object(m, 'clients', return_value=clients), patch.object(m, 'dispatch') as dispatch:
            m.start()
        dispatch.assert_not_called()

    def test_layout_has_calendar_right_and_music_below_timer(self):
        with patch.object(m, 'dispatch') as dispatch:
            m.arrange({'pomoru': '0x1', 'calendar': '0x2', 'music': '0x3'})
        calls = [call.args for call in dispatch.call_args_list]
        right = calls.index(('layoutmsg', 'preselect r'))
        down = calls.index(('layoutmsg', 'preselect d'))
        self.assertLess(right, down)
        self.assertEqual(calls[right + 1], ('settiled', 'address:0x2'))
        self.assertEqual(calls[down + 1], ('settiled', 'address:0x3'))

    def test_unrelated_browser_and_terminals_are_ignored(self):
        self.assertIsNone(m.identify({'class': 'google-chrome', 'title': 'Notion'}))
        self.assertIsNone(m.identify({'class': 'com.mitchellh.ghostty', 'title': 'work'}))

    def test_cold_login_launches_once_and_waits_before_arranging(self):
        ready = [dict(address=str(i), workspace={'id': 1}, **data) for i, data in enumerate([
            {'class': 'dotfiles-pomoru'}, {'class': 'dotfiles-music'},
            {'class': 'chrome-calendar.notion.com__-Default'},
        ])]
        with patch.object(m, 'clients', side_effect=[[], [], ready]), \
                patch.object(m, 'dispatch') as dispatch, \
                patch.object(m, 'arrange') as arrange, patch.object(m.time, 'sleep'):
            m.start()
        self.assertEqual(dispatch.call_count, 3)
        commands = [call.args[1] for call in dispatch.call_args_list]
        self.assertTrue(all(cmd.startswith('[workspace 1 silent; float]') for cmd in commands))
        self.assertTrue(any('--app=https://calendar.notion.com' in cmd for cmd in commands))
        arrange.assert_called_once_with({'pomoru': '0', 'music': '1', 'calendar': '2'})

    def test_timeout_does_not_rearrange_partial_windows(self):
        with patch.object(m, 'clients', return_value=[]), \
                patch.object(m, 'dispatch'), patch.object(m, 'arrange') as arrange, \
                patch.object(m.time, 'monotonic', side_effect=[0, 61]):
            with self.assertRaisesRegex(RuntimeError, 'timed out'):
                m.start()
        arrange.assert_not_called()


if __name__ == '__main__':
    unittest.main()
