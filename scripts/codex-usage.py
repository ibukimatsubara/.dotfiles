#!/usr/bin/env python3
"""Read a bounded, local Codex session snapshot. Never contacts a service."""
import argparse
from datetime import datetime, timezone, timedelta
import json
import math
import os
from pathlib import Path
import time

MAX_FILES = 16
TAIL_BYTES = 262144
LOOKBACK_DAYS = 14
STALE_SECONDS = 3600


def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def window(raw):
    if not isinstance(raw, dict) or not number(raw.get('used_percent')):
        return None
    used = min(100, max(0, raw['used_percent']))
    return {'used_percent': used, 'remaining_percent': 100 - used,
            'window_minutes': raw.get('window_minutes') if number(raw.get('window_minutes')) else None,
            'resets_at': raw.get('resets_at') if number(raw.get('resets_at')) else None}


def snapshot(home, now=None):
    now = time.time() if now is None else now
    result = {'available': False, 'label': '--', 'tooltip': 'No local Codex usage snapshot',
              'remaining_percent': None, 'primary': None, 'secondary': None,
              'stale': False, 'snapshot_at': None}
    files = []
    # Bound traversal as well as reads: only known daily directories, then recent files.
    for offset in range(LOOKBACK_DAYS):
        day = datetime.fromtimestamp(now, timezone.utc) - timedelta(days=offset)
        directory = Path(home) / 'sessions' / day.strftime('%Y/%m/%d')
        try:
            files.extend((p.stat().st_mtime, p) for p in directory.glob('*.jsonl') if p.is_file())
        except OSError:
            continue
    latest = None
    for _, path in sorted(files, reverse=True)[:MAX_FILES]:
        try:
            with path.open('rb') as handle:
                handle.seek(0, 2)
                start = max(0, handle.tell() - TAIL_BYTES)
                handle.seek(start)
                if start:
                    handle.readline()  # Discard a possibly partial JSON record.
                lines = handle.read(TAIL_BYTES).splitlines()
        except OSError:
            continue
        for line in lines:
            try:
                event = json.loads(line)
                limits = event['payload']['rate_limits']
                if limits.get('limit_id') != 'codex':
                    continue
                primary = window(limits.get('primary'))
                if primary is None:
                    continue
                stamp = datetime.fromisoformat(event['timestamp'].replace('Z', '+00:00'))
                if stamp.tzinfo is None:
                    continue
                epoch = stamp.timestamp()
                if epoch > now + 300:
                    continue
                if latest is None or epoch > latest[0]:
                    latest = (epoch, primary, window(limits.get('secondary')))
            except (ValueError, TypeError, KeyError, AttributeError, OverflowError):
                continue
    if latest is None:
        return result
    epoch, primary, secondary = latest
    windows = [w for w in (primary, secondary) if w is not None]
    remaining = min(w['remaining_percent'] for w in windows)
    stale = now - epoch > STALE_SECONDS or datetime.fromtimestamp(epoch, timezone.utc).date() != datetime.fromtimestamp(now, timezone.utc).date()
    stamp = datetime.fromtimestamp(epoch, timezone.utc).isoformat()
    descriptions = []
    for name, item in [('Primary', primary), ('Secondary', secondary)]:
        if item:
            detail = f"{name}: {item['remaining_percent']:g}% remaining"
            if item['window_minutes'] is not None:
                detail += f" ({item['window_minutes']:g} min window)"
            if item['resets_at'] is not None:
                try:
                    detail += '; resets ' + datetime.fromtimestamp(item['resets_at'], timezone.utc).isoformat()
                except (ValueError, OverflowError, OSError):
                    pass
            descriptions.append(detail)
    result.update(available=True, label=f'{remaining:g}%' + (' stale' if stale else ''),
                  tooltip=('Stale local snapshot\n' if stale else 'Local snapshot\n') + '\n'.join(descriptions) + '\nUpdated ' + stamp,
                  remaining_percent=remaining, primary=primary, secondary=secondary,
                  stale=stale, snapshot_at=stamp)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    print(json.dumps(snapshot(Path(os.environ.get('CODEX_HOME', Path.home() / '.codex')))))


if __name__ == '__main__':
    main()
