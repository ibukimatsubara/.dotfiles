#!/usr/bin/env -S uv run --offline --no-project python
"""Check observer privacy, changes, and preservation of a good baseline on failure."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("network_watch", Path(__file__).with_name("ubuntu-network-watch.py"))
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)


class NetworkWatchTests(unittest.TestCase):
    def test_listener_normalization_excludes_all_loopback_forms(self):
        output = "\n".join("LISTEN 0 128 " + endpoint + " *:*" for endpoint in (
            "127.0.0.1:5000", "[::1]:5000", "[::ffff:127.0.0.1]:5000",
            "*:18555", "0.0.0.0:9000", "[fd7a::1234]%tailscale0:6000", "100.64.0.10%tailscale0:8080"))
        self.assertEqual(watch.parse_listeners(output), [
            {"address": "*", "port": 18555}, {"address": "0.0.0.0", "port": 9000},
            {"address": "100.64.0.10", "port": 8080}, {"address": "fd7a::1234", "port": 6000}])

    def test_invalid_listener_is_unknown_instead_of_empty(self):
        for output in ("bad-output", "LISTEN 0 128 bad *:*", "LISTEN 0 128 *:99999 *:*"):
            with self.subTest(output=output), self.assertRaises(watch.CollectionError):
                watch.parse_listeners(output)

    def test_reverse_ssh_and_code_tunnel_forms(self):
        for args, expected in ((["ssh", "-N", "-R", "9000:localhost:22"], "ssh-reverse-forward"),
                               (["ssh", "-NR9000:localhost:22"], "ssh-reverse-forward"),
                               (["ssh", "-o", "RemoteForward=9000 localhost:22"], "ssh-reverse-forward"),
                               (["code", "tunnel"], "vscode-tunnel"),
                               (["code", "--version"], None), (["ssh", "host"], None)):
            with self.subTest(args=args):
                self.assertEqual(watch.tunnel_kind(args), expected)

    def test_process_snapshot_never_contains_arguments_or_tokens(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "123").mkdir()
            (root / "123/cmdline").write_bytes(b"/usr/bin/cloudflared\0tunnel\0--token\0DO-NOT-RETAIN\0")
            observed = watch.collect_tunnels(root)
            self.assertEqual(observed, ["cloudflared"])
            self.assertNotIn("DO-NOT-RETAIN", json.dumps(observed))

    def test_funnel_nested_flags_and_unknown_response(self):
        self.assertFalse(watch.funnel_enabled({}))
        self.assertFalse(watch.funnel_enabled({"AllowFunnel": {"private.example:443": False}}))
        self.assertTrue(watch.funnel_enabled({"Foreground": {"session": {"AllowFunnel": {"private.example:443": True}}}}))
        for data in (None, [], {"error": "DO-NOT-RETAIN"}, {"AllowFunnel": {"host": "true"}}):
            with self.subTest(data=data), self.assertRaises(watch.CollectionError):
                watch.funnel_enabled(data)

    def test_initial_baseline_then_changes_and_private_files(self):
        first = {"listeners": [], "user_tunnel_kinds": [], "funnel_enabled": False}
        second = {"listeners": [{"address": "*", "port": 9000}], "user_tunnel_kinds": ["ngrok"], "funnel_enabled": True}
        with tempfile.TemporaryDirectory() as temporary, contextlib.redirect_stdout(io.StringIO()):
            state = Path(temporary) / "state"
            with patch.object(watch, "collect_snapshot", return_value=first):
                self.assertEqual(watch.run(state), 0)
            self.assertTrue(json.loads((state / "latest.json").read_text())["initial_baseline"])
            with patch.object(watch, "collect_snapshot", return_value=second):
                self.assertEqual(watch.run(state), 0)
            latest = json.loads((state / "latest.json").read_text())
            self.assertEqual(latest["changes"]["listeners"]["added"], second["listeners"])
            self.assertEqual(latest["changes"]["user_tunnel_kinds"]["added"], ["ngrok"])
            self.assertTrue(latest["changes"]["funnel_changed"])
            self.assertEqual(state.stat().st_mode & 0o777, 0o700)
            for filename in ("latest.json", "last-success.json"):
                self.assertEqual((state / filename).stat().st_mode & 0o777, 0o600)

    def test_collection_failure_preserves_successful_baseline(self):
        snapshot = {"listeners": [{"address": "*", "port": 9000}], "user_tunnel_kinds": [], "funnel_enabled": False}
        with tempfile.TemporaryDirectory() as temporary, contextlib.redirect_stdout(io.StringIO()):
            state = Path(temporary) / "state"
            with patch.object(watch, "collect_snapshot", return_value=snapshot):
                watch.run(state)
            before = (state / "last-success.json").read_bytes()
            with patch.object(watch, "collect_snapshot", side_effect=watch.CollectionError("funnel_unavailable")):
                self.assertEqual(watch.run(state), 1)
            self.assertEqual((state / "last-success.json").read_bytes(), before)
            latest = json.loads((state / "latest.json").read_text())
            self.assertEqual(latest["status"], "unknown")
            self.assertNotIn("changes", latest)

    def test_subprocess_errors_do_not_retain_stderr(self):
        result = subprocess.CompletedProcess(["dummy"], 1, "DO-NOT-RETAIN", "SECRET-ERROR")
        with patch.object(watch.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(watch.CollectionError, "^listeners_unavailable$"):
                watch.command(["dummy"], "listeners_unavailable")


if __name__ == "__main__":
    unittest.main(verbosity=2)
