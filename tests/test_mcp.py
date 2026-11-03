import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

BRIDGE=Path(__file__).resolve().parents[1]/'lisp'/'claude-ide-mcp.py'
spec=importlib.util.spec_from_file_location('bridge',str(BRIDGE))
bridge=importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)

class MCPTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.path=Path(self.temp.name)/'editor.json'
        self.path.write_text(json.dumps({'context':'한글 선택 영역'},ensure_ascii=False),encoding='utf-8')
    def tearDown(self):
        self.temp.cleanup()
    def request(self,method,params=None):
        return bridge.handle({'id':1,'method':method,'params':params or {}},self.path)
    def test_initialize_and_notification(self):
        self.assertEqual(self.request('initialize',{'protocolVersion':'2025-03-26'})['result']['protocolVersion'],'2025-03-26')
        self.assertIsNone(bridge.handle({'method':'notifications/initialized'},self.path))
    def test_tool_read_and_live_update(self):
        params={'name':'get_editor_context','arguments':{}}
        self.assertIn('한글 선택 영역',self.request('tools/call',params)['result']['content'][0]['text'])
        self.path.write_text('{"context":"new selection"}')
        self.assertIn('new selection',self.request('tools/call',params)['result']['content'][0]['text'])
    def test_rejects_other_tools_and_arguments(self):
        for params in ({'name':'write_file'},{'name':'get_editor_context','arguments':{'path':'/etc/passwd'}}):
            self.assertIn('error',self.request('tools/call',params))
    def test_missing_corrupt_and_large_snapshot(self):
        for content in ('bad json','[]','x'*(bridge.MAX_STATE_BYTES+1)):
            self.path.write_text(content)
            self.assertTrue(self.request('tools/call',{'name':'get_editor_context'})['result']['isError'])
        self.path.unlink()
        self.assertTrue(self.request('tools/call',{'name':'get_editor_context'})['result']['isError'])
    def test_stdio_protocol_utf8(self):
        requests=[{'jsonrpc':'2.0','id':1,'method':'initialize','params':{}},
                  {'jsonrpc':'2.0','method':'notifications/initialized'},
                  {'jsonrpc':'2.0','id':2,'method':'tools/list'},
                  {'jsonrpc':'2.0','id':3,'method':'tools/call','params':{'name':'get_editor_context','arguments':{}}}]
        proc=subprocess.run([sys.executable,str(BRIDGE),str(self.path)],
                            input='\n'.join(json.dumps(x) for x in requests)+'\n',
                            stdout=subprocess.PIPE,stderr=subprocess.PIPE,universal_newlines=True,
                            encoding='utf-8',check=True)
        replies=[json.loads(x) for x in proc.stdout.splitlines()]
        self.assertEqual([x['id'] for x in replies],[1,2,3])
        self.assertIn('한글 선택 영역',replies[-1]['result']['content'][0]['text'])
        self.assertFalse(proc.stderr)

if __name__=='__main__':
    unittest.main()
