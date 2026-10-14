#!/usr/bin/env python3
"""Cache service metrics on explicitly enabled computers; never run from the prompt."""

import argparse
from datetime import datetime, timedelta
from decimal import Decimal, InvalidOperation
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo


class MetricsError(Exception):
    """A bounded error code safe to write to local logs."""


def local_dir(variable, fallback):
    return Path(os.environ.get(variable) or Path.home() / fallback) / "mibuki-metrics"


CONFIG_DIR = local_dir("XDG_CONFIG_HOME", ".config")
DATA_DIR = local_dir("XDG_DATA_HOME", ".local/share")
STATE_DIR = local_dir("XDG_STATE_HOME", ".local/state")


def read_json(path, default=None):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def private_dir(path):
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)


def atomic_write(path, content):
    private_dir(path.parent)
    fd, name = tempfile.mkstemp(prefix=".metrics-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(content)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def validate_config(config):
    if not isinstance(config, dict) or not isinstance(config.get("services"), list) or not config["services"]:
        raise MetricsError("invalid_config")
    ids = set()
    for service in config["services"]:
        if not isinstance(service, dict):
            raise MetricsError("invalid_service")
        service_id = service.get("id", "")
        if not isinstance(service_id, str) or not re.fullmatch(r"[a-z0-9-]{1,40}", service_id) or service_id in ids:
            raise MetricsError("invalid_service_id")
        ids.add(service_id)
        name = service.get("name", service_id)
        if not isinstance(name, str) or not re.fullmatch(r"[ -~]{1,24}", name):
            raise MetricsError("invalid_service_name")
        try:
            price = Decimal(str(service["monthly_price_usd"]))
            if not price.is_finite() or not 0 <= price <= 100000:
                raise ValueError
            ZoneInfo(service["reporting_timezone"])
        except (KeyError, ValueError, InvalidOperation):
            raise MetricsError("invalid_price_or_timezone") from None
        except Exception:
            raise MetricsError("invalid_timezone") from None
        settings = service.get("analytics", {})
        if not isinstance(settings, dict):
            raise MetricsError("invalid_analytics_config")
        if settings.get("source", "bigquery") == "ga4":
            if not re.fullmatch(r"\d+", str(settings.get("property_id", ""))):
                raise MetricsError("missing_analytics_property")
        elif settings.get("source", "bigquery") == "bigquery":
            if (not re.fullmatch(r"[a-z][a-z0-9-]{4,62}", str(settings.get("project_id", "")))
                    or not re.fullmatch(r"[A-Za-z0-9_]+", str(settings.get("dataset_id", "")))):
                raise MetricsError("missing_bigquery_config")
        else:
            raise MetricsError("invalid_analytics_source")
        if not isinstance(service.get("revenuecat", {}), dict):
            raise MetricsError("invalid_revenuecat_config")
    return config


def command_output(argv):
    if not isinstance(argv, list) or not argv or not all(isinstance(x, str) for x in argv):
        raise MetricsError("invalid_auth_command")
    try:
        result = subprocess.run(argv, stdin=subprocess.DEVNULL, capture_output=True,
                                text=True, timeout=30, check=True)
    except (OSError, subprocess.SubprocessError):
        raise MetricsError("google_auth_unavailable") from None
    token = result.stdout.strip()
    if not token or "\n" in token:
        raise MetricsError("invalid_google_token")
    return token


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise MetricsError("unexpected_redirect")


def request_json(url, token, body=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(url, data=data, headers={
        "Authorization": "Bearer " + token, "Content-Type": "application/json",
    })
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=25) as response:
            result = json.load(response)
        if not isinstance(result, dict):
            raise MetricsError("invalid_api_response")
        return result
    except urllib.error.HTTPError as error:
        # Responses and command stderr may contain private details; do not log them.
        raise MetricsError("http_" + str(error.code)) from None
    except (urllib.error.URLError, TimeoutError, OSError):
        raise MetricsError("network_unavailable") from None
    except ValueError:
        raise MetricsError("invalid_api_response") from None


def count_value(value):
    try:
        number = Decimal(str(value))
        if (isinstance(value, bool) or not number.is_finite() or not 0 <= number < 10**15
                or number != number.to_integral_value()):
            raise ValueError
    except (ValueError, InvalidOperation):
        raise MetricsError("invalid_count")
    return int(number)


def cached_snapshot():
    raw = read_json(DATA_DIR / "snapshot.json", {})
    snapshot = {"version": 1, "services": {}}
    if not isinstance(raw, dict) or not isinstance(raw.get("services"), dict):
        return snapshot
    for service_id, service in raw["services"].items():
        if not isinstance(service, dict):
            continue
        clean = snapshot["services"].setdefault(service_id, {})
        for metric_name in ("dau", "subscribers"):
            try:
                metric = service[metric_name]
                count = count_value(metric["value"])
                refreshed_on = datetime.strptime(metric["refreshed_on"], "%Y-%m-%d").date().isoformat()
                updated_at = datetime.fromisoformat(metric["updated_at"])
                if updated_at.tzinfo is None:
                    continue
                clean[metric_name] = {"value": count, "refreshed_on": refreshed_on,
                                      "updated_at": updated_at.isoformat(timespec="seconds")}
                if metric_name == "dau":
                    clean[metric_name]["date"] = datetime.strptime(metric["date"], "%Y-%m-%d").date().isoformat()
            except (KeyError, TypeError, ValueError, MetricsError):
                clean.pop(metric_name, None)
    return snapshot


def fetch_dau(service, token, report_date):
    settings = service.get("analytics", {})
    source = settings.get("source", "bigquery")
    if source == "ga4":
        property_id = str(settings.get("property_id", ""))
        if not re.fullmatch(r"\d+", property_id):
            raise MetricsError("missing_analytics_property")
        report = request_json(
            "https://analyticsdata.googleapis.com/v1beta/properties/" + property_id + ":runReport",
            token, {"dateRanges": [{"startDate": report_date, "endDate": report_date}],
                    "metrics": [{"name": "activeUsers"}]})
        if "metricHeaders" not in report:
            raise MetricsError("invalid_analytics_response")
        rows = report.get("rows", [])
        try:
            return count_value(rows[0]["metricValues"][0]["value"]) if rows else 0
        except (KeyError, IndexError, TypeError):
            raise MetricsError("invalid_analytics_response") from None
    if source != "bigquery":
        raise MetricsError("invalid_analytics_source")
    project = settings.get("project_id", "")
    dataset = settings.get("dataset_id", "")
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,62}", project) or not re.fullmatch(r"[A-Za-z0-9_]+", dataset):
        raise MetricsError("missing_bigquery_config")
    table_date = report_date.replace("-", "")
    # Use the daily export's active-user flag, not a count of background events.
    # A missing export raises HTTP 404 instead of inventing a zero.
    query = ("SELECT COUNT(DISTINCT IF(is_active_user, user_pseudo_id, NULL)) AS dau "
             f"FROM `{project}.{dataset}.events_{table_date}`")
    base = "https://bigquery.googleapis.com/bigquery/v2/projects/" + project
    result = request_json(base + "/queries", token, {
        "query": query, "useLegacySql": False, "location": settings.get("location", "US"),
        "maximumBytesBilled": str(settings.get("maximum_bytes_billed", 10485760)),
        "timeoutMs": 10000, "maxResults": 1,
    })
    deadline = time.monotonic() + 45
    while not result.get("jobComplete"):
        if time.monotonic() >= deadline:
            raise MetricsError("bigquery_timeout")
        try:
            job = result["jobReference"]
            url = base + "/queries/" + urllib.parse.quote(job["jobId"], safe="")
            url += "?" + urllib.parse.urlencode({"location": job.get("location", "US"), "timeoutMs": 10000})
        except (KeyError, TypeError):
            raise MetricsError("invalid_bigquery_response") from None
        result = request_json(url, token)
    if result.get("errors"):
        raise MetricsError("bigquery_query_failed")
    try:
        return count_value(result["rows"][0]["f"][0]["v"])
    except (KeyError, IndexError, TypeError):
        raise MetricsError("invalid_bigquery_response") from None


