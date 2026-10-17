#!/usr/bin/env python3
"""Check portable cliamp lists, pending updates, and recovery with real files."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parent.parent


class PlayerSyncTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('player_sync', ROOT / 'scripts/music-player-sync.py')
        self.sync = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.sync)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.config = root / 'Mac config'
        self.state = root / 'state'
        self.music = root / 'Music/Shared'
        self.config.mkdir()
        self.state.mkdir()
        self.snapshot = {
            'version': 1, 'music_roots': ['~/Music', '/home/alice/Music', '/srv/audio'],
            'playlists': {'Lofi.toml': '[[dir]]\npath = "~/Music/Lo-fi"\nrecursive = false\n\n'
                          '[[track]]\npath = "/srv/audio/猫.mp3"\ntitle = "猫"\nbookmark = true\n\n'
                          '[[track]]\npath = "https://example.org/radio"\ntitle = "Radio"\n'},
            'subscriptions': [{'title': 'Rebuild', 'feed_url': 'https://feeds.rebuild.fm/rebuildfm'}],
        }

    def stage(self):
        self.sync.stage(self.snapshot, self.config, self.music, self.state)

    def apply(self):
        return self.sync.apply_pending(self.config, self.state)

    def test_paths_are_translated_without_losing_track_order_or_bookmarks(self):
        self.stage()
        self.assertTrue(self.apply())
        data = tomllib.loads((self.config / 'playlists/Lofi.toml').read_text())
        self.assertEqual(data['dir'][0], {'path': str(self.music / 'Lo-fi'), 'recursive': False})
        self.assertEqual(data['track'][0]['path'], str(self.music / '猫.mp3'))
        self.assertTrue(data['track'][0]['bookmark'])
        self.assertEqual(data['track'][1]['path'], 'https://example.org/radio')
        self.assertEqual(json.loads((self.config / 'podcast_subscriptions.json').read_text()),
                         [{'title': 'Rebuild', 'feed_url': 'https://feeds.rebuild.fm/rebuildfm'}])

    def test_active_player_keeps_config_untouched_until_next_launch(self):
        (self.config / 'cliamp.sock.pid').write_text(str(os.getpid()))
        (self.config / 'podcast_subscriptions.json').write_text('[]')
        (self.config / 'history.toml').write_text('keep history')
        self.stage()
        self.assertFalse(self.apply())
        self.assertEqual((self.config / 'podcast_subscriptions.json').read_text(), '[]')
        self.assertTrue((self.state / 'cliamp-pending.json').exists())
        (self.config / 'cliamp.sock.pid').unlink()
        self.assertTrue(self.apply())
        self.assertFalse((self.state / 'cliamp-pending.json').exists())
        self.assertEqual((self.config / 'history.toml').read_text(), 'keep history')

    def test_removals_only_touch_previously_synced_lists_and_keep_backups(self):
        (self.config / 'playlists').mkdir()
        (self.config / 'playlists/Lofi.toml').write_text('local original')
        (self.config / 'playlists/Mac-only.toml').write_text('keep this')
        self.stage()
        self.apply()
        self.snapshot['playlists'] = {}
        self.snapshot['subscriptions'] = []
        self.stage()
        self.apply()
        self.assertFalse((self.config / 'playlists/Lofi.toml').exists())
        self.assertEqual((self.config / 'playlists/Mac-only.toml').read_text(), 'keep this')
        self.assertEqual((self.config / 'podcast_subscriptions.json').read_text().strip(), '[]')
        saved = list((self.state / 'backups').rglob('Lofi.toml'))
        self.assertTrue(any(p.read_text() == 'local original' for p in saved))

    def test_invalid_snapshot_does_not_replace_good_pending_or_local_files(self):
        self.stage()
        pending = (self.state / 'cliamp-pending.json').read_bytes()
        for name, text in [('../bad.toml', '[[dir]]\npath="~/Music"'),
                           ('Bad.toml', '[[dir]]\npath="/etc"'),
                           ('Bad.toml', '[[dir]]\npath="~/Music/../secret"'),
                           ('Bad.toml', 'broken TOML')]:
            with self.subTest(name=name, text=text):
                self.snapshot['playlists'] = {name: text}
                with self.assertRaises(ValueError):
                    self.stage()
                self.assertEqual((self.state / 'cliamp-pending.json').read_bytes(), pending)
        self.assertFalse((self.config / 'podcast_subscriptions.json').exists())

    def test_export_only_includes_shared_lists_and_resolves_library_symlink(self):
        remote = self.config
        (remote / 'playlists').mkdir()
        (remote / 'playlists/Music.toml').write_text('[[dir]]\npath="~/Music"\n')
        (remote / 'podcast_subscriptions.json').write_text('[]')
        (remote / 'resume.json').write_text('private resume state')
        (remote / 'history.toml').write_text('private history')
        (remote / 'config.toml').write_text('private credentials')
        library = remote / 'Music'
        self.music.mkdir(parents=True)
        library.symlink_to(self.music, target_is_directory=True)
        data = self.sync.export_snapshot(str(remote), str(library))
        self.assertEqual(set(data), {'version', 'music_roots', 'playlists', 'subscriptions'})
        self.assertIn(str(self.music.resolve()), data['music_roots'])
        self.assertEqual(list(data['playlists']), ['Music.toml'])

    def test_missing_source_or_bad_subscription_is_not_treated_as_unsubscribe(self):
        with self.assertRaises(ValueError):
            self.sync.export_snapshot(str(self.config / 'missing'), str(self.music))
        for subscription in [
                {'title': 'Bad', 'feed_url': 'file:///etc/passwd'},
                {'id': 'feed', 'title': 'Bad', 'feed_url': 'https://example.org/feed',
                 'author': 'Someone', 'artwork': '', 'genre': 'Technology', 'episode_count': 'invalid'}]:
            self.snapshot['subscriptions'] = [subscription]
            with self.subTest(subscription=subscription), self.assertRaises(ValueError):
                self.stage()
        self.assertFalse((self.state / 'cliamp-pending.json').exists())

    def test_launcher_applies_pending_lists_without_network_before_starting_cliamp(self):
        # Omitting the launch-time apply would leave the subscription file absent.
        state_root = self.state
        self.state = state_root / 'music-sync'
        self.state.mkdir()
        self.stage()
        binary = state_root / 'cliamp'
        binary.write_text('#!/bin/sh\ntest -f "$CLIAMP_CONFIG_DIR/podcast_subscriptions.json" || exit 42\nprintf "%s\\n" "$@"\n')
        binary.chmod(0o755)
        env = dict(os.environ, CLIAMP_CONFIG_DIR=str(self.config), XDG_STATE_HOME=str(state_root),
                   PATH=f'{state_root}:' + os.environ.get('PATH', ''))
        result = subprocess.run(['/bin/bash', str(ROOT / 'scripts/music-player.sh'), '--provider', 'podcast'],
                                env=env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('--provider\npodcast', result.stdout)


if __name__ == '__main__':
    unittest.main()
