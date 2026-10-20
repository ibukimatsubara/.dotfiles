#!/usr/bin/env python3
"""Verify image shortcuts reach terminal CLIs without changing ordinary paste."""
import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class PasteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.env = dict(os.environ, PATH=str(self.base) + ':' + os.environ['PATH'],
                        PASTE_WINDOW=json.dumps({'class': 'com.mitchellh.ghostty'}),
                        PASTE_TYPES='image/png\n', PASTE_CLIPBOARD_EXIT='0',
                        PASTE_LOG=str(self.base / 'calls'),
                        PASTE_STATE=str(self.base / 'clipboard.json'),
                        PASTE_CAPTURE=str(self.base / 'capture.json'), TMPDIR=str(self.base))
        self.png = b'\x89PNG\r\n\x1a\nclipboard-image-fixture'
        (self.base / 'clipboard.json').write_text(json.dumps({
            'mime': 'image/png', 'data': base64.b64encode(self.png).decode()}))
        self.stub('hyprctl', '''#!/usr/bin/env python3
import base64,json,os,sys
from pathlib import Path
if sys.argv[1:]==['-j','activewindow']:print(os.environ['PASTE_WINDOW'])
else:
 with open(os.environ['PASTE_LOG'],'a') as f:f.write(json.dumps(sys.argv[1:])+'\\n')
 if 'SHIFT,Insert,' in sys.argv:
  state=json.loads(Path(os.environ['PASTE_STATE']).read_text())
  assert state['mime']=='text/plain'
  path=base64.b64decode(state['data']).decode()
  Path(os.environ['PASTE_CAPTURE']).write_text(json.dumps({'path':path,'image':Path(path).read_bytes().hex()}))
  if os.environ.get('PASTE_EXTERNAL_COPY'):
   Path(os.environ['PASTE_STATE']).write_text(json.dumps({'mime':'text/plain','data':base64.b64encode(b'new-user-copy').decode()}))
''')
        self.stub('wl-paste', '''#!/usr/bin/env python3
import base64,json,os,sys
from pathlib import Path
if os.environ['PASTE_CLIPBOARD_EXIT']!='0':sys.exit(int(os.environ['PASTE_CLIPBOARD_EXIT']))
state=json.loads(Path(os.environ['PASTE_STATE']).read_text())
if sys.argv[1:]==['--list-types']:
 print(os.environ['PASTE_TYPES'] if state['mime']=='image/png' else state['mime'])
elif len(sys.argv)==3 and sys.argv[1]=='--type' and sys.argv[2]==state['mime']:
 sys.stdout.buffer.write(base64.b64decode(state['data']))
else:sys.exit(1)
''')
        self.stub('wl-copy', '''#!/usr/bin/env python3
import base64,json,os,subprocess,sys
from pathlib import Path
assert len(sys.argv)==3 and sys.argv[1]=='--type'
Path(os.environ['PASTE_STATE']).write_text(json.dumps({'mime':sys.argv[2],'data':base64.b64encode(sys.stdin.buffer.read()).decode()}))
if os.environ.get('PASTE_COPY_FORK'):
 subprocess.Popen([sys.executable,'-c','import time; time.sleep(4)'],start_new_session=True)
''')

    def stub(self, name, source):
        path = self.base / name
        path.write_text(source)
        path.chmod(0o755)

    def run_paste(self):
        result = subprocess.run(['python3', str(ROOT / 'scripts/hyprland-paste.py')],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return [json.loads(line) for line in (self.base / 'calls').read_text().splitlines()]

    def test_image_in_ghostty_pastes_valid_file_path_and_restores_image(self):
        self.assertEqual(self.run_paste(), [['dispatch', 'sendshortcut', 'SHIFT,Insert,']])
        captured=json.loads((self.base / 'capture.json').read_text())
        self.assertEqual(bytes.fromhex(captured['image']), self.png)
        self.assertTrue(Path(captured['path']).is_file())
        state=json.loads((self.base / 'clipboard.json').read_text())
        self.assertEqual(state['mime'], 'image/png')
        self.assertEqual(base64.b64decode(state['data']), self.png)

    def test_new_user_copy_during_paste_is_not_overwritten(self):
        self.env['PASTE_EXTERNAL_COPY']='1'
        self.assertEqual(self.run_paste(), [['dispatch', 'sendshortcut', 'SHIFT,Insert,']])
        state=json.loads((self.base / 'clipboard.json').read_text())
        self.assertEqual(base64.b64decode(state['data']), b'new-user-copy')

    def test_forking_clipboard_owner_does_not_block_or_lose_the_image(self):
        self.env['PASTE_COPY_FORK']='1'
        self.assertEqual(self.run_paste(), [['dispatch', 'sendshortcut', 'SHIFT,Insert,']])
        state=json.loads((self.base / 'clipboard.json').read_text())
        self.assertEqual(state['mime'], 'image/png')
        self.assertEqual(base64.b64decode(state['data']), self.png)

    def test_text_in_ghostty_keeps_terminal_clipboard_paste(self):
        self.env['PASTE_TYPES'] = 'text/plain\ntext/html\n'
        self.assertEqual(self.run_paste(), [['dispatch', 'sendshortcut', 'CTRL,V,']])

    def test_image_in_chrome_keeps_normal_ctrl_v(self):
        self.env['PASTE_WINDOW'] = json.dumps({'class': 'google-chrome'})
        self.assertEqual(self.run_paste(), [['dispatch', 'sendshortcut', 'CTRL,V,']])

    def test_unreadable_clipboard_does_not_swallow_normal_paste(self):
        self.env['PASTE_CLIPBOARD_EXIT'] = '1'
        self.assertEqual(self.run_paste(), [['dispatch', 'sendshortcut', 'CTRL,V,']])

    def test_no_active_window_preserves_focused_layer_paste(self):
        self.env['PASTE_WINDOW'] = '{}'
        self.assertEqual(self.run_paste(), [['dispatch', 'sendshortcut', 'CTRL,V,']])


if __name__ == '__main__':
    unittest.main()
