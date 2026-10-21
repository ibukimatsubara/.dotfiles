#!/usr/bin/env python3
"""Read the local Claude Code weekly rate-limit snapshot. Never contacts a service.

The snapshot is written by the Claude Code statusLine script
(agent-env: harnesses/claude/statusline-command.sh).
"""
import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import time

MAX_BYTES = 65536
STALE_SECONDS = 3600


def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def snapshot(path, now=None):
    now = time.time() if now is None else now
    result = {'available': False, 'label': '--', 'tooltip': 'No local Claude Code weekly usage snapshot\nRun Claude Code to refresh',
              'remaining_percent': None, 'weekly': None,
              'stale': False, 'snapshot_at': None}
    try:
        with Path(path).open('rb') as handle:
            data = json.loads(handle.read(MAX_BYTES))
        raw = data['rate_limits']['seven_day']
        used = raw['used_percentage']
        captured = data.get('captured_at')
    except (OSError, ValueError, TypeError, KeyError, AttributeError):
        return result
    if not number(used):
        return result
    resets_at = raw.get('resets_at') if number(raw.get('resets_at')) else None
    captured = captured if number(captured) and captured <= now + 300 else None
    weekly = {'used_percent': min(100, max(0, used)), 'resets_at': resets_at}
    # A window whose reset time has passed is full again, even if no newer snapshot exists.
    reset = resets_at is not None and resets_at <= now
    remaining = 100 if reset else round(100 - weekly['used_percent'])
    stale = captured is None or now - captured > STALE_SECONDS
    detail = f'Weekly: {remaining}% remaining'
    if reset:
        detail += '; reset since snapshot'
    elif resets_at is not None:
        try:
            detail += '; resets ' + datetime.fromtimestamp(resets_at).astimezone().strftime('%a %m/%d %H:%M')
        except (ValueError, OverflowError, OSError):
            pass
    stamp = datetime.fromtimestamp(captured, timezone.utc).isoformat() if captured is not None else None
    result.update(available=True, label=f'{remaining}%',
                  tooltip=('Stale local snapshot\n' if stale else 'Local snapshot\n') + detail + ('\nUpdated ' + datetime.fromtimestamp(captured).astimezone().strftime('%a %m/%d %H:%M') if stamp else ''),
                  remaining_percent=remaining, weekly=weekly, stale=stale, snapshot_at=stamp)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    cache = Path(os.environ.get('XDG_CACHE_HOME') or Path.home() / '.cache')
    print(json.dumps(snapshot(cache / 'claude-code' / 'rate-limits.json')))


if __name__ == '__main__':
    main()