def fetch_subscribers(service):
    settings = service.get("revenuecat", {})
    project_id = settings.get("project_id", "")
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", project_id):
        raise MetricsError("missing_revenuecat_config")
    key = os.environ.get(settings.get("api_key_env", "REVENUECAT_API_KEY"), "").strip()
    if not key:
        try:
            key = Path(settings["api_key_file"]).expanduser().read_text().strip()
        except (KeyError, OSError, TypeError):
            raise MetricsError("missing_revenuecat_key") from None
    if not key or "\n" in key:
        raise MetricsError("invalid_revenuecat_key")
    result = request_json("https://api.revenuecat.com/v2/projects/" + project_id
                          + "/metrics/overview?currency=USD", key)
    for metric in result.get("metrics", []):
        if metric.get("id") == "active_subscriptions":
            return count_value(metric.get("value"))
    raise MetricsError("missing_subscriber_metric")


def render_panel(config, snapshot, now=None):
    lines = []
    for service in config["services"]:
        if lines:
            lines.append("")
        current = snapshot.get("services", {}).get(service["id"], {})
        now_local = (now or datetime.now().astimezone()).astimezone(ZoneInfo(service["reporting_timezone"]))
        today = now_local.date().isoformat()
        yesterday = (now_local.date() - timedelta(days=1)).isoformat()
        dau = current.get("dau", {})
        subscribers = current.get("subscribers", {})
        dau_value = f'{dau["value"]:,}' if "value" in dau else "--"
        sub_value = f'{subscribers["value"]:,}' if "value" in subscribers else "--"
        date_label = dau.get("date", yesterday)[5:].replace("-", "/")
        dau_cached = " cached" if "value" in dau and dau.get("date") != yesterday else ""
        sub_cached = " cached" if "value" in subscribers and subscribers.get("refreshed_on") != today else ""
        price = Decimal(str(service["monthly_price_usd"]))
        revenue = f'${subscribers["value"] * price:,.2f}' if "value" in subscribers else "--"
        lines.extend([
            service.get("name", service["id"]),
            f"DAU ({date_label})   {dau_value}{dau_cached}",
            f"Subscribers   {sub_value}{sub_cached}",
            f"Est. / month  {revenue}{sub_cached}",
        ])
        updated = [m["updated_at"] for m in (dau, subscribers) if "updated_at" in m]
        if updated:
            stamp = datetime.fromisoformat(max(updated)).astimezone(ZoneInfo(service["reporting_timezone"]))
            lines.append("Updated " + stamp.strftime("%m/%d %H:%M"))
        else:
            lines.append("Awaiting first update")
    return "\n".join(lines) + "\n"


