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
        with tempfile.TemporaryDirectory() as tmp, patch.object(m, 'CONFIG', Path(tmp)), patch.dict(m.os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': 'fixture'}), patch.object(m, 'ipc') as ipc:
            m.wallpaper()
            ipc.assert_called_once_with('wallpaper', 'next')

    def test_caelestia_wallpaper_does_not_call_dms(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            (config / 'dotfiles').mkdir()
            (config / 'dotfiles/desktop-shell').write_text('caelestia\n')
            with patch.object(m, 'CONFIG', config), patch.object(m, 'ROTATION', config / 'missing.json'), patch.dict(m.os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': 'fixture'}), patch.object(m, 'ipc') as ipc, patch.object(m, 'command') as command:
                m.wallpaper()
                ipc.assert_not_called()
                command.assert_called_once_with('caelestia', 'wallpaper', '-r')

    def test_caelestia_wallpaper_cycles_listed_images(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / '.config/dotfiles').mkdir(parents=True)
            (home / '.config/dotfiles/desktop-shell').write_text('caelestia\n')
            for name in ('a.png', 'c.png'):
                (home / name).write_bytes(b'')
            rotation = home / 'wallpapers.json'
            rotation.write_text(json.dumps({'rotation_seconds': 60, 'wallpapers': ['a.png', 'missing.png', 'c.png']}))
            current = home / 'state/caelestia/wallpaper/path.txt'
            current.parent.mkdir(parents=True)
            with patch.object(m, 'CONFIG', home / '.config'), patch.object(m, 'STATE', home / 'state'), patch.object(m, 'ROTATION', rotation), patch.object(m.Path, 'home', return_value=home), patch.dict(m.os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': 'fixture'}), patch.object(m, 'command') as command:
                for selected, expected in [('/elsewhere.png', 'a.png'), (str(home / 'a.png'), 'c.png'), (str(home / 'c.png'), 'a.png')]:
                    current.write_text(selected + '\n')
                    m.wallpaper()
                    command.assert_called_with('caelestia', 'wallpaper', '-f', str((home / expected).resolve()))

    def test_caelestia_wallpaper_matches_resolved_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / 'home'
            pictures = Path(tmp) / 'pictures'
            pictures.mkdir()
            home.mkdir()
            (home / 'Pictures').symlink_to(pictures)
            (home / '.config/dotfiles').mkdir(parents=True)
            (home / '.config/dotfiles/desktop-shell').write_text('caelestia\n')
            for name in ('a.png', 'b.png'):
                (pictures / name).write_bytes(b'')
            rotation = home / 'wallpapers.json'
            rotation.write_text(json.dumps({'rotation_seconds': 60, 'wallpapers': ['Pictures/a.png', 'Pictures/b.png']}))
            current = home / 'state/caelestia/wallpaper/path.txt'
            current.parent.mkdir(parents=True)
            current.write_text(str((pictures / 'a.png').resolve()))
            with patch.object(m, 'CONFIG', home / '.config'), patch.object(m, 'STATE', home / 'state'), patch.object(m, 'ROTATION', rotation), patch.object(m.Path, 'home', return_value=home), patch.dict(m.os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': 'fixture'}), patch.object(m, 'command') as command:
                m.wallpaper()
                command.assert_called_once_with('caelestia', 'wallpaper', '-f', str((pictures / 'b.png').resolve()))

    def test_rotation_rejects_short_interval(self):
        with tempfile.TemporaryDirectory() as tmp:
            rotation = Path(tmp) / 'wallpapers.json'
            rotation.write_text('{"rotation_seconds": 5, "wallpapers": []}')
            with patch.object(m, 'ROTATION', rotation), self.assertRaisesRegex(ValueError, '60 seconds'):
                m.rotation()

    def test_repository_rotation_list_is_valid(self):
        seconds, _ = m.rotation()
        self.assertGreaterEqual(seconds, 60)

    def test_live_caelestia_theme_apply_uses_its_wallpaper_backend(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            current = config / 'desktop-theme/current'
            current.mkdir(parents=True)
            for name, content in [('dms-theme.json', '{}'), ('hyprland.conf', '# colors\n'),
                                  ('vicinae-theme.toml', '[meta]\nversion = 1\n'),
                                  ('theme.json', '{"wallpapers":[{"path":"/test.png"}]}')]:
                (current / name).write_text(content)
            (config / 'dotfiles').mkdir()
            (config / 'dotfiles/desktop-shell').write_text('caelestia\n')
            with patch.object(m, 'CONFIG', config), patch.object(m, 'DATA', config / 'data'), patch.object(m, 'CURRENT', current), patch.object(m, 'ROTATION', config / 'missing.json'), patch.dict(m.os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': 'fixture'}), patch.object(m, 'ipc') as ipc, patch.object(m, 'command') as command:
                m.apply()
                ipc.assert_not_called()
                self.assertIn(unittest.mock.call('caelestia', 'wallpaper', '-f', '/test.png'), command.call_args_list)

    def test_live_caelestia_theme_apply_keeps_rotation_wallpaper(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            current = config / 'desktop-theme/current'
            current.mkdir(parents=True)
            for name, content in [('dms-theme.json', '{}'), ('hyprland.conf', '# colors\n'),
                                  ('vicinae-theme.toml', '[meta]\nversion = 1\n'),
                                  ('theme.json', '{"wallpapers":[{"path":"/test.png"}]}')]:
                (current / name).write_text(content)
            (config / 'dotfiles').mkdir()
            (config / 'dotfiles/desktop-shell').write_text('caelestia\n')
            (config / 'a.png').write_bytes(b'')
            rotation = config / 'wallpapers.json'
            rotation.write_text(json.dumps({'rotation_seconds': 60, 'wallpapers': ['a.png']}))
            with patch.object(m, 'CONFIG', config), patch.object(m, 'DATA', config / 'data'), patch.object(m, 'CURRENT', current), patch.object(m, 'ROTATION', rotation), patch.object(m.Path, 'home', return_value=config), patch.dict(m.os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': 'fixture'}), patch.object(m, 'command') as command:
                m.apply()
                self.assertFalse([c for c in command.call_args_list if c.args[:2] == ('caelestia', 'wallpaper')])
                command.assert_called_with('hyprctl', 'reload')

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
