#!/usr/bin/env python3
"""Real production socket transport against local TCP fixtures; no model requests."""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time

parser=argparse.ArgumentParser()
parser.add_argument('--flex',type=Path,required=True)
args=parser.parse_args()
checks=[]
def check(ok,name):
    checks.append(dict(name=name,passed=bool(ok)))
    print(('PASS ' if ok else 'FAIL ')+name)

with tempfile.TemporaryDirectory(prefix='flex-connection-') as folder:
    binary=Path(folder)/'test'
    subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk',
                    '-fobjc-arc','-Wall','-Werror','-I',str(args.flex),
                    str(Path(__file__).with_name('FlexConnectionTests.m')),str(args.flex/'FLEXDylixConnection.m'),str(args.flex/'FLEXDylixAddress.m'),
                    '-framework','Foundation','-o',str(binary)],check=True)
    for name,ok in json.loads(subprocess.check_output([str(binary),'--scopes'])).items():check(ok,name)
    def run(port,path='/api/v1/pair',timeout=.4):
        result=json.loads(subprocess.check_output([str(binary),str(port),path,str(timeout)],timeout=5))
        for secret in ['fixture-code-never-log','fixture-token-never-log','fixture-csrf-never-log','response-secret-never-log']:
            check(secret not in result['report'] and secret not in result['description'],'diagnostics redact '+secret.split('-')[1])
        return result
    def serve(reply,hold=0,chunk=0):
        listener=socket.socket();listener.bind(('127.0.0.1',0));listener.listen();port=listener.getsockname()[1]
        received=[]
        def work():
            try:
                with listener.accept()[0] as conn:
                    conn.settimeout(2)
                    data=b''
                    while b'\r\n\r\n' not in data:data+=conn.recv(16384)
                    headers,body=data.split(b'\r\n\r\n',1)
                    length=next((int(line.split(b':',1)[1]) for line in headers.split(b'\r\n') if line.lower().startswith(b'content-length:')),0)
                    while len(body)<length:body+=conn.recv(16384)
                    received.append((headers,body))
                    if chunk:
                        for i in range(0,len(reply),chunk):conn.sendall(reply[i:i+chunk]);time.sleep(.001)
                    else:conn.sendall(reply)
                    time.sleep(hold)
            except (OSError,ValueError):pass
            finally:listener.close()
        threading.Thread(target=work,daemon=True).start()
        return port,received
    def response(payload,status=200,extra=b'',length=None):
        body=payload if isinstance(payload,bytes) else json.dumps(payload).encode()
        return b'HTTP/1.1 '+str(status).encode()+b' Test\r\nContent-Length: '+str(len(body) if length is None else length).encode()+b'\r\n'+extra+b'\r\n'+body

    port,received=serve(response({'data':{'state':'approved'}},extra=b'Set-Cookie: DylixRemoteSession=fixture-session; HttpOnly\r\n'),hold=1)
    r=run(port)
    check(r['ok'] and r['token']=='fixture-session','pair response and exact cookie parsing')
    check(r['elapsed']<.35,'Content-Length completes without waiting for server to close')
    head,body=received[0]
    check(b'POST /api/v1/pair HTTP/1.1' in head and b'Cookie: DylixRemoteSession=fixture-token-never-log' in head and b'x-dylix-csrf: fixture-csrf-never-log' in head,'existing POST and authentication headers preserved')
    check(json.loads(body)['code']=='fixture-code-never-log','pairing request JSON preserved')
    port,received=serve(response({'data':{'state':'running'},'session':{'csrf':'fixture-csrf'}}),chunk=3)
    r=run(port,'/api/v1/status',1)
    check(r['ok'] and r['data']['session']['csrf']=='fixture-csrf','fragmented status response and session envelope')
    check(received[0][0].startswith(b'GET ') and not received[0][1],'status GET still has no request body')

    port,_=serve(response({'error':{'code':'invalid_code','message':'response-secret-never-log'},'data':{}},403))
    r=run(port)
    check(not r['ok'] and r['code']==403 and r['domain']=='FLEX.Dylix.HTTP' and '配对码无效' in r['description'],'wrong code distinguished from TCP failure without echoing server body')
    for status in [401,404,423,429,503,302]:
        port,_=serve(response({'data':{},'error':None},status,extra=b'Location: http://127.0.0.1:1/secret\r\n'))
        r=run(port)
        check(not r['ok'] and r['code']==status,'HTTP '+str(status)+' classified, redirects not followed')
    for payload in [b'[]',b'null',b'<html>response-secret-never-log</html>',b'{"data":[]}',b'{"data":{},"session":[]}']:
        port,_=serve(response(payload));r=run(port,'/api/v1/status')
        check(not r['ok'] and '阶段：json' in r['report'],'wrong JSON root/envelope safely rejected')
    port,_=serve(response({'data':{}},length=200));r=run(port)
    check(not r['ok'] and 'read_incomplete' in r['report'],'truncated body distinguished from invalid JSON')
    port,_=serve(b'not-http\r\n\r\n{}');r=run(port)
    check(not r['ok'] and '阶段：headers' in r['report'],'malformed HTTP safely rejected')
    for header in [b'Content-Length: nope\r\n',b'Content-Length: 12\r\nContent-Length: 0\r\n',b'Transfer-Encoding: chunked\r\n']:
        port,_=serve(b'HTTP/1.1 200 OK\r\n'+header+b'\r\n{"data":{}}');r=run(port)
        check(not r['ok'] and '阶段：headers' in r['report'],'unsupported/ambiguous framing rejected')
    port,_=serve(b'',hold=1);r=run(port)
    check(not r['ok'] and '阶段：read' in r['report'] and .3<r['elapsed']<.9,'established connection read timeout is bounded and explicit')
    held=socket.socket();held.bind(('127.0.0.1',0));port=held.getsockname()[1];held.close()
    r=run(port)
    check(not r['ok'] and '拒绝连接' in r['description'] and '尚未进入授权码' in r['description'],'TCP refusal retains errno and does not blame pairing code')
    r=run(0)
    check(not r['ok'] and '地址' in r['description'],'invalid port rejected before connect')

    # Fill a local listen backlog so the actual TCP connect, not recv, times out.
    with socket.socket() as listener:
        listener.bind(('127.0.0.1',0));listener.listen(1);clients=[]
        try:
            for _ in range(8):
                client=socket.socket();client.settimeout(.08)
                try:client.connect(listener.getsockname());clients.append(client)
                except OSError:client.close();break
            r=run(listener.getsockname()[1],timeout=.3)
            check(not r['ok'] and '阶段：connect' in r['report'] and r['elapsed']<.85,'real connect timeout bounded despite saturated backlog')
        finally:
            for client in clients:client.close()

    reports=json.loads(subprocess.check_output([str(binary),'--errors']))
    check(all('目标：http://192.168.20.10:9432' in x['report'] for x in reports),'actual custom port retained in diagnostic')
    check('本地网络权限' in reports[0]['description'] and '不能确定' in reports[0]['description'],'permission advice does not assert unobservable authorization state')
    check(all('尚未进入授权码' in x['description'] for x in reports[:-1]) and '尚未进入授权码' not in reports[-1]['description'],'connection and response failure stages remain distinct')

report=dict(checks=checks,failures=sum(not x['passed'] for x in checks),scope='production Foundation socket transport with local TCP fixtures; no physical iPad or VPN reproduction')
Path(os.environ.get('FLEX_CONNECTION_RESULT','/private/tmp/flex-connection-results.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('RESULT',len(checks),'checks',report['failures'],'failures')
raise SystemExit(bool(report['failures']))
