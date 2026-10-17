#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('ubuntu_theme', Path(__file__).with_name('ubuntu-theme.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class UbuntuThemeTests(unittest.TestCase):
    def test_offline_apply_preserves_settings_without_ipc(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            current = config / 'desktop-theme/current'
            current.mkdir(parents=True)
            (current / 'dms-theme.json').write_text('{}')
            (current / 'hyprland.conf').write_text('general:col.active_border = rgb(abcdef)\n')
            (current / 'vicinae-theme.toml').write_text('[meta]\nversion = 1\n')
            (current / 'theme.json').write_text(json.dumps({'wallpapers': [{'path': '/test.png'}]}))
            settings = config / 'DankMaterialShell/settings.json'
            settings.parent.mkdir()
            settings.write_text('{"keep": 42}')
            with patch.object(m, 'CONFIG', config), patch.object(m, 'DATA', config / 'data'), patch.object(m, 'CURRENT', current), patch.dict(m.os.environ, {}, clear=True), patch.object(m.subprocess, 'run') as run:
                m.apply()
                run.assert_not_called()
            self.assertEqual(json.loads(settings.read_text())['keep'], 42)
            self.assertEqual(json.loads(settings.read_text())['currentThemeName'], 'custom')
            self.assertFalse((config / 'vicinae/vicinae.json').is_symlink())
            self.assertTrue((config / 'data/vicinae/themes/dotfiles-desktop.toml').is_file())
            self.assertIn('abcdef', (config / 'dotfiles/hypr/theme.conf').read_text())

    def test_wallpaper_requires_session(self):
        with patch.dict(m.os.environ, {}, clear=True), patch.object(m.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'Hyprland'):
                m.wallpaper()
            run.assert_not_called()

    def test_wallpaper_uses_installed_dms_ipc(self):
        with patch.dict(m.os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': 'fixture'}), patch.object(m, 'ipc') as ipc:
            m.wallpaper()
            ipc.assert_called_once_with('wallpaper', 'next')

    def test_mutable_settings_symlinks_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            original = Path(tmp) / 'managed.json'
            original.write_text('{"keep": true}')
            settings = Path(tmp) / 'settings.json'
            settings.symlink_to(original)
            with self.assertRaisesRegex(ValueError, 'symlinked'):
                m.atomic_write(settings, '{}')
            self.assertEqual(original.read_text(), '{"keep": true}')

if __name__ == '__main__':
    unittest.main()
