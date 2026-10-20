#!/usr/bin/env python3
"""Exercise the callback against fake CLI/API commands without moving windows."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('aerospace-autotile.sh')


class AutotileTest(unittest.TestCase):
    def run_helper(self, layout='h_tiles', fullscreen='false', direction='horizontal', stale=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'aerospace').write_text('''#!/bin/bash
case "$1" in
list-windows)
    if [[ "$*" == *window-layout* ]]; then
        echo "42|$LAYOUT|$FULLSCREEN"
    elif [[ "$STALE" == yes ]]; then echo 99
    else echo 42; fi ;;
split) printf '%s\\n' "$*" >> "$CALL_LOG" ;;
esac
''')
            (root / 'osascript').write_text('#!/bin/bash\nprintf "%s\\n" "$DIRECTION"\n')
            for name in ('aerospace', 'osascript'):
                (root / name).chmod(0o755)
            log = root / 'calls'
            env = dict(os.environ, PATH=f'{root}:/usr/bin:/bin', LAYOUT=layout,
                       FULLSCREEN=fullscreen, DIRECTION=direction,
                       STALE='yes' if stale else 'no', CALL_LOG=str(log))
            result = subprocess.run(['/bin/bash', str(SCRIPT)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return log.read_text() if log.exists() else ''

    def test_wide_window_splits_horizontally(self):
        self.assertEqual(self.run_helper(), 'split --window-id 42 horizontal\n')

    def test_tall_window_splits_vertically(self):
        self.assertEqual(self.run_helper(direction='vertical'), 'split --window-id 42 vertical\n')

    def test_floating_and_fullscreen_are_untouched(self):
        self.assertEqual(self.run_helper(layout='floating'), '')
        self.assertEqual(self.run_helper(fullscreen='true'), '')

    def test_focus_change_discards_stale_geometry(self):
        self.assertEqual(self.run_helper(stale=True), '')

    def test_missing_geometry_is_ignored(self):
        self.assertEqual(self.run_helper(direction=''), '')


if __name__ == '__main__':
    unittest.main()
