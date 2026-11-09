"""Production HTTP MCP regression, with no external service or user config writes."""
import json
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

calls = []
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass
    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        method = request['method']
        if method != 'initialize':
            assert self.headers['MCP-Protocol-Version'] == '2025-03-26'
            assert self.headers['Mcp-Session-Id'] == 'fixture-session'
        if method == 'notifications/initialized':
            self.send_response(202); self.end_headers(); return
        if method == 'initialize':
            result = {'protocolVersion':'2025-03-26','capabilities':{'tools':{}},'serverInfo':{'name':'fixture','version':'1'}}
        elif method == 'tools/list':
            def tool(name, annotations=None):
                row = {'name':name,'inputSchema':{'type':'object','properties':{}}}
                if annotations is not None: row['annotations'] = annotations
                return row
            result = {'tools':[tool('get_screen_info'),tool('write_file',{'readOnlyHint':True,'destructiveHint':False})]} if request.get('params',{}).get('cursor') else {'tools':[tool('search_docs',{'readOnlyHint':True}),tool('tap_screen',{'readOnlyHint':True,'destructiveHint':False})],'nextCursor':'page2'}
        elif method == 'tools/call':
            calls.append(request['params']['name'])
            result = {'content':[{'type':'text','text':request['params']['name']}],'isError':False}
        else:
            raise AssertionError(method)
        payload = json.dumps({'jsonrpc':'2.0','id':request['id'],'result':result}).encode()
        sse = method == 'tools/list'
        if sse: payload = b'data: ' + payload + b'\n\n'
        self.send_response(200)
        self.send_header('Content-Type','text/event-stream' if sse else 'application/json')
        self.send_header('Mcp-Session-Id','fixture-session')
        self.send_header('Content-Length',str(len(payload)))
        self.end_headers(); self.wfile.write(payload)

root = Path(__file__).resolve().parents[1]
server = ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix='dylix-mcp-access-') as folder:
        exe = Path(folder)/'test'
        files = ['tests/MCPAccessTests.m','App/AI/Agent/TFAIMCP.m','App/AI/Registry/TFAIToolRegistry.m','App/AI/Sandbox/TFAIISHRuntime.m','App/AI/Sandbox/TFAIISHMCPTransport.m','App/AI/Permissions/TFAIPolicy.m','App/AI/Providers/TFAIProtocol.m','App/AI/Providers/TFAIRegistry.m']
        subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-fblocks','-Wno-nullability-completeness',*[str(root/f) for f in files],'-framework','Foundation','-framework','Security','-o',str(exe)],check=True)
        subprocess.run([str(exe),f'http://127.0.0.1:{server.server_port}/mcp'],check=True,timeout=45)
        assert calls == ['search_docs','tap_screen','get_screen_info'], calls
        print('PASS denied, revoked and SQL mutation calls never reached HTTP server')
finally:
    server.shutdown()
