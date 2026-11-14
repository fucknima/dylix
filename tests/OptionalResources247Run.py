"""Reproduce real HTTPS download/install/restart/uninstall on an iOS simulator.

Creates a temporary localhost-only TLS server and adds its temporary root cert
to the chosen simulator (never the Mac system trust store). Uses real production
resource/SDK/runtime code. The small native harness stubs unrelated project UI.
"""
from pathlib import Path
import argparse
import functools
import http.server
import json
import os
import shutil
import ssl
import subprocess
import sys
import tempfile
import threading
import time

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
args = parser.parse_args()
evidence = root / 'build/data247-evidence'
evidence.mkdir(exist_ok=True)

def run(*argv, **kw):
    return subprocess.run([str(x) for x in argv], check=True, **kw)

def collect(name):
    data = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device, 'com.dylix.ishproof', 'data'], text=True).strip()) / 'Documents'
    output = data / 'ish-regression.json'
    deadline = time.monotonic() + 720
    while time.monotonic() < deadline:
        if output.exists():
            rows = json.loads(output.read_text())
            if any(row['test'] == 'resources247_finished' for row in rows):
                shutil.copy(output, evidence / f'{name}.json')
                for image in data.glob('data247-*.png'):
                    shutil.copy(image, evidence / image.name)
                assert all(row['passed'] for row in rows), rows
                output.unlink()
                print(f'{name}: PASS {len(rows)} integration checks', flush=True)
                return
        time.sleep(.25)
    raise RuntimeError(f'{name} timed out')

with tempfile.TemporaryDirectory(prefix='dylix247-https-') as temporary:
    stage = Path(temporary)
    run(sys.executable, root / 'scripts/prepare_download_resources.py', '--stage', stage)
    (stage / 'fixture.bin').write_bytes(b'fixture47')
    cert, key = stage / 'cert.pem', stage / 'key.pem'
    run('openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', key, '-out', cert, '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    run('xcrun', 'simctl', 'keychain', args.device, 'add-root-cert', cert)
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(stage)))
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with (evidence / 'native-build.log').open('w') as log:
            run(sys.executable, root / 'tests/ISHRuntimeRun.py', '--resources247', '--resource-origin', f'https://localhost:{server.server_port}', '--device', args.device, stdout=log, stderr=subprocess.STDOUT)
        collect('download-install')
        run('xcrun', 'simctl', 'launch', '--terminate-running-process', args.device, 'com.dylix.ishproof', '--resources247-persist')
        collect('restart-uninstall')
    finally:
        server.shutdown()
        server.server_close()
