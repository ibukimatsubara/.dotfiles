#!/usr/bin/env python3
"""Render desktop presets without rewriting shared application configuration."""

import argparse
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import struct
import tempfile
from urllib.request import Request, urlopen
import uuid
import zlib

ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
THEMES = Path(os.environ.get("DESKTOP_THEME_DIR", ROOT / "desktop-themes"))
STATE = HOME / ".config/desktop-theme"
WALLPAPERS = HOME / "Pictures/Wallpapers/themes"
STYLE_KEYS = {
    "BAR_HEIGHT", "MODULE_HEIGHT", "INNER_HEIGHT", "ARTWORK_SIZE",
    "RADIUS_LARGE", "RADIUS_MEDIUM", "RADIUS_SMALL", "BLUR_RADIUS",
    "BAR_MARGIN", "BAR_Y_OFFSET",
    "BAR_ATTACHED", "BAR_INVERSE_RADIUS", "BAR_SECTIONS", "BAR_SHOW_BRAND",
    "SCREEN_BOTTOM_RADIUS", "SCREEN_BORDER_WIDTH",
}


def load_preset(name):
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
        raise ValueError("Invalid theme name")
    path = THEMES / name / "theme.json"
    if not path.is_file():
        raise ValueError("Unknown theme: " + name)
    data = json.loads(path.read_text())
    for key in ("label", "description"):
        if not isinstance(data[key], str) or any(c in data[key] for c in "\n\r\t"):
            raise ValueError("Invalid theme " + key)
    for key, value in data["colors"].items():
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", key) or not re.fullmatch(r"0x[0-9a-fA-F]{8}", str(value)):
            raise ValueError("Invalid bar color: " + key)
    for key, value in data["style"].items():
        if key not in STYLE_KEYS or type(value) is not int or not 0 <= value <= 100:
            raise ValueError("Invalid bar dimension: " + key)
    for flag in ("BAR_ATTACHED", "BAR_SECTIONS", "BAR_SHOW_BRAND"):
        if data["style"].get(flag, 0) not in (0, 1):
            raise ValueError(flag + " must be 0 or 1")
    ghostty = data["ghostty"]
    for key, value in ghostty.items():
        if key == "theme":
            valid = isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9 _-]+", value)
        elif key in {"foreground", "background", "cursor-color", "selection-background", "selection-foreground"}:
            valid = isinstance(value, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", value)
        elif key == "background-opacity":
            valid = type(value) in (int, float) and 0 <= value <= 1
        elif key == "background-blur":
            valid = type(value) is bool or (type(value) is int and 0 <= value <= 100)
        else:
            valid = False
        if not valid:
            raise ValueError("Invalid Ghostty option: " + key)
    if type(data["rotation_seconds"]) is not int or data["rotation_seconds"] < 60:
        raise ValueError("Wallpaper rotation must be at least 60 seconds")
    if not data["wallpapers"]:
        raise ValueError("A theme needs at least one wallpaper")
    seen = set()
    ids = set()
    for image in data["wallpapers"]:
        filename = image["filename"]
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*\.(png|jpg|jpeg)", filename) or filename in seen:
            raise ValueError("Invalid or duplicate wallpaper filename")
        seen.add(filename)
        if not re.fullmatch(r"[a-z0-9-]+", image["id"]):
            raise ValueError("Invalid wallpaper id")
        if image["id"] in ids:
            raise ValueError("Duplicate wallpaper id: " + image["id"])
        ids.add(image["id"])
        if not re.fullmatch(r"[0-9a-f]{64}", image["sha256"]):
            raise ValueError("Invalid wallpaper SHA-256")
        if not image["url"].startswith("https://"):
            raise ValueError("Wallpaper URLs must use HTTPS")
        for candidate in image.get("local_candidates", []):
            if Path(candidate).is_absolute() or ".." in Path(candidate).parts:
                raise ValueError("Wallpaper cache candidates must be home-relative")
    data["name"] = name
    return data


def presets():
    return [load_preset(p.parent.name) for p in sorted(THEMES.glob("*/theme.json"))]


def current_name():
    path = STATE / "current/theme.json"
    return json.loads(path.read_text())["name"] if path.is_file() else "none"


def verified(path, expected):
    if not path.is_file():
        return False
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest() == expected


def prepare_wallpaper(name, image, offline):
    destination = WALLPAPERS / name / image["filename"]
    if verified(destination, image["sha256"]):
        return destination
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as output:
        temporary = Path(output.name)
        try:
            candidate = next((HOME / p for p in image.get("local_candidates", [])
                              if verified(HOME / p, image["sha256"])), None)
            if candidate:
                with candidate.open("rb") as source:
                    shutil.copyfileobj(source, output)
            elif offline:
                raise ValueError("Verified wallpaper is not cached: " + image["id"])
            else:
                print("Downloading wallpaper: " + image["id"], file=sys.stderr)
                request = Request(image["url"], headers={"User-Agent": "dotfiles-desktop-theme/1.0"})
                with urlopen(request, timeout=30) as response:
                    shutil.copyfileobj(response, output)
            output.close()
            if not verified(temporary, image["sha256"]):
                raise ValueError("Wallpaper checksum mismatch: " + image["id"])
            os.replace(temporary, destination)
        finally:
            temporary.unlink(missing_ok=True)
    return destination


def render_bar_flares(data, directory):
    style = data["style"]
    radius = style.get("BAR_INVERSE_RADIUS", 0)
    if not style.get("BAR_ATTACHED") or not style.get("BAR_SECTIONS") or not radius:
        return
    # Four pixels per point, with sRGB metadata and a one-pixel antialiased edge.
    size = radius * 4
    inner = min(radius, style.get("RADIUS_LARGE", 0)) * 4
    argb = bytes.fromhex(data["colors"]["BAR_COLOR"][2:])
    rows = []
    for y in range(size):
        row = []
        for x in range(size * 2):
            if x >= size:
                distance = math.hypot(2 * size - x - .5, size - y - .5) - size
            elif inner and x >= size - inner and y < inner:
                # Fill only the bracket's top corner cutout; leave text untouched.
                distance = math.hypot(x + .5 - (size - inner), inner - y - .5) - inner
            else:
                distance = -1
            coverage = max(0, min(1, distance + .5))
            row.append(argb[1:] + bytes([round(argb[0] * coverage)]))
        rows.append(row)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    for side in ("left", "right"):
        pixels = b"".join(b"\0" + b"".join(row if side == "right" else reversed(row)) for row in rows)
        png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size * 2, size, 8, 6, 0, 0, 0))
               + chunk(b"sRGB", b"\0") + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))
        (directory / ("bar-flare-" + side + ".png")).write_bytes(png)


