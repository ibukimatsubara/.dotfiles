#!/usr/bin/env python3
"""Test desktop configuration in a temporary home and route apps with fake IPC."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent

class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ubuntu-desktop-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        (self.home / '.dotfiles').symlink_to(ROOT)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / '.config'),
                        XDG_DATA_HOME=str(self.home / '.local/share'),
                        XDG_STATE_HOME=str(self.home / '.local/state'),
                        PATH=str(self.bin) + ':' + os.environ['PATH'],
                        DESKTOP_TEST_LOG=str(self.home / 'calls'),
                        DESKTOP_TEST_WINDOWS='[]')
        self.stub('hyprctl', '''#!/usr/bin/env python3
import json,os,sys
args=sys.argv[1:]
if args == ['-j','activeworkspace']: print('{"id":2}')
elif args == ['-j','clients']: print(os.environ['DESKTOP_TEST_WINDOWS'])
else:
 with open(os.environ['DESKTOP_TEST_LOG'],'a') as f: f.write(json.dumps(args)+'\\n')
''')
        for name in ('ghostty','google-chrome','code','vicinae','dms'):
            self.stub(name, '#!/bin/sh\nexit 0\n')
        self.stub('Hyprland', '#!/bin/sh\necho "Hyprland 0.53.3"\n')

    def stub(self, name, source):
        p=self.bin/name
        p.write_text(source)
        p.chmod(0o755)

    def run_script(self, path, *args, success=True):
        script=ROOT/path
        self.assertTrue(script.is_file(), f'missing script {path}')
        result=subprocess.run(['bash',str(script),*args], env=self.env,
                              capture_output=True,text=True,timeout=20)
        if success: self.assertEqual(result.returncode,0,result.stderr+result.stdout)
        else: self.assertNotEqual(result.returncode,0)
        return result

    def calls(self):
        p=self.home/'calls'
        return [json.loads(line) for line in p.read_text().splitlines()] if p.exists() else []

    def test_desktop_override_does_not_write_through_symlink(self):
        apps=Path(self.env['XDG_DATA_HOME'])/'applications'
        apps.mkdir(parents=True)
        original=self.home/'original.desktop'
        content='[Desktop Entry]\nName=Terminal\nExec=ghostty %U\n'
        original.write_text(content)
        entry=apps/'com.mitchellh.ghostty.desktop';entry.symlink_to(original)
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        self.assertEqual(original.read_text(),content)
        self.assertFalse(entry.is_symlink())

    def test_custom_desktop_env_command_is_preserved(self):
        apps=Path(self.env['XDG_DATA_HOME'])/'applications'
        apps.mkdir(parents=True)
        entry=apps/'com.mitchellh.ghostty.desktop'
        content='[Desktop Entry]\nName=Terminal\nExec=env CUSTOM_FLAG=1 ghostty %U\n'
        entry.write_text(content)
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        self.assertEqual(entry.read_text(),content)

    def test_app_launcher_leaves_gnome_backend_alone_with_stale_signature(self):
        self.stub('google-chrome', '#!/usr/bin/env python3\nimport os,json,sys\nprint(json.dumps({"args":sys.argv[1:],"display":os.environ.get("DISPLAY")}))\n')
        self.env.update(HYPRLAND_INSTANCE_SIGNATURE='stale',XDG_CURRENT_DESKTOP='ubuntu:GNOME',DISPLAY=':42')
        result=self.run_script('scripts/ubuntu-app-launch.sh','chrome','--new-window')
        self.assertEqual(json.loads(result.stdout),{'args':['--new-window'],'display':':42'})

    def test_desktop_entry_shares_launcher_and_preserves_arguments(self):
        apps=Path(self.env['XDG_DATA_HOME'])/'applications'
        apps.mkdir(parents=True)
        entry=apps/'com.mitchellh.ghostty.desktop'
        original='[Desktop Entry]\nName=My terminal\nExec=/old/ghostty --gtk-single-instance=true %U\nDBusActivatable=true\n'
        entry.write_text(original)
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        first=entry.read_text()
        self.assertIn('ubuntu-app-launch.sh" ghostty --gtk-single-instance=true %U',first)
        self.assertIn('Name=My terminal',first)
        self.assertIn('DBusActivatable=false',first)
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        self.assertEqual(entry.read_text(),first)
        self.assertEqual(entry.with_suffix('.desktop.before-dotfiles-wayland').read_text(),original)

    def test_app_launcher_uses_native_backends_in_hyprland(self):
        for binary in ('ghostty','google-chrome','code'):
            self.stub(binary, '#!/usr/bin/env python3\nimport os,json,sys\nprint(json.dumps({"args":sys.argv[1:],"display":os.environ.get("DISPLAY")}))\n')
        self.env.update(HYPRLAND_INSTANCE_SIGNATURE='fixture',XDG_CURRENT_DESKTOP='Hyprland',DISPLAY=':42')
        for app,flag in [('ghostty','--gtk-single-instance=true'),('chrome','--ozone-platform=wayland'),('vscode','--ozone-platform=wayland')]:
            result=self.run_script('scripts/ubuntu-app-launch.sh',app,'--new-window')
            data=json.loads(result.stdout)
            self.assertIn(flag,data['args'])
            self.assertIsNone(data['display'])

    def test_native_shell_clients_do_not_probe_x11(self):
        self.stub('probe-native', '#!/usr/bin/env python3\nimport os,json\nprint(json.dumps({k:os.environ.get(k) for k in ["DISPLAY","XAUTHORITY","WAYLAND_DISPLAY"]}))\n')
        self.env.update(DISPLAY=':42',XAUTHORITY='/test/xauth',WAYLAND_DISPLAY='wayland-test')
        result=self.run_script('scripts/hyprland-native.sh','probe-native')
        self.assertEqual(json.loads(result.stdout),{'DISPLAY':None,'XAUTHORITY':None,'WAYLAND_DISPLAY':'wayland-test'})

    def test_existing_object_widget_is_not_duplicated(self):
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        config=Path(self.env['XDG_CONFIG_HOME'])/'DankMaterialShell'
        (config/'plugin_settings.json').write_text('{}')
        settings=config/'settings.json'
        data=json.loads(settings.read_text())
        data['barConfigs'][0]['rightWidgets']=[{'id':'dotfilesBreakTimer','enabled':False},{'id':'clock'}]
        settings.write_text(json.dumps(data))
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        widgets=json.loads(settings.read_text())['barConfigs'][0]['rightWidgets']
        self.assertEqual(sum((w.get('id') if isinstance(w,dict) else w)=='dotfilesBreakTimer' for w in widgets),1)
        self.assertFalse(widgets[0]['enabled'])

    def test_additions_installed_once_and_preferences_preserved(self):
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        config=Path(self.env['XDG_CONFIG_HOME'])
        settings=config/'DankMaterialShell/settings.json'
        data=json.loads(settings.read_text())
        self.assertIn('dotfilesBreakTimer',data['barConfigs'][0]['leftWidgets'])
        self.assertIn('dotfilesCodexUsage',data['barConfigs'][0]['rightWidgets'])
        plugins=config/'DankMaterialShell/plugin_settings.json'
        data=json.loads(plugins.read_text())
        self.assertTrue(data['dotfilesBreakTimer']['enabled'])
        data['dotfilesBreakTimer']['enabled']=False
        plugins.write_text(json.dumps(data))
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        self.assertFalse(json.loads(plugins.read_text())['dotfilesBreakTimer']['enabled'])
        self.assertTrue((config/'DankMaterialShell/plugins/dotfilesBreakTimer/Widget.qml').is_file())
        self.assertTrue((config/'dotfiles/mic-priority.json').is_file())
        self.assertTrue((config/'dotfiles/hypr/theme.conf').is_file())

    def test_custom_config_home_uses_its_own_local_overrides(self):
        self.env['XDG_CONFIG_HOME']=str(self.home/'custom-config')
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        config=Path(self.env['XDG_CONFIG_HOME'])
        self.assertIn('source = '+str(config/'hypr/local.conf'),
                      (config/'hypr/hyprland.conf').read_text())

    def test_session_replaces_gnome_input_environment(self):
        self.stub('hyprctl', '#!/bin/sh\nexit 1\n')
        self.stub('fcitx5', '#!/bin/sh\nexit 0\n')
        self.stub('hypridle', '#!/bin/sh\nexit 0\n')
        self.stub('dbus-update-activation-environment', """#!/usr/bin/env python3
