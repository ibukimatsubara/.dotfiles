#!/usr/bin/env python3
"""Exercise real theme generation in an isolated home without desktop side effects."""

import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from urllib.error import HTTPError

SCRIPT = Path(__file__).with_name("desktop-theme.py")


class DesktopThemeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="desktop theme test ")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.themes = self.home / "presets"
        self.state = self.home / ".config/desktop-theme"
        self.env = dict(os.environ, HOME=str(self.home),
                        DESKTOP_THEME_DIR=str(self.themes))
        # The test never fetches an image: both presets have a verified cache.
        for name, color in [("alpha", "0xff123456"), ("beta", "0xffabcdef")]:
            cache = self.home / "Pictures/Wallpapers/themes" / name
            cache.mkdir(parents=True)
            image = b"wallpaper fixture"
            (cache / "coast.png").write_bytes(image)
            preset = {
                "label": name.title(), "description": "Test preset",
                "ghostty": {"theme": "GitHub Dark", "foreground": "#e6e6e6",
                            "background-opacity": 0.94, "background-blur": False},
                "colors": {"TEXT_COLOR": color}, "style": {"BAR_HEIGHT": 40},
                "rotation_seconds": 3600,
                "wallpapers": [{"id": "coast", "filename": "coast.png",
                                "url": "https://invalid.example/coast.png",
                                "source": "https://example.com/artist",
                                "sha256": hashlib.sha256(image).hexdigest()}],
            }
            folder = self.themes / name
            folder.mkdir(parents=True)
            (folder / "theme.json").write_text(json.dumps(preset))

    def run_cli(self, *args, success=True):
        result = subprocess.run([sys.executable, str(SCRIPT), *args, "--no-reload"],
                                env=self.env, text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_apply_generates_consumable_files_and_preserves_shared_config(self):
        shared = self.home / ".config/ghostty/config"
        shared.parent.mkdir(parents=True)
        shared.write_text("keybind = super+v=paste_from_clipboard\n")
        self.run_cli("apply", "alpha")
        current = self.state / "current"
        self.assertTrue(current.is_symlink())
        config = json.loads((current / "theme.json").read_text())
        self.assertEqual(config["name"], "alpha")
        self.assertEqual(config["wallpapers"][0]["path"],
                         str(self.home / "Pictures/Wallpapers/themes/alpha/coast.png"))
        self.assertIn("background-opacity = 0.94\n", (current / "ghostty.conf").read_text())
        result = subprocess.run(["/bin/sh", "-c",
                                 '. "$1"; . "$2"; echo "$TEXT_COLOR $BAR_HEIGHT"',
                                 "sh", str(current / "sketchybar-colors.sh"),
                                 str(current / "sketchybar-style.sh")],
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), "0xff123456 40")
        self.assertEqual(shared.read_text(), "keybind = super+v=paste_from_clipboard\n")

    def test_next_wraps_and_current_survives_separate_processes(self):
        self.run_cli("apply", "beta")
        self.run_cli("next")
        self.assertEqual(self.run_cli("current").stdout.strip(), "alpha")
        self.run_cli("next")
        self.assertEqual(self.run_cli("current").stdout.strip(), "beta")

    def test_invalid_name_and_injected_values_do_not_replace_current(self):
        self.run_cli("apply", "alpha")
        before = (self.state / "current").resolve()
        self.run_cli("apply", "../alpha", success=False)
        preset = self.themes / "beta/theme.json"
        data = json.loads(preset.read_text())
        data["colors"]["TEXT_COLOR"] = '$(touch /tmp/desktop-theme-unsafe)'
        preset.write_text(json.dumps(data))
        self.run_cli("apply", "beta", success=False)
        self.assertEqual((self.state / "current").resolve(), before)

    def test_corrupt_cache_is_rejected_without_publishing(self):
        self.run_cli("apply", "alpha")
        before = (self.state / "current").resolve()
        (self.home / "Pictures/Wallpapers/themes/beta/coast.png").write_bytes(b"corrupt")
        result = self.run_cli("apply", "beta", "--offline", success=False)
        self.assertIn("wallpaper", result.stderr.lower())
        self.assertEqual((self.state / "current").resolve(), before)

    def test_missing_wallpaper_does_not_publish_partial_theme(self):
        self.run_cli("apply", "alpha")
        before = (self.state / "current").resolve()
        (self.home / "Pictures/Wallpapers/themes/beta/coast.png").unlink()
        self.run_cli("apply", "beta", "--offline", success=False)
        self.assertEqual((self.state / "current").resolve(), before)

    def test_connection_failure_keeps_current_and_removes_partial_download(self):
        self.run_cli("apply", "alpha")
        before = (self.state / "current").resolve()
        cache = self.home / "Pictures/Wallpapers/themes/beta"
        (cache / "coast.png").unlink()
        preset = self.themes / "beta/theme.json"
        data = json.loads(preset.read_text())
        data["wallpapers"][0]["url"] = "https://127.0.0.1:1/coast.png"
        preset.write_text(json.dumps(data))
        self.run_cli("apply", "beta", success=False)
        self.assertEqual((self.state / "current").resolve(), before)
        self.assertEqual(list(cache.iterdir()), [])

    def test_duplicate_wallpaper_ids_are_rejected(self):
        preset = self.themes / "beta/theme.json"
        data = json.loads(preset.read_text())
        duplicate = dict(data["wallpapers"][0], filename="other.png")
        data["wallpapers"].append(duplicate)
        preset.write_text(json.dumps(data))
        result = self.run_cli("apply", "beta", "--offline", success=False)
        self.assertIn("duplicate wallpaper id", result.stderr.lower())

    def test_download_uses_identified_client_and_checks_received_content(self):
        spec = importlib.util.spec_from_file_location("desktop_theme", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.WALLPAPERS = self.home / "downloaded"
        image = json.loads((self.themes / "beta/theme.json").read_text())["wallpapers"][0]

        # Pexels rejects urllib's default Python User-Agent with HTTP 403.
        def image_server(request, timeout):
            if isinstance(request, str) or not request.get_header("User-agent"):
                raise HTTPError(image["url"], 403, "Unidentified client", {}, None)
            return io.BytesIO(b"wallpaper fixture")

        with mock.patch.object(module, "urlopen", side_effect=image_server):
            downloaded = module.prepare_wallpaper("beta", image, False)
        self.assertEqual(downloaded.read_bytes(), b"wallpaper fixture")
        downloaded.unlink()
        with mock.patch.object(module, "urlopen", return_value=io.BytesIO(b"wrong content")):
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                module.prepare_wallpaper("beta", image, False)
        self.assertFalse(downloaded.exists())
        self.assertEqual(list(downloaded.parent.iterdir()), [])

    def test_list_is_read_only_and_supports_picker_metadata(self):
        entries = json.loads(self.run_cli("list", "--json").stdout)
        self.assertEqual([entry["name"] for entry in entries], ["alpha", "beta"])
        self.assertFalse(self.state.exists())


if __name__ == "__main__":
    unittest.main()
