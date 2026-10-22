#!/usr/bin/env -S uv run --offline --no-project python
"""Exercise firewall behavior only in a disposable root network namespace."""

import ipaddress
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import socketserver
import subprocess
import threading
import time


if os.geteuid() != 0 or os.readlink("/proc/self/ns/net") == os.readlink("/proc/1/ns/net"):
    raise SystemExit("Run as root inside unshare --net; host namespace execution is refused.")

RULES = Path(__file__).resolve().parent.parent / "platforms/ubuntu/systemd/ubuntu-ingress-guard.nft"
UV = shutil.which("uv")
assert UV, "uv is required"
PY = [UV, "run", "--offline", "--no-project", "--no-managed-python", "--python", "/usr/bin/python3", "python", "-I", "-c"]
children = []


def call(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=5).stdout


class Echo(socketserver.StreamRequestHandler):
    def handle(self):
        self.request.settimeout(3)
        try:
            while data := self.request.recv(32):
                self.request.sendall(data)
        except (TimeoutError, OSError):
            pass


class Server(socketserver.ThreadingTCPServer):
    address_family = socket.AF_INET6
    allow_reuse_address = True
    daemon_threads = True


def check(label, condition):
    assert condition, label
    print("PASS " + label, flush=True)


try:
    peer = subprocess.Popen(["unshare", "--net", "sleep", "35"], start_new_session=True)
    children.append(peer)
    for _ in range(50):
        if os.readlink(f"/proc/{peer.pid}/ns/net") != os.readlink("/proc/self/ns/net"):
            break
        time.sleep(0.02)
    else:
        raise RuntimeError("peer namespace was not established")
    PEER = ["nsenter", "--target", str(peer.pid), "--net"]
    call("ip", "link", "set", "lo", "up")
    call(*PEER, "ip", "link", "set", "lo", "up")
    call("ip", "link", "add", "guard-host", "type", "veth", "peer", "name", "guard-peer")
    call("ip", "link", "set", "guard-peer", "netns", str(peer.pid))
    for host, client in (("198.51.100.1/24", "198.51.100.2/24"), ("192.168.88.1/24", "192.168.88.2/24"),
                         ("fd00:88::1/64", "fd00:88::2/64"), ("2001:db8:88::1/64", "2001:db8:88::2/64")):
        extra = ["nodad"] if ":" in host else []
        call("ip", "addr", "add", host, "dev", "guard-host", *extra)
        call(*PEER, "ip", "addr", "add", client, "dev", "guard-peer", *extra)
    call("ip", "link", "set", "guard-host", "up")
    call(*PEER, "ip", "link", "set", "guard-peer", "up")
    server = Server(("::", 49200), Echo)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp.bind(("0.0.0.0", 49201))
    def udp_echo():
        data, address = udp.recvfrom(32)
        udp.sendto(data, address)
    threading.Thread(target=udp_echo, daemon=True).start()

    persistent_code = "import socket,sys; s=socket.create_connection(('198.51.100.1',49200),1); s.sendall(b'a'); assert s.recv(1)==b'a'; print('ready',flush=True); sys.stdin.read(1); s.sendall(b'b'); assert s.recv(1)==b'b'"
    persistent = subprocess.Popen([*PEER, *PY, persistent_code], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, text=True, start_new_session=True)
    children.append(persistent)
    assert persistent.stdout.readline().strip() == "ready"
    call("nft", "add", "table", "inet", "fixture_sentinel")
    call("nft", "--check", "--file", str(RULES))
    call("nft", "--file", str(RULES))
    call("nft", "--file", str(RULES))
    check("idempotent apply preserves other tables", bool(call("nft", "list", "table", "inet", "fixture_sentinel")))
    persistent_output, persistent_error = persistent.communicate("x", timeout=3)
    if persistent.returncode:
        print(persistent_error, flush=True)
    check("established public TCP survives", persistent.returncode == 0)

    def connects(source, destination):
        family = "AF_INET6" if ":" in source else "AF_INET"
        code = f"import socket; s=socket.socket(socket.{family}); s.settimeout(.4); s.bind(({source!r},0)); s.connect(({destination!r},49200)); s.sendall(b'ok'); assert s.recv(2)==b'ok'"
        return subprocess.run([*PEER, *PY, code], capture_output=True, timeout=3).returncode == 0
    check("new public IPv4 TCP blocked", not connects("198.51.100.2", "198.51.100.1"))
    check("new public IPv6 TCP blocked", not connects("2001:db8:88::2", "2001:db8:88::1"))
    check("LAN IPv4 TCP preserved", connects("192.168.88.2", "192.168.88.1"))
    check("ULA IPv6 TCP preserved", connects("fd00:88::2", "fd00:88::1"))
    udp_code = "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.settimeout(1); s.sendto(b'ok',('198.51.100.1',49201)); assert s.recv(2)==b'ok'"
    call(*PEER, *PY, udp_code)
    check("public UDP preserved", True)
    with socket.create_connection(("127.0.0.1", 49200), 1) as client:
        client.sendall(b"ok")
        check("loopback TCP preserved", client.recv(2) == b"ok")
    peer_code = "import socket; s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(('0.0.0.0',49202)); s.listen(); print('ready',flush=True); c,a=s.accept(); c.sendall(c.recv(2))"
    peer_server = subprocess.Popen([*PEER, *PY, peer_code], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   text=True, start_new_session=True)
    children.append(peer_server)
    assert peer_server.stdout.readline().strip() == "ready"
    with socket.create_connection(("198.51.100.2", 49202), 1) as client:
        client.sendall(b"ok")
        check("outbound TCP and return traffic preserved", client.recv(2) == b"ok")
    call("ip", "link", "set", "guard-host", "name", "tailscale0")
    check("Tailscale interface TCP preserved", connects("198.51.100.2", "198.51.100.1"))
finally:
    for child in reversed(children):
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            child.wait(timeout=2)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
