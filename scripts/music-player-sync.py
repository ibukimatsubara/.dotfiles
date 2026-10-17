#!/usr/bin/env python3
"""Pull only cliamp playlists and subscriptions; keep player state local."""
import argparse
from contextlib import contextmanager
import datetime
import fcntl
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import tomllib
from urllib.parse import urlsplit


def config_dir():
    return Path(os.environ.get('CLIAMP_CONFIG_DIR') or
                str(Path(os.environ.get('XDG_CONFIG_HOME') or str(Path.home() / '.config')) / 'cliamp'))


def valid_url(value):
    if not isinstance(value, str):
        return False
    url = urlsplit(value)
    return url.scheme in ('http', 'https') and bool(url.hostname) and not url.username


def validate_name(name):
    if (not isinstance(name, str) or '/' in name or '\\' in name or
            not name.lower().endswith('.toml') or name.startswith('.') or
            any(ord(c) < 32 for c in name)):
        raise ValueError('Invalid playlist filename')


def export_snapshot(remote_config, remote_music):
    # This mode runs on Ubuntu via SSH. Never export config.toml, history,
    # progress, tokens, logs, sockets, or any recursively discovered files.
    source = Path(os.path.expandvars(remote_config)).expanduser()
    playlists = source / 'playlists'
    subscriptions = source / 'podcast_subscriptions.json'
    if not playlists.is_dir() or not subscriptions.is_file():
        raise ValueError('Initialize Ubuntu cliamp playlists and subscriptions before syncing')
    if source.is_symlink() or playlists.is_symlink() or subscriptions.is_symlink():
        raise ValueError('Shared cliamp configuration must contain regular files')
    music = Path(os.path.expandvars(remote_music)).expanduser().absolute()
    roots = [str(music), str(music.resolve())]
    if music.is_relative_to(Path.home()):
        suffix = str(music.relative_to(Path.home()))
        roots.extend(['~/' + suffix, '$HOME/' + suffix, '${HOME}/' + suffix])
    files = {}
    for path in sorted(playlists.iterdir()):
        if path.suffix.lower() != '.toml':
            continue
        validate_name(path.name)
        if path.is_symlink() or not path.is_file() or path.stat().st_size > 5_000_000:
            raise ValueError('Invalid or oversized playlist')
        files[path.name] = path.read_text()
    return {'version': 1, 'music_roots': roots, 'playlists': files,
            'subscriptions': json.loads(subscriptions.read_text())}


def translate_path(value, roots, music):
    if valid_url(value):
        return value
    if not isinstance(value, str) or '\x00' in value or '..' in PurePosixPath(value).parts:
        raise ValueError('Invalid playlist path')
    value = str(PurePosixPath(value))
    for root in sorted(roots, key=len, reverse=True):
        root = str(PurePosixPath(root))
        if value == root:
            return str(music)
        if value.startswith(root + '/'):
            return str(music / value[len(root) + 1:])
    raise ValueError(f'Playlist path is outside the shared library: {value}')


def translate_playlist(text, roots, music):
    # cliamp's flat TOML format uses scalar fields in [[dir]] / [[track]].
    # Parse every section separately to retain interleaved source order.
    document = tomllib.loads(text)
    if set(document) - {'dir', 'track'}:
        raise ValueError('Unsupported playlist sections')
    headers = list(re.finditer(r'(?m)^\s*\[\[(dir|track)\]\][ \t]*\r?$', text))
    if len(headers) != sum(len(document.get(k, [])) for k in ('dir', 'track')):
        raise ValueError('Unsupported playlist layout')
    result = []
    for i, header in enumerate(headers):
        kind = header.group(1)
        end = headers[i + 1].start() if i + 1 < len(headers) else len(text)
        fields = tomllib.loads(text[header.start():end])[kind][0]
        if 'path' not in fields:
            raise ValueError('Playlist source has no path')
        fields['path'] = translate_path(fields['path'], roots, music)
        result.append(f'[[{kind}]]')
        for key, value in fields.items():
            # Embedded artwork URLs point into cliamp's per-device cache.
            if key == 'album_art_url' and isinstance(value, str) and value.startswith('file:'):
                continue
            if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', key) or not isinstance(value, (str, int, float, bool)):
                raise ValueError('Unsupported playlist field')
            result.append(f'{key} = {json.dumps(value, ensure_ascii=False, allow_nan=False)}')
        result.append('')
    return '\n'.join(result)


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as out:
            out.write(data)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def stage(snapshot, target, music, state):
    if snapshot.get('version') != 1:
        raise ValueError('Unsupported player snapshot version')
    roots = snapshot['music_roots']
    if not roots or not all(isinstance(r, str) and r not in ('', '/', '~') for r in roots):
        raise ValueError('Invalid source library roots')
    lists = {}
    for name, text in snapshot['playlists'].items():
        validate_name(name)
        if name.casefold() in {n.casefold() for n in lists}:
            raise ValueError('Playlist names collide on macOS')
        lists[name] = translate_playlist(text, roots, music)
    subscriptions = snapshot['subscriptions']
    if not isinstance(subscriptions, list) or not all(
            isinstance(s, dict) and isinstance(s.get('title'), str) and valid_url(s.get('feed_url')) and
            all(isinstance(s.get(key, ''), str) for key in ('id', 'author', 'artwork', 'genre')) and
            type(s.get('episode_count', 0)) is int and 0 <= s.get('episode_count', 0) <= sys.maxsize
            for s in subscriptions):
        raise ValueError('Invalid podcast subscription list')
    payload = {'target': str(target.absolute()), 'playlists': lists, 'subscriptions': subscriptions}
    atomic_write(state / 'cliamp-pending.json', json.dumps(payload, ensure_ascii=False, indent=2) + '\n')