def render_theme(data, directory):
    ghostty = []
    for key, value in data["ghostty"].items():
        if type(value) is bool:
            value = str(value).lower()
        ghostty.append("{} = {}\n".format(key, value))
    (directory / "ghostty.conf").write_text("".join(ghostty))
    for field, filename in [("colors", "sketchybar-colors.sh"), ("style", "sketchybar-style.sh")]:
        body = "".join("export {}={}\n".format(k, v) for k, v in data[field].items())
        (directory / filename).write_text(body)
    (directory / "theme.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    render_bar_flares(data, directory)


def activate(name, offline=False):
    data = load_preset(name)
    # Download and verify every image before publishing any application settings.
    for image in data["wallpapers"]:
        image["path"] = str(prepare_wallpaper(name, image, offline))
    generations = STATE / "generations"
    generations.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix=name + "-", dir=generations))
    link = STATE / (".current-" + uuid.uuid4().hex)
    try:
        render_theme(data, directory)
        link.symlink_to(directory.relative_to(STATE), target_is_directory=True)
        os.replace(link, STATE / "current")
    except Exception:
        link.unlink(missing_ok=True)
        shutil.rmtree(directory)
        raise


def executable(name):
    return shutil.which(name) or next((str(p) for p in
        [Path("/opt/homebrew/bin") / name, Path("/usr/local/bin") / name]
        if p.is_file() and os.access(p, os.X_OK)), None)


def hammerspoon(expression):
    hs = executable("hs")
    if not hs:
        return False
    result = subprocess.run([hs, "-c", expression], text=True, capture_output=True, timeout=15)
    return result.returncode == 0 and result.stdout.strip().endswith("true")


def reload_apps():
    if not hammerspoon("return desktoptheme and desktoptheme.refresh() or false"):
        bar = executable("sketchybar")
        if bar:
            subprocess.run([bar, "--reload"], capture_output=True, timeout=10)
        print("Theme saved. Reload Hammerspoon to enable live Ghostty/wallpaper updates.", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", default="pick",
                        choices=["list", "current", "apply", "next", "pick", "wallpaper"])
    parser.add_argument("name", nargs="?")
    parser.add_argument("--json", action="store_true", help="List picker metadata as JSON")
    parser.add_argument("--no-reload", action="store_true", help="Only publish configuration")
    parser.add_argument("--offline", action="store_true", help="Use verified local wallpapers only")
    args = parser.parse_args()
    if args.action == "current":
        print(current_name())
        return
    if args.action == "list":
        entries = [{k: data[k] for k in ("name", "label", "description")} for data in presets()]
        if args.json:
            print(json.dumps(entries, ensure_ascii=False))
        else:
            for entry in entries:
                print("{name}\t{label}\t{description}".format(**entry))
        return
    if args.action == "wallpaper":
        if not hammerspoon("return wallpaper and wallpaper.next() or false"):
            raise ValueError("Hammerspoon could not change the wallpaper")
        return
    if args.action == "pick":
        fzf = executable("fzf")
        if not fzf:
            raise ValueError("Use Ctrl+Option+Cmd+T, or install fzf for the terminal picker")
        entries = presets()
        selection = subprocess.run([fzf, "--prompt=Theme > ", "--height=40%", "--reverse",
                                    "--delimiter=\t", "--with-nth=2.."], text=True,
                                   input="".join("{}\t{} — {}\n".format(p["name"], p["label"], p["description"])
                                                 for p in entries), stdout=subprocess.PIPE)
        if selection.returncode in (1, 130):
            return
        if selection.returncode:
            raise ValueError("Theme picker failed")
        args.name = selection.stdout.split("\t")[0]
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / ".lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.action == "next":
            names = [p["name"] for p in presets()]
            if not names:
                raise ValueError("No desktop themes found")
            old = current_name()
            args.name = names[(names.index(old) + 1) % len(names)] if old in names else names[0]
        if not args.name:
            raise ValueError("Use: desktop-theme apply NAME")
        activate(args.name, args.offline)
        if not args.no_reload:
            reload_apps()
    print("Theme: " + args.name)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print("desktop-theme: " + str(error), file=sys.stderr)
        sys.exit(1)
