#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest
import json
import tempfile
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('desktop_style',Path(__file__).with_name('ubuntu-desktop-style.py'))
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class StyleTests(unittest.TestCase):
    def test_geometry_preserves_custom_widgets_and_other_bars(self):
        settings={'keep':True,'barConfigs':[{'id':'primary','rightWidgets':['custom','clock'],'userValue':42},{'id':'secondary','spacing':7}]}
        result=module.merge(settings,{'settings':{'cornerRadius':10},'bar':{'spacing':0}},layout=False)
        self.assertEqual(result['barConfigs'][0]['rightWidgets'],['custom','clock'])
        self.assertEqual(result['barConfigs'][0]['userValue'],42)
        self.assertEqual(result['barConfigs'][1],settings['barConfigs'][1])
        self.assertEqual(result['barConfigs'][0]['spacing'],0)
        self.assertNotIn('spacing',settings['barConfigs'][0])
    def test_explicit_layout_matches_mac_sections(self):
        result=module.merge({'barConfigs':[{'id':'main'}]}, {'settings':{},'bar':{}},layout=True)
        bar=result['barConfigs'][0]
        self.assertEqual(bar['leftWidgets'],['dotfilesBreakTimer','workspaceSwitcher'])
        self.assertEqual(bar['centerWidgets'],['music'])
        self.assertIn('dotfilesCodexUsage',bar['rightWidgets'])
        self.assertEqual(bar['rightWidgets'][-1],'clock')
    def test_explicit_generation_is_used_and_original_settings_backed_up(self):
        with tempfile.TemporaryDirectory() as tmp:
            base=Path(tmp);config=base/'config';(config/'DankMaterialShell').mkdir(parents=True)
            settings=config/'DankMaterialShell/settings.json'
            settings.write_text('{"keep": true, "barConfigs": [{"id": "main"}]}')
            pinned=base/'generation-a';pinned.mkdir()
            (pinned/'ubuntu-style.json').write_text(json.dumps({'settings':{'cornerRadius':7},'bar':{'spacing':2}}))
            with patch.object(module,'CONFIG',config),patch.object(module,'CURRENT',base/'missing-current'),patch.dict(module.os.environ,{},clear=True),patch('sys.argv',['style','--generation',str(pinned)]):
                module.main()
            updated=json.loads(settings.read_text())
            self.assertTrue(updated['keep'])
            self.assertEqual(updated['cornerRadius'],7)
            self.assertTrue(settings.with_suffix('.json.before-macos-style').is_file())

    def test_missing_bar_is_reported_without_replacing_configuration(self):
        with self.assertRaisesRegex(ValueError,'bar'):
            module.merge({'private':1},{'settings':{},'bar':{}})

if __name__=='__main__':unittest.main()
