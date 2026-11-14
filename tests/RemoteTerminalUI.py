"""Exact production terminal renderer + xterm; mocked job API, real browser DOM.
Native authorization/PTY are covered separately by --workspace227 on iOS.
"""
import json, threading
from pathlib import Path
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from playwright.sync_api import sync_playwright,expect
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*a,**kw):super().__init__(*a,directory=str(ROOT/'Resources'),**kw)
 def log_message(self,*a):pass
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(headless=True,executable_path='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
  page=browser.new_page(viewport={'width':1280,'height':900});errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
  page.goto(f'http://127.0.0.1:{server.server_port}/RemoteWeb/remote.css');page.set_content('<main><div id="toolbar"></div><div id="module-body"></div><p id="error"></p></main>')
  page.add_script_tag(url=f'http://127.0.0.1:{server.server_port}/Terminal/xterm.js');page.add_script_tag(url=f'http://127.0.0.1:{server.server_port}/Terminal/addon-fit.js');page.add_style_tag(path=str(ROOT/'Resources/Terminal/xterm.css'))
  page.add_script_tag(content='''const $=id=>document.getElementById(id);let moduleEpoch=1,sessionID='s1';window.calls=[];window.denied=false;window.started=false;window.reads=0;window.holdRead=false;window.releaseRead=null;
function node(tag,text,cls){const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e;}
function showError(e){$('error').textContent=e.message;}
function button(label,fn){const e=node('button',label);e.onclick=()=>Promise.resolve().then(fn).catch(showError);return e;}
function toolbar(...elements){$('toolbar').replaceChildren(...elements);}
async function run(action,args){calls.push({action,args});if(denied)throw Error('当前会话终端授权已撤销');if(action==='ai_sessions')return {sessions:[{id:'s1',title:'工程一'},{id:'s2',title:'工程二'}]};if(action==='terminal_status')return {processes:started?[{process_id:'process-1',state:'running'}]:[]};if(action==='terminal_start'){started=true;return {process_id:'process-1'};}if(action==='terminal_read'){if(holdRead)return new Promise(resolve=>{releaseRead=()=>resolve({output:'STALE_SESSION_OUTPUT',next_offset:300,running:false});});reads++;return {output:reads===1?'\\u001b[32mREAL_XTERM_OUTPUT\\u001b[0m\\r\\n':'',next_offset:20,running:false,exit_code:0};}return {};}
''')
  source=(ROOT/'Resources/RemoteWeb/remote.js').read_text();page.add_script_tag(content=source[source.index('async function renderTerminal(epoch)'):]);page.evaluate('renderTerminal(1)');page.wait_for_load_state('networkidle')
  expect(page.get_by_label('终端会话')).to_have_value('s1');expect(page.locator('.xterm')).to_be_visible();print('PASS actual xterm and isolated session chooser')
  page.get_by_role('button',name='新建终端',exact=True).click();page.wait_for_function("document.querySelector('.xterm-screen').textContent.includes('REAL_XTERM_OUTPUT')");print('PASS ANSI output rendered by real xterm')
  page.get_by_label('终端输入',exact=True).fill('echo hello');page.get_by_role('button',name='发送',exact=True).click();page.wait_for_function("calls.some(c=>c.action==='terminal_write'&&c.args.input==='echo hello\\n')");print('PASS explicit line submission through job route')
  page.get_by_role('button',name='Ctrl-C',exact=True).click();page.wait_for_function("calls.some(c=>c.action==='terminal_write'&&c.args.input==='\\u0003')");print('PASS interrupt through confirmation-aware job route')
  page.get_by_role('button',name='同步尺寸',exact=True).click();page.wait_for_function("calls.some(c=>c.action==='terminal_resize'&&c.args.columns>=20&&c.args.rows>=1)");print('PASS fit dimensions sent explicitly')
  page.evaluate('denied=true');page.get_by_role('button',name='重连读取',exact=True).click();expect(page.locator('.detail-note')).to_contain_text('授权已撤销');print('PASS revocation error shown without pretending connected')
  page.screenshot(path=str(ROOT/'build/proof227/remote-terminal.png'),full_page=True)
  page.evaluate('denied=false');page.get_by_label('终端会话').select_option('s2');page.wait_for_function("calls.some(c=>c.action==='terminal_status'&&c.args.sessionID==='s2')");expect(page.get_by_label('终端输入',exact=True)).to_have_value('');print('PASS session switch resets output cursor')
  page.get_by_role('button',name='新建终端',exact=True).click();page.wait_for_function("calls.filter(c=>c.action==='terminal_start').length===2");page.get_by_role('button',name='停止进程',exact=True).click();page.wait_for_function("calls.some(c=>c.action==='terminal_stop')");print('PASS owned process stop route')
  page.evaluate('holdRead=true');page.get_by_role('button',name='重连读取',exact=True).click();page.wait_for_function('releaseRead!==null');page.get_by_label('终端会话').select_option('s1');page.evaluate('releaseRead()');page.wait_for_timeout(200);assert 'STALE_SESSION_OUTPUT' not in page.locator('.xterm-screen').inner_text();print('PASS in-flight output discarded after session switch')
  assert not errors,errors
  print('TOTAL 9 remote terminal browser checks passed');browser.close()
finally:server.shutdown();server.server_close()
