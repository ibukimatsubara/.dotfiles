#!/usr/bin/env -S uv run --offline --no-project python
"""Observe host listeners, this user's known tunnel tools, and local Funnel state."""

import argparse
from datetime import datetime, timezone
import ipaddress
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


class CollectionError(Exception):
    pass


def command(args, reason):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=4)
    except (OSError, subprocess.TimeoutExpired):
        raise CollectionError(reason) from None
    if result.returncode:
        raise CollectionError(reason)
    return result.stdout


def parse_listeners(output):
    listeners = set()
    for line in output.splitlines():
        columns = line.split()
        if len(columns) < 5 or columns[0] != "LISTEN":
            raise CollectionError("listener_format_unknown")
        try:
            address, port = columns[3].rsplit(":", 1)
            address = address.split("%", 1)[0].strip("[]")
            port = int(port)
            if not 0 < port <= 65535:
                raise ValueError
            if address != "*":
                parsed = ipaddress.ip_address(address)
                if parsed.is_loopback or (getattr(parsed, "ipv4_mapped", None) and parsed.ipv4_mapped.is_loopback):
                    continue
        except ValueError:
            raise CollectionError("listener_format_unknown") from None
        listeners.add((address, port))
    return [{"address": address, "port": port} for address, port in sorted(listeners)]


def tunnel_kind(args):
    if not args:
        return None
    name = Path(args[0]).name
    known = {"cloudflared", "ngrok", "frpc", "chisel", "rathole", "tmate", "rustdesk", "anydesk", "meshagent"}
    if name in known:
        return name
    if name in {"ssh", "autossh"} and any(
        re.match(r"^-[^-]*R", arg) or arg.lower().lstrip("-o").startswith("remoteforward=")
        for arg in args[1:]
    ):
        return "ssh-reverse-forward"
    if any(Path(arg).name in {"code", "code-insiders", "code-tunnel"} for arg in args[:2]) and "tunnel" in args[1:]:
        return "vscode-tunnel"
    return None


def collect_tunnels(proc=Path("/proc")):
    kinds = set()
    try:
        entries = list(proc.iterdir())
        for entry in entries:
            if not entry.name.isdigit():
                continue
            try:
                if entry.stat().st_uid != os.getuid():
                    continue
                with (entry / "cmdline").open("rb") as source:
                    raw = source.read(65536)
                args = [arg.decode(errors="replace") for arg in raw.split(b"\0") if arg]
                kind = tunnel_kind(args)
                if kind:
                    kinds.add(kind)
            except (FileNotFoundError, ProcessLookupError):
                continue
    except OSError:
        raise CollectionError("user_process_coverage_unknown") from None
    return sorted(kinds)


def funnel_enabled(data):
    if not isinstance(data, dict) or (data and not set(data).intersection({"TCP", "Web", "AllowFunnel", "Foreground", "Services"})):
        raise CollectionError("funnel_format_unknown")
    enabled = False
    for key, value in data.items():
        if key == "AllowFunnel":
            if value is not None and (not isinstance(value, dict) or any(type(flag) is not bool for flag in value.values())):
                raise CollectionError("funnel_format_unknown")
            enabled |= any((value or {}).values())
        elif key in {"Foreground", "Services"} and value is not None:
            if not isinstance(value, dict):
                raise CollectionError("funnel_format_unknown")
            enabled |= any(funnel_enabled(child) for child in value.values())
    return enabled


def collect_snapshot():
    listeners = parse_listeners(command(["/usr/bin/ss", "-H", "-lnt"], "listeners_unavailable"))
    tunnels = collect_tunnels()
    try:
        funnel = json.loads(command(["/usr/bin/tailscale", "funnel", "status", "--json"], "funnel_unavailable"))
    except (ValueError, UnicodeError):
        raise CollectionError("funnel_format_unknown") from None
    return {"listeners": listeners, "user_tunnel_kinds": tunnels, "funnel_enabled": funnel_enabled(funnel)}


def atomic_json(path, data):
    descriptor, temporary = tempfile.mkstemp(prefix=".network-watch-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as target:
            json.dump(data, target, sort_keys=True)
            target.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def changes(before, after):
    encode = lambda value: json.dumps(value, sort_keys=True)
    result = {}
    for field in ("listeners", "user_tunnel_kinds"):
        old = {encode(value) for value in before[field]}
        new = {encode(value) for value in after[field]}
        result[field] = {"added": [json.loads(value) for value in sorted(new - old)],
                         "removed": [json.loads(value) for value in sorted(old - new)]}
    result["funnel_changed"] = before["funnel_enabled"] != after["funnel_enabled"]
    return result


def run(state):
    if state.is_symlink():
        raise CollectionError("state_directory_unsafe")
    state.mkdir(parents=True, mode=0o700, exist_ok=True)
    state.chmod(0o700)
    stamp = datetime.now(timezone.utc).isoformat()
    baseline = state / "last-success.json"
    try:
        before = None
        if baseline.exists():
            if baseline.is_symlink() or baseline.stat().st_size > 1024 * 1024:
                raise CollectionError("baseline_unknown")
            try:
                before = json.loads(baseline.read_text())
                if set(before) != {"listeners", "user_tunnel_kinds", "funnel_enabled"}:
                    raise ValueError
                changes(before, before)
            except (ValueError, KeyError, TypeError, OSError):
                raise CollectionError("baseline_unknown") from None
        snapshot = collect_snapshot()
        delta = changes(before, snapshot) if before is not None else None
        atomic_json(baseline, snapshot)
        atomic_json(state / "latest.json", {"checked_at": stamp, "status": "ok", "initial_baseline": before is None,
                    "coverage": "non-loopback TCP; current-user known tunnel forms; local Funnel", "snapshot": snapshot, "changes": delta})
    except CollectionError as error:
        atomic_json(state / "latest.json", {"checked_at": stamp, "status": "unknown", "reason": str(error)})
        print("network-watch: status=unknown reason=" + str(error))
        return 1
    if before is None:
        print("network-watch: baseline established")
    elif any(delta[field][direction] for field in ("listeners", "user_tunnel_kinds") for direction in ("added", "removed")) or delta["funnel_changed"]:
        print("network-watch: change recorded; inspect latest.json")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, default=Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "ubuntu-network-watch")
    options = parser.parse_args()
    try:
        raise SystemExit(run(options.state_dir))
    except (CollectionError, OSError):
        print("network-watch: status=unknown reason=state_unavailable")
        raise SystemExit(1)
