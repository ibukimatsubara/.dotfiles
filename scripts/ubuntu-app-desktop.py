#!/usr/bin/env python3
"""Preserve installed desktop entries while sharing native Hyprland app startup."""
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
applications = DATA / "applications"
applications.mkdir(parents=True, exist_ok=True)
search = [applications] + [Path(p) / "applications" for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")]
for ident, app in [("com.mitchellh.ghostty", "ghostty"), ("google-chrome", "chrome"), ("code", "vscode")]:
    target = applications / (ident + ".desktop")
    source = next((directory / target.name for directory in search if (directory / target.name).is_file()), None)
    if source is None:
        continue
    content = source.read_text()
    if "X-Dotfiles-Wayland=true" in content:
        continue
    lines = []
    supported = True
    allowed = {"ghostty": {"ghostty"}, "chrome": {"google-chrome", "google-chrome-stable"}, "vscode": {"code"}}[app]
    for line in content.splitlines():
        if line.startswith("Exec="):
            match = re.match(r'Exec=("[^"\n]+"|[^\s]+)(.*)', line)
            if match is None:
                raise ValueError("Unsupported Exec entry in " + str(source))
            if Path(match.group(1).strip('"')).name not in allowed:
                supported = False
                break
            rest = match.group(2)
            launcher = str(ROOT / "scripts/ubuntu-app-launch.sh").replace("%", "%%")
            line = 'Exec="' + launcher + '" ' + app + rest
        if line.startswith("DBusActivatable="):
            line = "DBusActivatable=false"
        lines.append(line)
    if not supported:
        print("Preserving custom desktop command: " + str(source), file=sys.stderr)
        continue
    if target.exists():
        backup = target.with_suffix(".desktop.before-dotfiles-wayland")
        if not backup.exists():
            shutil.copy2(target, backup)
    lines.append("X-Dotfiles-Wayland=true")
    with tempfile.NamedTemporaryFile(mode="w", dir=applications, delete=False) as stream:
        stream.write("\n".join(lines) + "\n")
        temporary = Path(stream.name)
    temporary.chmod(0o644)
    os.replace(temporary, target)
