#!/usr/bin/env python3
"""Print current throughput of the default-route interface. Never contacts a service.

Rates come from the kernel byte counters, so they show what the machine is
transferring now, not what the line could carry.
"""
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

SAMPLE_SECONDS = 1
IW_TIMEOUT_SECONDS = 2


def default_interface(route_file='/proc/net/route'):
    try:
        lines = Path(route_file).read_text().splitlines()[1:]
    except OSError:
        return None
    routes = [line.split() for line in lines]
    # Tie-break by metric, as the kernel does, so a VPN or a second link cannot win by file order.
    defaults = [r for r in routes if len(r) > 6 and r[1] == '00000000' and r[0] != 'lo']
    return min(defaults, key=lambda r: int(r[6]))[0] if defaults else None


def counters(interface, root='/sys/class/net'):
    stats = Path(root) / interface / 'statistics'
    try:
        return int((stats / 'rx_bytes').read_text()), int((stats / 'tx_bytes').read_text())
    except (OSError, ValueError):
        return None


def megabits(start, end, seconds):
    # A counter that went backwards means the interface was reset during the sample.
    return max(0, end - start) * 8 / seconds / 1_000_000


def short_rate(mbps):
    if mbps >= 1000:
        return f'{mbps / 1000:.1f}G'
    if mbps >= 10:
        return f'{mbps:.0f}M'
    return f'{mbps:.1f}M'


def link_detail(interface):
    iw = shutil.which('iw') or '/usr/sbin/iw'
    try:
        output = subprocess.run([iw, 'dev', interface, 'link'], capture_output=True, text=True,
                                timeout=IW_TIMEOUT_SECONDS).stdout
    except (OSError, subprocess.SubprocessError):
        return ''
    found = {key: re.search(pattern, output) for key, pattern in {
        'ssid': r'SSID: (.+)', 'signal': r'signal: (-?\d+ dBm)', 'rate': r'rx bitrate: ([\d.]+ \S+)'}.items()}
    parts = [found['ssid'] and found['ssid'][1], found['rate'] and 'Link ' + found['rate'][1],
             found['signal'] and 'Signal ' + found['signal'][1]]
    return ' · '.join(part for part in parts if part)


def snapshot(interface, start, end, seconds, detail=''):
    if start is None or end is None:
        return {'available': False, 'label': '--', 'tooltip': 'No active network'}
    down = megabits(start[0], end[0], seconds)
    up = megabits(start[1], end[1], seconds)
    lines = [f'{interface}: down {down:.1f} Mbps · up {up:.1f} Mbps']
    if detail:
        lines.append(detail)
    return {'available': True, 'label': f'↓{short_rate(down)} ↑{short_rate(up)}',
            'tooltip': '\n'.join(lines), 'down_mbps': round(down, 2), 'up_mbps': round(up, 2)}


def main():
    interface = default_interface()
    start = counters(interface) if interface else None
    began = time.monotonic()
    time.sleep(SAMPLE_SECONDS)
    end = counters(interface) if interface else None
    elapsed = time.monotonic() - began
    print(json.dumps(snapshot(interface, start, end, elapsed, link_detail(interface) if interface else ''),
                     ensure_ascii=False))


if __name__ == '__main__':
    main()