import os,json,sys
with open(os.environ['DESKTOP_TEST_LOG'],'w') as f:
 json.dump({'args':sys.argv[1:],'gtk':os.environ.get('GTK_IM_MODULE'),
            'qt':os.environ.get('QT_IM_MODULE'),'qt_modules':os.environ.get('QT_IM_MODULES')},f)
""")
        self.env.update(HYPRLAND_INSTANCE_SIGNATURE='test-only',XDG_RUNTIME_DIR=str(self.home),
                        GTK_IM_MODULE='ibus',QT_IM_MODULE='ibus',QT_IM_MODULES='wayland;ibus',
                        DISPLAY=':42',XAUTHORITY='/test/xauth')
        self.run_script('scripts/hyprland-session.sh')
        data=json.loads((self.home/'calls').read_text())
        self.assertEqual(data['gtk'],'')
        self.assertEqual(data['qt'],'fcitx')
        self.assertEqual(data['qt_modules'],'wayland;fcitx;ibus')
        for key in ('DISPLAY','XAUTHORITY','XMODIFIERS','GTK_IM_MODULE'):
            self.assertIn(key,data['args'])

    def test_focus_official_vscode_class_on_current_workspace(self):
        self.env['DESKTOP_TEST_WINDOWS']=json.dumps([{'class':'com.microsoft.VSCode','workspace':{'id':2},'address':'0x456'}])
        self.run_script('scripts/hyprland-focus-or-open.sh','vscode')
        self.assertEqual(self.calls(),[['dispatch','focuswindow','address:0x456']])

    def test_focus_existing_browser_only_on_current_workspace(self):
        self.env['DESKTOP_TEST_WINDOWS']=json.dumps([
            {'class':'google-chrome','workspace':{'id':1},'address':'0x111'},
            {'class':'google-chrome','workspace':{'id':2},'address':'0x222'}])
        self.run_script('scripts/hyprland-focus-or-open.sh','chrome')
        self.assertEqual(self.calls(),[['dispatch','focuswindow','address:0x222']])

    def test_other_workspace_browser_creates_new_window(self):
        self.env['DESKTOP_TEST_WINDOWS']=json.dumps([
            {'class':'google-chrome','workspace':{'id':1},'address':'0x111'}])
        self.run_script('scripts/hyprland-focus-or-open.sh','chrome')
        self.assertEqual(self.calls(),[['dispatch','exec','[workspace 2] ~/.dotfiles/scripts/ubuntu-app-launch.sh chrome --new-window']])

    def test_terminal_always_new_and_unknown_app_rejected(self):
        self.env['DESKTOP_TEST_WINDOWS']=json.dumps([
            {'class':'com.mitchellh.ghostty','workspace':{'id':2},'address':'0x333'}])
        self.run_script('scripts/hyprland-focus-or-open.sh','ghostty')
        self.assertEqual(self.calls(),[['dispatch','exec','[workspace 2] ~/.dotfiles/scripts/ubuntu-app-launch.sh ghostty']])
        self.run_script('scripts/hyprland-focus-or-open.sh','unknown',success=False)
        self.assertEqual(len(self.calls()),1)

    def test_desktop_setup_preserves_mutable_settings_and_local_config(self):
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        config=self.home/'.config'
        self.assertIn('source = '+str(config/'hypr/local.conf'),(config/'hypr/hyprland.conf').read_text())
        settings=config/'DankMaterialShell/settings.json'
        self.assertFalse(settings.is_symlink())
        data=json.loads(settings.read_text()); data['customUserValue']=True
        settings.write_text(json.dumps(data))
        local=config/'hypr/local.conf'; local.write_text('# user monitor overrides\n')
        self.run_script('platforms/ubuntu/setup-desktop.sh')
        self.assertTrue(json.loads(settings.read_text())['customUserValue'])
        self.assertEqual(local.read_text(),'# user monitor overrides\n')
        self.assertFalse(list(config.rglob('*.bak-*')))

if __name__=='__main__': unittest.main()
