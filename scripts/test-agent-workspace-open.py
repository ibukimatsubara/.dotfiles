#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('routing', Path(__file__).with_name('agent-workspace-open.py'))
routing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(routing)


def window(identifier, bundle, workspace, title='', pid=10):
    return {'window-id': identifier, 'app-bundle-id': bundle,
            'app-pid': pid, 'workspace': workspace, 'window-title': title}


class RoutingTests(unittest.TestCase):
    def test_existing_document_window_is_never_moved(self):
        existing = window(2, 'com.apple.TextEdit', '3', 'report.txt')
        self.assertIsNone(routing.select_new_window({'2'}, [existing], 'com.apple.TextEdit', ['report.txt']))

    def test_unrelated_app_and_document_are_not_selected(self):
        items = [window(2, 'com.apple.finder', '3', 'report.txt'),
                 window(3, 'com.apple.TextEdit', '3', 'different.txt')]
        self.assertIsNone(routing.select_new_window(set(), items, 'com.apple.TextEdit', ['report.txt']))

    def test_ambiguous_new_windows_are_not_selected(self):
        items = [window(i, 'com.google.Chrome', '3') for i in [2, 3]]
        self.assertIsNone(routing.select_new_window(set(), items, 'com.google.Chrome', []))

    @patch.object(routing.time, 'sleep')
    @patch.object(routing.subprocess, 'run')
    @patch.object(routing, 'launch', return_value=0)
    @patch.object(routing, 'windows')
    def test_destination_follows_origin_moved_after_launch(self, query, launch, run, sleep):
        origin = window(1, 'com.mitchellh.ghostty', '1')
        moved = window(1, 'com.mitchellh.ghostty', '4')
        result = window(2, 'com.apple.TextEdit', '3', 'report.txt')
        query.side_effect = [[origin], [moved, result]]
        self.assertEqual(routing.route('open', ['report.txt'], ('com.apple.TextEdit', ['report.txt']), '1', '10'), 0)
        run.assert_called_once_with(['aerospace', 'move-node-to-workspace', '4', '--window-id', '2'], check=True, timeout=4)

    @patch.object(routing, 'launch')
    @patch.object(routing, 'windows', return_value=[])
    def test_closed_origin_does_not_open_anything(self, query, launch):
        self.assertEqual(routing.route('open', ['report.txt'], ('com.apple.TextEdit', ['report.txt']), '1', '10'), 75)
        launch.assert_not_called()

    def test_reused_id_in_another_process_is_not_origin(self):
        self.assertIsNone(routing.origin_workspace([window(1, 'com.mitchellh.ghostty', '1', pid=11)], '1', '10'))

    @patch.object(routing.subprocess, 'call')
    @patch.object(routing, 'route')
    @patch.object(routing, 'request_target', return_value=('com.electron.aqua-voice', []))
    @patch.dict(routing.os.environ, {'AGENT_ORIGIN_WINDOW_ID': '1', 'AGENT_ORIGIN_APP_PID': '10'})
    @patch.object(routing.sys, 'argv', ['helper', 'open', '-a', 'Aqua Voice', 'report.txt'])
    def test_aqua_voice_is_never_routed(self, target, route, call):
        call.return_value = 0
        self.assertEqual(routing.main(), 0)
        route.assert_not_called()

    def test_code_goto_title_does_not_include_line_number(self):
        self.assertEqual(routing.request_target('code', ['--goto', '/tmp/report.txt:12:3']), ('com.microsoft.VSCode', ['report.txt']))

    def test_code_queries_and_reuse_are_passthrough(self):
        for args in [['--version'], ['--list-extensions'], ['--reuse-window', '/tmp/project'], ['--wait', 'report.txt']]:
            self.assertIsNone(routing.request_target('code', args))

    def test_multiple_open_targets_are_not_guessed(self):
        self.assertIsNone(routing.request_target('open', ['a.pdf', 'b.pdf']))


class LauncherTests(unittest.TestCase):
    def capture(self, term='ghostty', tmux='', nested=False):
        with tempfile.TemporaryDirectory() as folder:
            bin_dir = Path(folder)
            aero = bin_dir / 'aerospace'
            aero.write_text('#!/bin/sh\nprintf "123|com.mitchellh.ghostty|456\\n"\n')
            agent = bin_dir / 'fake-agent'
            agent.write_text('#!/usr/bin/env python3\nimport os,json\nprint(json.dumps({k:os.environ.get(k) for k in ["AGENT_ORIGIN_WINDOW_ID","AGENT_ORIGIN_APP_PID","PATH"]}))\n')
            for path in [aero, agent]:
                path.chmod(0o755)
            env = dict(os.environ)
            for key in ['TMUX', 'SSH_CONNECTION', 'AGENT_ORIGIN_WINDOW_ID', 'AGENT_ORIGIN_APP_PID', 'AGENT_REAL_CODE']:
                env.pop(key, None)
            env.update(TERM_PROGRAM=term, TMUX=tmux, PATH=f'{bin_dir}:{env["PATH"]}')
            if nested:
                env.update(AGENT_ORIGIN_WINDOW_ID='789', AGENT_ORIGIN_APP_PID='987')
            master, slave = os.openpty()
            try:
                source = Path(__file__).resolve().parent.parent / 'zsh/functions/agent-workspace.zsh'
                result = subprocess.run(['zsh', '-fc', 'source "$1"; _agent_workspace_launch fake-agent', 'test', str(source)],
                                        env=env, stdin=slave, capture_output=True, text=True, check=True)
                return json.loads(result.stdout)
            finally:
                os.close(master)
                os.close(slave)

    def test_direct_ghostty_records_origin_and_scopes_path(self):
        result = self.capture()
        self.assertEqual(result['AGENT_ORIGIN_WINDOW_ID'], '123')
        self.assertEqual(result['AGENT_ORIGIN_APP_PID'], '456')
        self.assertTrue(result['PATH'].startswith(str(Path.home() / '.dotfiles/scripts/agent-bin')))

    def test_tmux_is_not_registered(self):
        self.assertIsNone(self.capture(tmux='/tmp/tmux/default,1,0')['AGENT_ORIGIN_WINDOW_ID'])

    def test_other_terminals_are_not_registered(self):
        self.assertIsNone(self.capture(term='Apple_Terminal')['AGENT_ORIGIN_WINDOW_ID'])

    def test_nested_agent_keeps_original_identity(self):
        self.assertEqual(self.capture(nested=True)['AGENT_ORIGIN_WINDOW_ID'], '789')


if __name__ == '__main__':
    unittest.main()
