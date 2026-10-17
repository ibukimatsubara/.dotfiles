#!/usr/bin/env python3
"""Add desktop widgets once, preserving subsequent user customizations."""
import json
import os
from pathlib import Path
import tempfile

config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
plugins = ("dotfilesBreakTimer", "dotfilesCodexUsage")

def save(path, data):
    if path.is_symlink():
        raise ValueError("Mutable preferences cannot be symlinks: " + str(path))
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        json.dump(data, stream, indent=2)
        stream.write("\n")
        temporary = Path(stream.name)
    os.replace(temporary, path)

path = config / "DankMaterialShell/plugin_settings.json"
settings = json.loads(path.read_text()) if path.exists() else {}
bar_path = config / "DankMaterialShell/settings.json"
bar = json.loads(bar_path.read_text())
changed = False
for name in plugins:
    if name in settings:
        continue
    settings[name] = {"enabled": True}
    changed = True
    bars = bar.get("barConfigs", [])
    if bars:
        widgets = bars[0].setdefault("rightWidgets", [])
        ids = [item.get("id") if isinstance(item, dict) else item for item in widgets]
        existing = [item.get("id") if isinstance(item, dict) else item
                    for section in ("leftWidgets", "centerWidgets", "rightWidgets")
                    for item in bars[0].get(section, [])]
        if name not in existing:
            widgets.insert(ids.index("clock") if "clock" in ids else len(widgets), name)
if changed:
    save(bar_path, bar)
    save(path, settings)