def log_result(message):
    private_dir(STATE_DIR)
    path = STATE_DIR / "refresh.log"
    if path.exists() and path.stat().st_size > 1024 * 1024:
        os.replace(path, STATE_DIR / "refresh.log.1")
    with path.open("a") as output:
        output.write(datetime.now().astimezone().isoformat(timespec="seconds") + " " + message + "\n")
    path.chmod(0o600)


def refresh(config, force=False):
    private_dir(DATA_DIR)
    with (DATA_DIR / "refresh.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0
        snapshot = cached_snapshot()
        services = snapshot["services"]
        token = None
        token_error = None
        statuses = []
        failed = False
        for service in config["services"]:
            today = datetime.now(ZoneInfo(service["reporting_timezone"])).date()
            yesterday = (today - timedelta(days=1)).isoformat()
            current = services.setdefault(service["id"], {})
            for metric_name in ("dau", "subscribers"):
                previous = current.get(metric_name, {})
                if not force and previous.get("refreshed_on") == today.isoformat():
                    continue
                try:
                    if metric_name == "dau":
                        if token_error:
                            raise MetricsError(token_error)
                        if token is None:
                            try:
                                token = command_output(config.get("google_token_command", ["gcloud", "auth", "print-access-token"]))
                            except MetricsError as error:
                                token_error = str(error)
                                raise
                        value = fetch_dau(service, token, yesterday)
                    else:
                        value = fetch_subscribers(service)
                    current[metric_name] = {
                        "value": value, "refreshed_on": today.isoformat(),
                        "updated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
                    }
                    if metric_name == "dau":
                        current[metric_name]["date"] = yesterday
                    statuses.append(service["id"] + ":" + metric_name + "=ok")
                except MetricsError as error:
                    # Keep the last successful value and retry on the next launchd tick.
                    previous["error"] = str(error)
                    current[metric_name] = previous
                    statuses.append(service["id"] + ":" + metric_name + "=" + str(error))
                    failed = True
        if statuses or not (DATA_DIR / "panel.txt").exists():
            atomic_write(DATA_DIR / "snapshot.json", json.dumps(snapshot, indent=2) + "\n")
            atomic_write(DATA_DIR / "panel.txt", render_panel(config, snapshot))
        if statuses:
            log_result(" ".join(statuses))
        return 1 if failed else 0


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="refresh even after today's successful update")
    parser.add_argument("--validate-config", action="store_true")
    parser.add_argument("--render", action="store_true", help="render cached data without making API calls")
    args = parser.parse_args()
    # The local marker is the opt-in gate for fetching and displaying personal data.
    if not args.validate_config and not (CONFIG_DIR / "enabled").is_file():
        return 0
    try:
        config = validate_config(read_json(CONFIG_DIR / "config.json"))
        if args.validate_config:
            return 0
        if args.render:
            print(render_panel(config, cached_snapshot()), end="")
            return 0
        return refresh(config, args.force)
    except MetricsError as error:
        print("mibuki-metrics: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
