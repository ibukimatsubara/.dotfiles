#!/usr/bin/env python3
"""Verify music setup in isolated homes without changing desktop services."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class MusicSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles music ")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / "custom config"))

    def setup_music(self, platform):
        return subprocess.run([
            "/bin/bash", "-eu", "-c",
            'DOTFILES_ROOT="$1"; DOTFILES_PLATFORM="$2"; '
            'source "$1/platforms/common/lib.sh"; '
            'source "$1/platforms/common/setup.sh"; link_music_configs',
            "bash", str(ROOT), platform,
        ], env=self.env, text=True, capture_output=True)

    def test_each_platform_gets_shared_library_and_its_audio_output(self):
        for platform, backend in [("macos", "osx"), ("ubuntu", "pulse")]:
            with self.subTest(platform=platform):
                result = self.setup_music(platform)
                self.assertEqual(result.returncode, 0, result.stderr)
                config_home = Path(self.env["XDG_CONFIG_HOME"])
                conf = config_home / "mpd/mpd.conf"
                text = conf.read_text()
                self.assertIn('music_directory "~/Music"', text)
                self.assertIn('bind_to_address "~/.local/state/mpd/socket"', text)
                self.assertNotIn('127.0.0.1', text)
                self.assertIn(f'type "{backend}"', text)
                self.assertEqual((self.home / ".mpdconf").resolve(), conf.resolve())
                self.assertEqual((config_home / "rmpc/config.ron").resolve(),
                                 ROOT / "rmpc/config.ron")
                self.assertTrue((self.home / "Music").is_dir())
                self.assertTrue((self.home / ".local/share/mpd/playlists").is_dir())
                self.assertEqual((self.home / '.local/bin/music').resolve(), ROOT / 'scripts/music-player.sh')
                self.assertEqual((self.home / '.local/bin/music-sync').resolve(), ROOT / 'scripts/music-sync.sh')
                if platform == "ubuntu":
                    unit = config_home / "systemd/user/dotfiles-mpd.service"
                    self.assertIn('"%h/.mpdconf"', unit.read_text())

    def test_existing_config_is_backed_up_once_and_repeat_is_idempotent(self):
        target = Path(self.env["XDG_CONFIG_HOME"]) / "mpd/mpd.conf"
        target.parent.mkdir(parents=True)
        target.write_text("private local config\n")
        first = self.setup_music("ubuntu")
        self.assertEqual(first.returncode, 0, first.stderr)
        before = target.resolve().stat().st_mtime_ns
        backups = list(target.parent.glob("mpd.conf.bak-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "private local config\n")
        second = self.setup_music("ubuntu")
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(target.resolve().stat().st_mtime_ns, before)
        self.assertEqual(list(target.parent.glob("mpd.conf.bak-*")), backups)

    def test_cliamp_initial_library_is_created_without_overwriting_user_lists(self):
        first = self.setup_music('ubuntu')
        self.assertEqual(first.returncode, 0, first.stderr)
        target = Path(self.env['XDG_CONFIG_HOME']) / 'cliamp/playlists/Music.toml'
        self.assertTrue(target.is_file())
        self.assertIn('path = "~/Music"', target.read_text())
        target.write_text('[[dir]]\npath = "~/Music/My library"\n')
        second = self.setup_music('ubuntu')
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(target.read_text(), '[[dir]]\npath = "~/Music/My library"\n')

    def test_linux_download_failure_leaves_no_installed_binary(self):
        installer = ROOT / "scripts/install-rmpc.sh"
        self.assertTrue(installer.is_file())
        bin_dir = self.home / "test-bin"
        bin_dir.mkdir()
        for name, body in {
            "uname": 'echo "${TEST_ARCH:-x86_64}"',
            "curl": 'exit 22',
        }.items():
            path = bin_dir / name
            path.write_text("#!/bin/sh\n" + body + "\n")
            path.chmod(0o755)
        result = subprocess.run(["/bin/bash", str(installer)],
                                env=dict(self.env, PATH=f"{bin_dir}:/usr/bin:/bin"),
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / ".local/bin/rmpc").exists())

    def test_linux_installer_rejects_unsupported_architecture(self):
        installer = ROOT / "scripts/install-rmpc.sh"
        self.assertTrue(installer.is_file())
        bin_dir = self.home / "test-bin"
        bin_dir.mkdir()
        uname = bin_dir / "uname"
        uname.write_text("#!/bin/sh\necho riscv64\n")
        uname.chmod(0o755)
        result = subprocess.run(["/bin/bash", str(installer)],
                                env=dict(self.env, PATH=f"{bin_dir}:/usr/bin:/bin"),
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unsupported architecture", result.stderr)
        self.assertFalse((self.home / ".local/bin").exists())

    def test_linux_installer_rejects_corrupt_download_before_install(self):
        bin_dir = self.home / "test-bin"
        bin_dir.mkdir()
        scripts = {
            "uname": 'echo x86_64',
            "curl": '''while [ "$#" -gt 0 ]; do
if [ "$1" = --output ]; then printf corrupt > "$2"; exit 0; fi
shift
done
exit 1''',
        }
        # Use the real SHA-256 implementation on either host platform.
        if not Path('/usr/bin/sha256sum').exists():
            scripts['sha256sum'] = 'exec /usr/bin/shasum -a 256 "$@"'
        for name, body in scripts.items():
            path = bin_dir / name
            path.write_text("#!/bin/sh\n" + body + "\n")
            path.chmod(0o755)
        result = subprocess.run(["/bin/bash", str(ROOT / "scripts/install-rmpc.sh")],
                                env=dict(self.env, PATH=f"{bin_dir}:/usr/bin:/bin"),
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('not found', result.stderr)
        self.assertFalse((self.home / ".local/bin/rmpc").exists())


    def test_cliamp_corrupt_download_is_rejected_before_install(self):
        installer = ROOT / 'scripts/install-cliamp.sh'
        self.assertTrue(installer.is_file())
        bin_dir = self.home / 'bin'
        bin_dir.mkdir()
        scripts = {
            'uname': 'if [ "$1" = -s ]; then echo Linux; else echo x86_64; fi',
            'curl': '''while [ "$#" -gt 0 ]; do
if [ "$1" = --output ]; then printf corrupt > "$2"; exit 0; fi
shift
done
exit 1''',
        }
        if not Path('/usr/bin/sha256sum').exists():
            scripts['sha256sum'] = 'exec /usr/bin/shasum -a 256 "$@"'
        for name, body in scripts.items():
            path = bin_dir / name
            path.write_text('#!/bin/sh\n' + body + '\n')
            path.chmod(0o755)
        result = subprocess.run(['/bin/bash', str(installer)],
                                env=dict(self.env, PATH=f'{bin_dir}:/usr/bin:/bin'),
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('checksum', result.stderr.lower())
        self.assertFalse((self.home / '.local/bin/cliamp').exists())


if __name__ == "__main__":
    unittest.main()
