#!/usr/bin/env python3
"""Check opt-in isolation, daily updates, failure recovery, and terminal layout."""

import copy
from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from zoneinfo import ZoneInfo


REPO_DIR = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("mibuki_metrics", REPO_DIR / "scripts/mibuki-metrics.py")
metrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metrics)


class MetricsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        env_patch = patch.dict(os.environ, {"REVENUECAT_API_KEY": ""})
        env_patch.start()
        self.addCleanup(env_patch.stop)
        root = Path(self.temp.name)
        for name in ("CONFIG_DIR", "DATA_DIR", "STATE_DIR"):
            self.patch = patch.object(metrics, name, root / name.lower() / "mibuki-metrics")
            self.patch.start()
            self.addCleanup(self.patch.stop)
        self.config = {
            "services": [{
                "id": "langdict", "name": "LangDict", "reporting_timezone": "Asia/Tokyo",
                "monthly_price_usd": "4.99", "analytics": {
                    "source": "bigquery", "project_id": "test-project", "dataset_id": "analytics_123",
                    "location": "US", "maximum_bytes_billed": 10485760,
                }, "revenuecat": {"project_id": "proj123", "api_key_file": str(root / "key")},
            }],
        }
        (root / "key").write_text("test-secret")

    def test_no_opt_in_does_not_read_config_or_authenticate(self):
        with patch("sys.argv", ["metrics"]), patch.object(metrics, "read_json") as read:
            self.assertEqual(metrics.main(), 0)
            read.assert_not_called()
        self.assertFalse(metrics.DATA_DIR.exists())

    def test_bigquery_requests_only_yesterday_with_billing_limit(self):
        with patch.object(metrics, "request_json", return_value={
            "jobComplete": True, "rows": [{"f": [{"v": "7"}]}],
        }) as request:
            self.assertEqual(metrics.fetch_dau(self.config["services"][0], "token", "2026-10-13"), 7)
            body = request.call_args.args[2]
            self.assertIn("events_20261013", body["query"])
            self.assertIn("IF(is_active_user, user_pseudo_id, NULL)", body["query"])
            self.assertEqual(body["maximumBytesBilled"], "10485760")
            self.assertNotIn("*", body["query"])

    def test_missing_export_is_an_error_instead_of_zero(self):
        with patch.object(metrics, "request_json", side_effect=metrics.MetricsError("http_404")):
            with self.assertRaisesRegex(metrics.MetricsError, "http_404"):
                metrics.fetch_dau(self.config["services"][0], "token", "2026-10-13")

    def test_revenuecat_uses_subscription_metric_instead_of_trials(self):
        with patch.object(metrics, "request_json", return_value={"metrics": [
            {"id": "active_trials", "value": 5}, {"id": "active_subscriptions", "value": 3.0},
        ]}) as request:
            self.assertEqual(metrics.fetch_subscribers(self.config["services"][0]), 3)
            self.assertEqual(request.call_args.args[1], "test-secret")
            self.assertTrue(request.call_args.args[0].endswith("metrics/overview?currency=USD"))

    def test_missing_subscriber_metric_is_an_error(self):
        with patch.object(metrics, "request_json", return_value={"metrics": []}):
            with self.assertRaisesRegex(metrics.MetricsError, "missing_subscriber_metric"):
                metrics.fetch_subscribers(self.config["services"][0])

    def test_revenuecat_key_can_come_from_the_local_environment(self):
        with patch.dict(os.environ, {"REVENUECAT_API_KEY": "test-env-key"}), \
                patch.object(metrics, "request_json", return_value={"metrics": [
                    {"id": "active_subscriptions", "value": 3},
                ]}) as request:
            self.assertEqual(metrics.fetch_subscribers(self.config["services"][0]), 3)
            self.assertEqual(request.call_args.args[1], "test-env-key")

    def test_successful_zero_is_cached_once_per_day(self):
        with patch.object(metrics, "command_output", return_value="secret-token") as auth, \
                patch.object(metrics, "fetch_dau", return_value=0) as dau, \
                patch.object(metrics, "fetch_subscribers", return_value=0) as subs:
            self.assertEqual(metrics.refresh(self.config), 0)
            self.assertEqual(metrics.refresh(self.config), 0)
            self.assertEqual(auth.call_count, 1)
            self.assertEqual(dau.call_count, 1)
            self.assertEqual(subs.call_count, 1)
        panel = (metrics.DATA_DIR / "panel.txt").read_text()
        self.assertIn("$0.00", panel)
        self.assertNotIn("--", panel)
        self.assertNotIn("secret", (metrics.DATA_DIR / "snapshot.json").read_text())
        self.assertEqual((metrics.DATA_DIR / "snapshot.json").stat().st_mode & 0o777, 0o600)

    def test_failed_metric_keeps_old_value_and_retries_independently(self):
        old_date = (datetime.now(ZoneInfo("Asia/Tokyo")).date() - timedelta(days=1)).isoformat()
        old_stamp = "2026-01-01T10:00:00+09:00"
        metrics.atomic_write(metrics.DATA_DIR / "snapshot.json", json.dumps({"services": {
            "langdict": {"subscribers": {"value": 3, "refreshed_on": old_date, "updated_at": old_stamp}},
        }}))
        with patch.object(metrics, "command_output", return_value="secret-token"), \
                patch.object(metrics, "fetch_dau", return_value=7) as dau, \
                patch.object(metrics, "fetch_subscribers", side_effect=metrics.MetricsError("http_503")) as subs:
            self.assertEqual(metrics.refresh(self.config), 1)
            self.assertEqual(metrics.refresh(self.config), 1)
            self.assertEqual(dau.call_count, 1)
            self.assertEqual(subs.call_count, 2)
        panel = (metrics.DATA_DIR / "panel.txt").read_text()
        self.assertIn("3 cached", panel)
        self.assertIn("$14.97 cached", panel)
        log = (metrics.STATE_DIR / "refresh.log").read_text()
        self.assertIn("http_503", log)
        self.assertNotIn("secret", log)

    def test_monthly_estimate_and_actual_report_date(self):
        now = datetime(2026, 10, 14, 12, tzinfo=timezone.utc)
        snapshot = {"services": {"langdict": {
            "dau": {"value": 7, "date": "2026-10-13"},
            "subscribers": {"value": 3, "refreshed_on": "2026-10-14"},
        }}}
        panel = metrics.render_panel(self.config, snapshot, now)
        self.assertIn("DAU (10/13)   7", panel)
        self.assertIn("$14.97", panel)
        self.assertNotIn("cached", panel)
        self.assertNotIn("MAU", panel)
        self.assertNotIn("USD / subscriber", panel)

    def test_corrupt_cache_does_not_print_untrusted_text(self):
        metrics.atomic_write(metrics.DATA_DIR / "snapshot.json", json.dumps({"services": {
            "langdict": {"dau": {"value": "\u001b[31msecret"}},
        }}))
        panel = metrics.render_panel(self.config, metrics.cached_snapshot())
        self.assertIn("--", panel)
        self.assertNotIn("secret", panel)

    def test_invalid_prices_and_terminal_control_characters_are_rejected(self):
        for field, value in (("monthly_price_usd", "NaN"), ("monthly_price_usd", "-1"),
                             ("name", "LangDict\u001b[31m")):
            config = copy.deepcopy(self.config)
            config["services"][0][field] = value
            with self.assertRaises(metrics.MetricsError):
                metrics.validate_config(config)

    def test_adding_a_service_produces_another_panel(self):
        config = copy.deepcopy(self.config)
        extra = copy.deepcopy(config["services"][0])
        extra.update(id="another-service", name="Another service")
        config["services"].append(extra)
        metrics.validate_config(config)
        panel = metrics.render_panel(config, {})
        self.assertIn("LangDict", panel)
        self.assertIn("Another service", panel)

    def banner(self, width, enabled=True, height=30, color=False, no_color=False):
        metrics.private_dir(metrics.CONFIG_DIR)
        if enabled:
            (metrics.CONFIG_DIR / "enabled").touch()
        metrics.atomic_write(metrics.DATA_DIR / "panel.txt", "LangDict\nDAU (10/13)   7\nSubscribers   3\nEst. / month  $14.97\n")
        env = {**os.environ, "XDG_CONFIG_HOME": str(metrics.CONFIG_DIR.parent),
               "XDG_DATA_HOME": str(metrics.DATA_DIR.parent),
               "MIBUKI_BANNER_COLOR": "1" if color else "0", "TERM": "xterm-256color"}
        env.pop("NO_COLOR", None)
        if no_color:
            env["NO_COLOR"] = "1"
        return subprocess.check_output([
            "zsh", "-f", "-c",
            'COLUMNS=$1; LINES=$3; source "$2"; mibuki_banner', "test", str(width),
            str(REPO_DIR / "zsh/configs/startup-banner.zsh"),
            str(height),
        ], env=env, text=True)

    def test_wide_terminal_places_metrics_beside_logo(self):
        output = self.banner(100)
        heading = next(line for line in output.splitlines() if "LangDict" in line)
        self.assertIn("⣿", heading)
        self.assertTrue(all(len(line) <= 100 for line in output.splitlines()))

    def test_narrow_terminal_places_metrics_below_logo(self):
        output = self.banner(50)
        heading = next(line for line in output.splitlines() if "LangDict" in line)
        self.assertEqual(heading, "LangDict")
        self.assertTrue(all(len(line) <= 50 for line in output.splitlines()))

    def test_unconfigured_computer_never_displays_a_copied_cache(self):
        self.assertNotIn("LangDict", self.banner(100, enabled=False))

    def test_short_narrow_pane_leaves_room_for_the_prompt(self):
        output = self.banner(50, height=18)
        self.assertIn("LangDict", output)
        self.assertLess(len(output.splitlines()), 18)

    def test_color_preserves_the_layout_at_both_widths(self):
        for width in (50, 100):
            plain = self.banner(width)
            colored = self.banner(width, color=True)
            self.assertIn("\u001b[", colored)
            self.assertEqual(re.sub(r"\u001b\[[0-9;]*m", "", colored), plain)

    def test_no_color_suppresses_even_explicit_color(self):
        self.assertNotIn("\u001b[", self.banner(100, color=True, no_color=True))


if __name__ == "__main__":
    unittest.main()
