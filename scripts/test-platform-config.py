#!/usr/bin/env python3
"""Platform selection and real config linking without touching the active HOME."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class PlatformTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles platform ')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        (self.home / '.dotfiles').symlink_to(ROOT)
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / 'xdg'))

    def shell(self, code, platform='ubuntu', success=True):
        lib = ROOT / 'platforms/common/lib.sh'
        self.assertTrue(lib.is_file(), 'shared platform library must exist')
        prefix = 'DOTFILES_ROOT="$1"; source "$1/platforms/common/lib.sh"; '
        result = subprocess.run(['bash', '-eu', '-c', prefix + code,
                                 'bash', str(ROOT), platform], env=self.env,
                                capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_platform_detection_and_unsupported_os(self):
        release = self.home / 'os-release'
        for distro in ('ubuntu', 'debian'):
            release.write_text(f'ID={distro}\n')
            result = self.shell('uname() { echo Linux; }; detect_platform "$HOME/os-release"')
            self.assertEqual(result.stdout.strip(), 'ubuntu')
        self.assertEqual(self.shell('uname() { echo Darwin; }; detect_platform').stdout.strip(), 'macos')
        release.write_text('ID=fedora\n')
        self.shell('uname() { echo Linux; }; detect_platform "$HOME/os-release"', success=False)
        self.shell('uname() { echo FreeBSD; }; detect_platform', success=False)

    def test_profiles_link_and_merge_repeatably(self):
        for platform in ('macos', 'ubuntu'):
            with self.subTest(platform=platform):
                self.home = Path(self.temp.name) / platform
                self.home.mkdir()
                (self.home / '.dotfiles').symlink_to(ROOT)
                self.env.update(HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / 'xdg'))
                target = (self.home / 'Library/Application Support/Code/User'
                          if platform == 'macos' else self.home / 'xdg/Code/User')
                target.mkdir(parents=True)
                original = target / 'settings.json'
                original.write_text('{"private-setting": true}\n')
                self.shell('DOTFILES_PLATFORM="$2"; '
                           'source "$1/platforms/common/setup.sh"; '
                           'source "$1/platforms/$2/setup.sh"; '
                           'code() { :; }; link_ghostty; link_vscode; '
                           'link_ghostty; link_vscode', platform)
                self.assertTrue(original.is_symlink())
                backups = list(target.glob('settings.json.bak-*'))
                self.assertEqual(len(backups), 1)
                self.assertEqual(json.loads(backups[0].read_text()), {'private-setting': True})
                data = json.loads(original.read_text())
                self.assertFalse(data['vim.handleKeys']['<C-h>'])
                self.assertEqual('terminal.integrated.defaultProfile.linux' in data,
                                 platform == 'ubuntu')
                ghostty = self.home / 'xdg/ghostty/config'
                self.assertEqual(ghostty.resolve(), ROOT / ('ghostty/config' if platform == 'macos' else 'ghostty/config-linux'))
                self.assertTrue((self.home / 'xdg/ghostty/shaders').is_dir())
                self.assertFalse(list((self.home / 'xdg/ghostty').glob('*.bak-*')))

    def test_install_backends_load_without_installing(self):
        for platform in ('macos', 'ubuntu'):
            self.shell('source "$1/platforms/common/install.sh"; '
                       'source "$1/platforms/$2/install.sh"; '
                       'declare -F check_package_manager pkg_install install_platform_tools '
                       'install_uv install_browser_runtime >/dev/null', platform)

    def test_common_setup_repeatedly_keeps_links_and_zshrc(self):
        (self.home / '.tmux/plugins/tpm').mkdir(parents=True)
        script = ('DOTFILES_PLATFORM=ubuntu; '
                  'source "$1/platforms/common/setup.sh"; '
                  'source "$1/platforms/ubuntu/setup.sh"; '
                  'code() { :; }; '
                  'install_neovim_plugins() { :; }; setup_common')
        self.shell(script)
        before = sorted(str(p) for p in self.home.rglob('*.bak-*'))
        zshrc = (self.home / '.zshrc').read_text()
        self.shell(script)
        self.assertEqual(sorted(str(p) for p in self.home.rglob('*.bak-*')), before)
        self.assertEqual((self.home / '.zshrc').read_text(), zshrc)
        self.assertEqual((self.home / '.tmux.conf').resolve(), ROOT / 'tmux/tmux.conf')
        self.assertEqual((self.home / '.config/nvim/lua').resolve(), ROOT / 'nvim/lua')

    def test_legacy_vscode_symlink_migrates_without_editing_shared_settings(self):
        target = self.home / 'xdg/Code/User'
        target.mkdir(parents=True)
        shared = ROOT / 'vscode/settings.json'
        before = shared.read_bytes()
        (target / 'settings.json').symlink_to(shared)
        self.shell('DOTFILES_PLATFORM=ubuntu; '
                   'source "$1/platforms/common/setup.sh"; '
                   'source "$1/platforms/ubuntu/setup.sh"; '
                   'code() { :; }; link_vscode')
        self.assertEqual(shared.read_bytes(), before)
        backups = list(target.glob('settings.json.bak-*'))
        self.assertEqual(len(backups), 1)
        self.assertTrue(backups[0].is_symlink())
        self.assertNotEqual((target / 'settings.json').resolve(), shared)

    def test_unsupported_entrypoints_stop_before_mutations(self):
        bin_dir = self.home / 'bin'
        bin_dir.mkdir()
        uname = bin_dir / 'uname'
        uname.write_text('#!/bin/sh\necho FreeBSD\n')
        uname.chmod(0o755)
        env = dict(self.env, PATH=str(bin_dir) + ':' + self.env['PATH'])
        for entry in ('install.sh', 'setup.sh'):
            result = subprocess.run(['bash', str(ROOT / entry)], env=env,
                                    text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Unsupported OS', result.stderr)
        self.assertEqual(sorted(p.name for p in self.home.iterdir()), ['.dotfiles', 'bin'])

    def test_entrypoints_can_be_sourced_without_side_effects(self):
        self.shell('source "$1/install.sh"; source "$1/setup.sh"')
        self.assertEqual(sorted(p.name for p in self.home.iterdir()), ['.dotfiles'])

    def test_zsh_loads_only_selected_os_aliases(self):
        for platform in ('macos', 'ubuntu'):
            code = ('source "$1/platforms/common/zsh.zsh"; '
                    'source "$1/platforms/$2/zsh.zsh"; '
                    'if [[ "$2" == macos ]]; then '
                    '(( $+aliases[sim] && $+functions[desktop-theme] )); '
                    'else (( ! $+aliases[sim] && ! $+functions[desktop-theme] )); '
                    '(( $+aliases[pbcopy] && $+aliases[pbpaste] )); fi')
            result = subprocess.run(['zsh', '-f', '-c', code, 'zsh', str(ROOT), platform],
                                    env=dict(self.env, TERM_PROGRAM=''),
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_tmux_profiles_load_with_copy_bindings(self):
        # Stub only external hooks; tmux itself parses and runs the real config.
        (self.home / '.dotfiles').unlink()
        dotfiles = self.home / '.dotfiles'
        (dotfiles / 'scripts').mkdir(parents=True)
        (dotfiles / 'platforms').symlink_to(ROOT / 'platforms')
        for name in ('tmux-autosave.sh', 'tmux-config-watch.sh'):
            stub = dotfiles / 'scripts' / name
            stub.write_text('#!/bin/sh\nexit 0\n')
            stub.chmod(0o755)
        tpm = self.home / '.tmux/plugins/tpm/tpm'
        tpm.parent.mkdir(parents=True)
        tpm.write_text('#!/bin/sh\nexit 0\n')
        tpm.chmod(0o755)
        for platform in ('macos', 'ubuntu'):
            with self.subTest(platform=platform):
                if platform == 'ubuntu' and not os.access('/usr/bin/zsh', os.X_OK):
                    self.skipTest('Ubuntu tmux profile requires the Linux /usr/bin/zsh path')
                socket = str(self.home / (platform + '.sock'))
                command = ['tmux', '-S', socket]
                def tmux(*args):
                    result = subprocess.run(command + list(args), env=self.env,
                                            text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    return result.stdout
                try:
                    tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'test', 'sleep 30')
                    tmux('source-file', str(ROOT / 'tmux/tmux.conf'))
                    tmux('source-file', str(ROOT / f'platforms/{platform}/tmux.conf'))
                    keys = tmux('list-keys', '-T', 'copy-mode-vi')
                    for key in ('DoubleClick1Pane', 'TripleClick1Pane'):
                        binding = next(line for line in keys.splitlines() if key in line)
                        self.assertIn('copy-pipe-and-cancel', binding)
                    self.assertEqual(tmux('show-option', '-gv', 'status').strip(), 'off')
                    if platform == 'ubuntu':
                        self.assertEqual(tmux('show-option', '-gv', 'default-shell').strip(), '/usr/bin/zsh')
                finally:
                    subprocess.run(command + ['kill-server'], env=self.env, capture_output=True)


if __name__ == '__main__':
    unittest.main()
