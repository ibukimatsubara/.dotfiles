#!/usr/bin/env python3
"""Route the macOS navigation keys using fake compositor IPC."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
class NavigationTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.base=Path(self.temp.name);(self.base/'hyprctl').write_text('''#!/usr/bin/env python3
import json,os,sys
args=sys.argv[1:]
if args==['-j','activewindow']:print(os.environ['NAV_WINDOW'])
elif args==['-j','clients']:print(os.environ['NAV_CLIENTS'])
else:
 with open(os.environ['NAV_LOG'],'a') as f:f.write(json.dumps(args)+'\\n')
''');(self.base/'hyprctl').chmod(0o755)
        (self.base/'vicinae').write_text('#!/bin/sh\nexit 1\n');(self.base/'vicinae').chmod(0o755)
        self.env=dict(os.environ,PATH=str(self.base)+':'+os.environ['PATH'],NAV_LOG=str(self.base/'log'),NAV_CLIENTS='[]')
        self.window={'class':'com.mitchellh.ghostty','title':'zsh','address':'0x1','workspace':{'id':1},'at':[0,0],'size':[100,100],'mapped':True,'floating':False}
    def run_key(self,key,window=None,clients=None):
        self.env['NAV_WINDOW']=json.dumps(self.window if window is None else window)
        self.env['NAV_CLIENTS']=json.dumps(clients or [])
        result=subprocess.run(['python3',str(ROOT/'scripts/hyprland-navigation.py'),key],env=self.env,text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stderr)
        return [json.loads(s) for s in (self.base/'log').read_text().splitlines()] if (self.base/'log').exists() else []
    def test_open_launcher_keeps_keys_despite_stale_ghostty_focus(self):
        (self.base/'vicinae').write_text('#!/bin/sh\nexit 0\n')
        self.assertEqual(self.run_key('u'),[['dispatch','sendshortcut','CTRL,U,']])

    def test_ghostty_outside_tmux_moves_workspace(self):
        self.assertEqual(self.run_key('u'),[['dispatch','workspace','e-1']])
    def test_ghostty_tmux_gets_original_session_key(self):
        self.window['title']='[tmux] main:1 shell'
        self.assertEqual(self.run_key('i'),[['dispatch','sendshortcut','CTRL,I,']])
    def test_editor_keeps_its_navigation(self):
        self.window['class']='com.microsoft.VSCode'
        self.assertEqual(self.run_key('h'),[['dispatch','sendshortcut','CTRL,H,']])
    def test_focus_wrap_ignores_floating_windows(self):
        left=dict(self.window,address='0x2',at=[-100,0])
        popup=dict(self.window,address='0x3',at=[100,0],floating=True)
        self.assertEqual(self.run_key('l',clients=[self.window,left,popup]),[['dispatch','focuswindow','address:0x2']])
    def test_no_window_passes_key_to_focused_layer(self):
        self.assertEqual(self.run_key('u',window={}),[['dispatch','sendshortcut','CTRL,U,']])
if __name__=='__main__':unittest.main()
