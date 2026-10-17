#!/usr/bin/env python3
"""Select an explicitly preferred PipeWire microphone in the current user session."""
import argparse
import fnmatch
import json
import os
from pathlib import Path
import subprocess
import time


def sources(data):
    found = []
    for node in data:
        if node.get('type') != 'PipeWire:Interface:Node':
            continue
        props = node.get('info', {}).get('props', {})
        name = props.get('node.name', '')
        if (props.get('media.class') != 'Audio/Source' or not name
                or name.endswith('.monitor') or props.get('device.class') == 'monitor'
                or props.get('stream.capture.sink') in (True, 'true')
                or props.get('node.virtual') in (True, 'true')):
            continue
        found.append({'id': node['id'], 'name': name,
                      'description': props.get('node.description', props.get('node.nick', name))})
    return sorted(found, key=lambda node: node['name'])


def choose(nodes, preferences):
    for pattern in preferences:
        for node in nodes:
            if fnmatch.fnmatchcase(node['name'], pattern):
                return node
    return None


def plan(data, preferences):
    target = choose(sources(data), preferences)
    if target is None:
        return {'status': 'no-match', 'target': None}
    for obj in data:
        if obj.get('type') != 'PipeWire:Interface:Metadata':
            continue
        for entry in obj.get('metadata', []):
            if entry.get('key') == 'default.audio.source':
                try:
                    value = entry.get('value')
                    value = json.loads(value) if isinstance(value, str) else value
                    if value.get('name') == target['name']:
                        return {'status': 'unchanged', 'target': target}
                except (ValueError, AttributeError):
                    pass
    return {'status': 'select', 'target': target}


def preferences(path):
    try:
        config = json.loads(path.read_text())
    except FileNotFoundError:
        return []
    patterns = config.get('preferred_sources') if isinstance(config, dict) else None
    if not isinstance(patterns, list) or any(not isinstance(p, str) or not p for p in patterns):
        raise ValueError('preferred_sources must be an array of nonempty node.name glob patterns')
    return patterns


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--list', action='store_true', help='print available input nodes as JSON')
    mode.add_argument('--once', action='store_true')
    mode.add_argument('--watch', action='store_true', help='reconcile every five seconds')
    parser.add_argument('--dry-run', action='store_true', help='report selection without setting a default')
    parser.add_argument('--config', type=Path, default=Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'dotfiles/mic-priority.json')
    args = parser.parse_args()
    while True:
        try:
            data = json.loads(subprocess.run(['pw-dump'], check=True, capture_output=True, text=True, timeout=10).stdout)
            if args.list:
                print(json.dumps(sources(data)))
                return 0
            result = plan(data, preferences(args.config))
            if result['status'] == 'select':
                if args.dry_run:
                    result['status'] = 'would-select'
                else:
                    subprocess.run(['wpctl', 'set-default', str(result['target']['id'])], check=True, capture_output=True, timeout=10)
                    result['status'] = 'selected'
            print(json.dumps(result), flush=True)
        except (OSError, ValueError, subprocess.SubprocessError) as exc:
            # Do not expose command output, which may contain session/device details.
            print(json.dumps({'status': 'error', 'error': type(exc).__name__}), flush=True)
            if not args.watch:
                return 1
        if not args.watch:
            return 0
        time.sleep(5)


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        pass