def player_running(target):
    try:
        pid = int((target / 'cliamp.sock.pid').read_text().strip())
        if pid > 0:
            os.kill(pid, 0)
            return True
    except PermissionError:
        return True
    except (OSError, ValueError):
        pass
    return False


def apply_pending(target, state):
    pending = state / 'cliamp-pending.json'
    if not pending.exists():
        return True
    payload = json.loads(pending.read_text())
    if payload['target'] != str(target.absolute()):
        raise ValueError('Pending player update belongs to a different config directory')
    if player_running(target):
        print('cliamp is running; shared lists are staged. Close it, then launch music to apply them.')
        return False
    if target.is_symlink() or (target / 'playlists').is_symlink():
        raise ValueError('Shared player settings must use a regular config directory')
    lists = payload['playlists']
    for name in lists:
        validate_name(name)
    manifest = state / 'cliamp-managed.json'
    old = json.loads(manifest.read_text()) if manifest.exists() else {}
    old_names = old.get('playlists', []) if old.get('target') == payload['target'] else []
    for name in old_names:
        validate_name(name)
    writes = {target / 'playlists' / name: text for name, text in lists.items()}
    writes[target / 'podcast_subscriptions.json'] = json.dumps(payload['subscriptions'], ensure_ascii=False, indent=2) + '\n'
    deletes = [target / 'playlists' / name for name in old_names if name not in lists]
    changes = {p: text for p, text in writes.items() if not p.is_file() or p.read_text() != text}
    deletes = [p for p in deletes if p.exists()]
    # Back up overwritten/removed lists, including a local list with the same
    # name. Unmanaged Mac-only lists and all player runtime state stay intact.
    backup = state / 'backups' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    for path in [*changes, *deletes]:
        if path.is_symlink():
            raise ValueError('Refusing to replace a symlink in cliamp configuration')
        if path.is_file():
            saved = backup / path.relative_to(target)
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, saved)
    for path, text in changes.items():
        atomic_write(path, text)
    for path in deletes:
        path.unlink()
    atomic_write(manifest, json.dumps({'target': payload['target'], 'playlists': list(lists)}) + '\n')
    pending.unlink()
    print(f'Applied {len(lists)} shared playlists and {len(payload["subscriptions"])} podcast subscriptions.')
    return True


@contextmanager
def player_lock(state):
    state.mkdir(parents=True, exist_ok=True)
    with (state / 'cliamp.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            yield False
        else:
            yield True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['export', 'pull', 'apply'])
    parser.add_argument('--host')
    parser.add_argument('--remote-config', default='.config/cliamp')
    parser.add_argument('--remote-music')
    parser.add_argument('--local-music')
    args = parser.parse_args()
    if args.mode == 'export':
        print(json.dumps(export_snapshot(args.remote_config, args.remote_music), ensure_ascii=False))
        return
    state = Path(os.environ.get('XDG_STATE_HOME') or str(Path.home() / '.local/state')) / 'music-sync'
    target = config_dir()
    with player_lock(state) as acquired:
        if not acquired:
            print('Player list sync is busy; using the current lists for now.')
            return
        if args.mode == 'pull':
            command = shlex.join(['python3', '-', 'export', '--remote-config', args.remote_config,
                                  '--remote-music', args.remote_music])
            result = subprocess.run(['ssh', '-oBatchMode=yes', '-oConnectTimeout=10',
                                     '-oServerAliveInterval=15', '-oServerAliveCountMax=2', args.host, command],
                                    input=Path(__file__).read_bytes(), capture_output=True, timeout=120)
            if result.returncode:
                raise ValueError('Could not read Ubuntu player lists: ' + result.stderr.decode(errors='replace').strip())
            if len(result.stdout) > 20_000_000:
                raise ValueError('Player snapshot is too large')
            stage(json.loads(result.stdout), target, Path(args.local_music), state)
        apply_pending(target, state)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
        print(f'Player settings sync failed: {error}', file=sys.stderr)
        sys.exit(1)
