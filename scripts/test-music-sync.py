#!/usr/bin/env python3
"""Exercise daily music pulls with real rsync and an isolated SSH transport."""
import datetime
import fcntl
import json
import os
from pathlib import Path
import plistlib
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
RSYNC = next((str(p) for p in (Path('/opt/homebrew/bin/rsync'),
                              Path('/usr/local/bin/rsync')) if p.is_file()),
             shutil.which('rsync'))


class MusicSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles music sync ')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.source = self.home / "Ubuntu library 日本語's"
        self.source.mkdir()
        self.destination = self.home / 'Music/Shared'
        self.config_dir = self.home / 'custom config/music-sync'
        self.config_dir.mkdir(parents=True)
        self.state = self.home / 'custom state/music-sync'
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / 'custom config'),
                        XDG_STATE_HOME=str(self.home / 'custom state'),
                        PATH=f'{self.bin}:{os.environ.get("PATH", "")}:/opt/homebrew/bin:/usr/local/bin',
                        TEST_HOME=str(self.home), TEST_RSYNC=RSYNC or '')
        self.executable('uname', '#!/bin/sh\necho Darwin\n')
        self.executable('rmpc', '#!/bin/sh\nprintf "%s\\n" "$@" >> "$TEST_HOME/mpd-updates"\n')
        # SSH is the external boundary. The sender and receiver are both real
        # rsync processes; the transport never opens a network connection.
        self.executable('ssh', f'''#!{sys.executable}
import json, os, pathlib, subprocess, sys
args = sys.argv[1:]
with (pathlib.Path(os.environ['TEST_HOME']) / 'ssh-calls').open('a') as out:
    out.write(json.dumps(args) + '\\n')
if (pathlib.Path(os.environ['TEST_HOME']) / 'offline').exists():
    sys.exit(255)
remote = args[args.index('music-source') + 1:]
assert remote[0] == 'rsync', remote
if (pathlib.Path(os.environ['TEST_HOME']) / 'interrupt-transfer').exists():
    os.set_blocking(sys.stdout.fileno(), True)
    sender = subprocess.Popen([os.environ['TEST_RSYNC'], *remote[1:]], stdout=subprocess.PIPE)
    try:
        sent = 0
        while sent < 500000:
            chunk = sender.stdout.read1(min(8192, 500000 - sent))
            if not chunk:
                break
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()
            sent += len(chunk)
    finally:
        sender.kill()
        sender.wait()
    sys.exit(1)
os.execv(os.environ['TEST_RSYNC'], [os.environ['TEST_RSYNC'], *remote[1:]])
''')
        self.executable('launchctl', '''#!/bin/sh
printf '%s\n' "$*" >> "$TEST_HOME/launchctl-calls"
if [ "$1" = bootstrap ] && [ -f "$TEST_HOME/bootstrap-fails" ]; then exit 1; fi
''')
        self.write_config()

    def executable(self, name, content):
        target = self.bin / name
        target.write_text(content)
        target.chmod(0o755)

    def write_config(self, host='music-source', remote=None):
        (self.config_dir / 'config').write_text(
            f'MUSIC_SYNC_HOST={shlex.quote(host)}\n'
            f'MUSIC_SYNC_REMOTE_DIR={shlex.quote(str(self.source) if remote is None else remote)}\n'
            'MUSIC_SYNC_LOCAL_DIR="$HOME/Music/Shared"\n')

    def run_script(self, *args, setup=False):
        script = ROOT / 'scripts' / ('setup-music-sync.sh' if setup else 'music-sync.sh')
        self.assertTrue(script.is_file(), f'missing {script.name}')
        return subprocess.run(['/bin/bash', str(script), *args], env=self.env,
                              capture_output=True, text=True, timeout=20)

    def require_rsync(self):
        if not RSYNC:
            self.skipTest('rsync is required for transfer integration tests')
        result = subprocess.run([RSYNC, '-s', '--version'], capture_output=True)
        if result.returncode:
            self.skipTest('rsync 3 or later is required')

    def test_pull_updates_tracks_and_keeps_local_extras_and_source(self):
        self.require_rsync()
        album = self.source / 'Album one'
        album.mkdir()
        track = album / '曲 one.flac'
        track.write_bytes(b'original audio')
        self.destination.mkdir(parents=True)
        (self.destination / 'mac-only.mp3').write_bytes(b'keep this')
        first = self.run_script()
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        copied = self.destination / 'Album one/曲 one.flac'
        self.assertEqual(copied.read_bytes(), b'original audio')
        track.write_bytes(b'updated audio with new tags')
        second = self.run_script()
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertEqual(copied.read_bytes(), track.read_bytes())
        track.unlink()
        third = self.run_script()
        self.assertEqual(third.returncode, 0, third.stdout + third.stderr)
        self.assertTrue(copied.exists(), 'remote deletion must not delete local music')
        self.assertEqual((self.destination / 'mac-only.mp3').read_bytes(), b'keep this')
        updates = (self.home / 'mpd-updates').read_text().splitlines()
        self.assertIn('update', updates)
        calls = json.loads((self.home / 'ssh-calls').read_text().splitlines()[0])
        self.assertIn('BatchMode=yes', ' '.join(calls))
        self.assertIn('ConnectTimeout=10', ' '.join(calls))

    def test_scheduled_success_runs_once_per_day_but_manual_pull_still_works(self):
        self.require_rsync()
        (self.source / 'one.mp3').write_bytes(b'one')
        first = self.run_script('--scheduled')
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        (self.source / 'two.mp3').write_bytes(b'two')
        second = self.run_script('--scheduled')
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertFalse((self.destination / 'two.mp3').exists())
        self.assertEqual(len((self.home / 'ssh-calls').read_text().splitlines()), 1)
        manual = self.run_script()
        self.assertEqual(manual.returncode, 0, manual.stdout + manual.stderr)
        self.assertEqual((self.destination / 'two.mp3').read_bytes(), b'two')
        self.assertIn(datetime.date.today().isoformat(),
                      (self.state / 'last-success').read_text())

    def test_failed_pull_preserves_music_and_can_retry_the_same_day(self):
        self.require_rsync()
        self.destination.mkdir(parents=True)
        (self.destination / 'local.mp3').write_bytes(b'keep')
        (self.source / 'new.mp3').write_bytes(b'new')
        (self.home / 'offline').touch()
        failed = self.run_script('--scheduled')
        self.assertNotEqual(failed.returncode, 0)
        self.assertFalse((self.state / 'last-success').exists())
        self.assertFalse((self.home / 'mpd-updates').exists())
        self.assertEqual((self.destination / 'local.mp3').read_bytes(), b'keep')
        (self.home / 'offline').unlink()
        retried = self.run_script('--scheduled')
        self.assertEqual(retried.returncode, 0, retried.stdout + retried.stderr)
        self.assertEqual((self.destination / 'new.mp3').read_bytes(), b'new')

    def test_preview_does_not_copy_files_or_mark_the_day_as_done(self):
        self.require_rsync()
        (self.source / 'preview.mp3').write_bytes(b'preview')
        result = self.run_script('--dry-run')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.destination / 'preview.mp3').exists())
        self.assertFalse((self.state / 'last-success').exists())
        self.assertFalse((self.home / 'mpd-updates').exists())

    def test_existing_sync_lock_prevents_an_overlapping_transfer(self):
        self.require_rsync()
        self.state.mkdir(parents=True)
        with (self.state / 'sync.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_script('--scheduled')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / 'ssh-calls').exists(),
                         'a second invocation must not start another transfer')
        self.assertFalse((self.state / 'last-success').exists())

    def test_interrupted_download_keeps_partial_audio_outside_the_music_library(self):
        self.require_rsync()
        (self.source / 'interrupted.mp3').write_bytes(b'partial audio' * 500000)
        (self.home / 'interrupt-transfer').touch()
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(list(self.destination.rglob('*.mp3')),
                         'players must not discover incomplete audio as an extra song')
        partials = list((self.state / 'partial').rglob('*.mp3'))
        self.assertTrue(partials, 'interrupted downloads should remain resumable')
        self.assertGreater(partials[0].stat().st_size, 0)
        self.assertFalse((self.state / 'last-success').exists())

    def test_missing_or_unsafe_config_never_contacts_a_host(self):
        for host in ('', '-oProxyCommand=bad', 'host:/a/path'):
            with self.subTest(host=host):
                self.write_config(host)
                result = self.run_script('--check-config')
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.home / 'ssh-calls').exists())
        (self.config_dir / 'config').unlink()
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / 'ssh-calls').exists())

    def test_setup_creates_template_without_enabling_or_overwriting_local_config(self):
        (self.config_dir / 'config').unlink()
        first = self.run_script('--setup', setup=True)
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        config = self.config_dir / 'config'
        self.assertTrue(config.is_file())
        self.assertEqual(config.stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.home / 'launchctl-calls').exists())
        self.assertFalse((self.home / 'Library/LaunchAgents/com.local.music-sync.plist').exists())
        self.write_config()
        before = config.read_bytes()
        second = self.run_script('--setup', setup=True)
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertEqual(config.read_bytes(), before)
        self.assertTrue((self.home / '.local/bin/music-sync').is_symlink())
        self.assertTrue((self.home / '.local/bin/music').is_symlink())

    def test_invalid_source_directory_cannot_turn_into_a_whole_home_or_daemon_pull(self):
        for remote in ('/', '///', '~', '~/', '.', '..', ':module', 'Music/../', 'Music/*'):
            with self.subTest(remote=remote):
                self.write_config(remote=remote)
                result = self.run_script('--check-config')
                self.assertNotEqual(result.returncode, 0, remote)
                self.assertFalse((self.home / 'ssh-calls').exists())

    def test_enable_renders_daily_agent_with_expanded_paths_and_disable_keeps_music(self):
        result = self.run_script('--enable', setup=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        agent = self.home / 'Library/LaunchAgents/com.local.music-sync.plist'
        with agent.open('rb') as f:
            plist = plistlib.load(f)
        self.assertEqual(plist['StartCalendarInterval'], {'Hour': 9, 'Minute': 0})
        self.assertTrue(plist['RunAtLoad'])
        self.assertEqual(plist['ProgramArguments'],
                         ['/bin/bash', str(ROOT / 'scripts/music-sync.sh'), '--scheduled'])
        self.assertEqual(plist['EnvironmentVariables']['XDG_CONFIG_HOME'],
                         self.env['XDG_CONFIG_HOME'])
        self.assertTrue((self.config_dir / 'enabled').exists())
        self.assertFalse((self.home / 'ssh-calls').exists())
        self.destination.mkdir(parents=True)
        (self.destination / 'keep.mp3').write_bytes(b'keep')
        disabled = self.run_script('--disable', setup=True)
        self.assertEqual(disabled.returncode, 0, disabled.stdout + disabled.stderr)
        self.assertFalse(agent.exists())
        self.assertFalse((self.config_dir / 'enabled').exists())
        self.assertEqual((self.destination / 'keep.mp3').read_bytes(), b'keep')
        self.assertTrue((self.config_dir / 'config').exists())

    def test_player_lists_are_pulled_alongside_audio_when_enabled(self):
        self.require_rsync()
        remote = self.home / 'remote-cliamp'
        (remote / 'playlists').mkdir(parents=True)
        (remote / 'playlists/Chill.toml').write_text('[[dir]]\npath = ' + json.dumps(str(self.source / 'Chill'), ensure_ascii=False) + '\n')
        (remote / 'podcast_subscriptions.json').write_text('[{"title":"Rebuild","feed_url":"https://feeds.rebuild.fm/rebuildfm"}]')
        with (self.config_dir / 'config').open('a') as f:
            f.write('MUSIC_SYNC_CLIAMP=1\n')
            f.write(f'MUSIC_SYNC_REMOTE_CLIAMP_DIR={shlex.quote(str(remote))}\n')
        # Only SSH is replaced: execute the uploaded export script locally.
        self.executable('ssh', f'''#!{sys.executable}
import os, shlex, sys
args=sys.argv[1:]
remote=args[args.index('music-source')+1:]
if remote[0] == 'rsync':
    os.execv(os.environ['TEST_RSYNC'], [os.environ['TEST_RSYNC'], *remote[1:]])
os.environ['HOME']=os.environ['TEST_HOME']
os.execvp('python3', shlex.split(remote[0]))
''')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        target = self.home / 'custom config/cliamp'
        self.assertTrue((target / 'podcast_subscriptions.json').exists())
        self.assertIn(str(self.destination / 'Chill'), (target / 'playlists/Chill.toml').read_text())
        self.assertTrue((self.state / 'last-success').exists())

    def test_failed_agent_registration_does_not_mark_sync_enabled(self):
        (self.home / 'bootstrap-fails').touch()
        result = self.run_script('--enable', setup=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.config_dir / 'enabled').exists())
        self.assertFalse((self.home / 'Library/LaunchAgents/com.local.music-sync.plist').exists(),
                         'a failed registration must not silently enable sync at the next login')


if __name__ == '__main__':
    unittest.main()
