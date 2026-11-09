#!/usr/bin/env python3
"""Run the production iSH adapter/terminal on an ARM64 iOS Simulator.

This intentionally uses a small harness because Dylix's existing LLVM simulator
frameworks are x86_64-only. The runtime and terminal sources are identical.
"""
import argparse
import io
import tarfile
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
def run(argv, **kw):return subprocess.run([str(x) for x in argv],check=True,**kw)

def main():
 p=argparse.ArgumentParser();p.add_argument('--reverse-only',action='store_true');p.add_argument('--device',default='booted');p.add_argument('--packages',action='store_true');p.add_argument('--network',action='store_true');a=p.parse_args()
 output=ROOT/'build/ish-regression';app=output/'DylixISHProof.app';app.mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env.update({'LC_ALL':'C','LANG':'C'})
 run([sys.executable,ROOT/'scripts/build_ish.py','--platform','simulator'],env=env)
 shutil.copytree(ROOT/'Resources/iSH',app/'iSH',dirs_exist_ok=True)
 shutil.copytree(ROOT/'Resources/Terminal',app/'Terminal',dirs_exist_ok=True)
 fixture=output/'reverse-fixture.c';fixture.write_text('__attribute__((noinline)) int dylix_fixture_add(int value){return value*3+7;} int dylix_fixture_call(int v){return dylix_fixture_add(v)+2;}')
 run(['xcrun','--sdk','iphoneos','clang','-arch','arm64','-miphoneos-version-min=15.0','-O1','-dynamiclib',fixture,'-o',app/'reverse-fixture.dylib'])
 symbols=subprocess.check_output(['xcrun','nm','-n',app/'reverse-fixture.dylib'],text=True)
 address=next('0x'+line.split()[0] for line in symbols.splitlines() if line.endswith(' _dylix_fixture_add'))
 (app/'reverse-fixture.json').write_text(json.dumps({'address':address}))
 run(['xcrun','--sdk','iphoneos','clang','-arch','arm64e','-miphoneos-version-min=15.0','-O1','-dynamiclib',fixture,'-o',app/'reverse-arm64e.dylib'])
 symbols=subprocess.check_output(['xcrun','nm','-n',app/'reverse-arm64e.dylib'],text=True)
 address=next('0x'+line.split()[0] for line in symbols.splitlines() if line.endswith(' _dylix_fixture_add'))
 (app/'reverse-arm64e.json').write_text(json.dumps({'address':address}))
 # Deterministic Debian fixture, including an install script which must not run.
 def tar_bytes(files):
  stream=io.BytesIO()
  with tarfile.open(fileobj=stream,mode='w:gz') as archive:
   for name,body in files.items():
    item=tarfile.TarInfo(name);item.size=len(body);item.mode=0o755 if name=='postinst' else 0o644
    archive.addfile(item,io.BytesIO(body))
  return stream.getvalue()
 members={'debian-binary':b'2.0\n','control.tar.gz':tar_bytes({'control':b'Package: dylix-smoke\nVersion: 1\nArchitecture: all\n','postinst':b'#!/bin/sh\ntouch /workspace/MAINTAINER_RAN\n'}),'data.tar.gz':tar_bytes({'usr/share/dylix/smoke.txt':b'DEB_PAYLOAD_OK\n'})}
 deb=bytearray(b'!<arch>\n')
 for name,body in members.items():
  deb.extend(f'{name+"/":<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(body):<10}`\n'.encode());deb.extend(body)
  if len(body)%2:deb.extend(b'\n')
 (app/'smoke.deb').write_bytes(deb)
 info={'CFBundleExecutable':'DylixISHProof','CFBundleIdentifier':'com.dylix.ishproof','CFBundleName':'DylixISHProof','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','MinimumOSVersion':'15.0','UIDeviceFamily':[1,2],'UILaunchScreen':{}}
 (app/'Info.plist').write_bytes(plistlib.dumps(info))
 libs=ROOT/'build/ish/simulator'
 command=['xcrun','--sdk','iphonesimulator','clang','-target','arm64-apple-ios15.0-simulator','-fobjc-arc','-fno-modules','-DDYLIX_HAS_ISH=1','-I'+str(ROOT/'Vendor/iSH'),'-I'+str(libs/'meson')]
 command += [ROOT/p for p in ['App/AI/Sandbox/TFAIISHRuntime.m','App/AI/Sandbox/TFAIISHExports.m','App/AI/Sandbox/TFAIISHTerminal.m','App/AI/Sandbox/TFAIISHPreview.m','App/AI/Sandbox/TFAIISHMCPTransport.m','App/AI/Sandbox/TFAIISHFiles.m','App/AI/Agent/TFAIWebDOM.m','App/AI/Core/AIPolicy.m','App/AI/Agent/TFAIMCP.m','App/AI/Registry/TFAIToolRegistry.m','App/AI/Permissions/TFAIPolicy.m','tests/ISHRuntimeIOSRegression.m']]
 command += [libs/n for n in ['libish.a','libish_emu.a','libfakefs.a','libish_rootfs.a']]
 for framework in ['UIKit','Foundation','CoreFoundation','CoreGraphics','WebKit','UniformTypeIdentifiers','Security']:command+=['-framework',framework]
 # Simulator uses an embedded entitlements section, as Xcode does; ad-hoc
 # restricted signature entitlements cannot launch on the host kernel.
 entitlements=output/'proof-entitlements.plist';entitlements.write_bytes(plistlib.dumps({'application-identifier':'DYLIXPROOF.com.dylix.ishproof','keychain-access-groups':['DYLIXPROOF.com.dylix.ishproof']}))
 command+=['-Xlinker','-sectcreate','-Xlinker','__TEXT','-Xlinker','__entitlements','-Xlinker',entitlements,'-lsqlite3','-lresolv','-larchive','-o',app/'DylixISHProof'];run(command,env=env)
 run(['codesign','--force','--sign','-',app],env=env)
 run(['xcrun','simctl','install',a.device,app],env=env)
 data=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.device,'com.dylix.ishproof','data'],text=True).strip())
 result=data/'Documents/ish-regression.json'
 if result.exists():result.unlink()
 run(['xcrun','simctl','launch','--terminate-running-process',a.device,'com.dylix.ishproof',*(['--test-packages'] if a.packages else []),*(['--test-network'] if a.network else []),*(['--test-reverse-only'] if a.reverse_only else [])],env=env)
 deadline=time.monotonic()+720
 while time.monotonic()<deadline:
  if result.exists():
   try: rows=json.loads(result.read_text())
   except (ValueError,OSError):rows=[]
   if any(r['test']==('reverse_suite_finished' if a.reverse_only else 'terminal_webview_roundtrip') for r in rows):break
  time.sleep(.25)
 else:raise SystemExit('iSH runtime tests did not finish in 720 seconds; inspect simulator crash logs.')
 run(['xcrun','simctl','io',a.device,'screenshot',output/'terminal.png'],env=env)
 if a.reverse_only:
  (output/'reverse-results.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n')
  print(json.dumps(rows,indent=2,ensure_ascii=False))
  if not all(r['passed'] for r in rows):raise SystemExit('Reverse engine regression failed')
  return
 # Relaunch without uninstalling: kernel restarts, guest files must survive.
 first=rows
 result.unlink()
 run(['xcrun','simctl','launch','--terminate-running-process',a.device,'com.dylix.ishproof','--verify-persistence'],env=env)
 deadline=time.monotonic()+30
 while time.monotonic()<deadline:
  if result.exists():
   try: rows=json.loads(result.read_text())
   except (ValueError,OSError): rows=[]
   if any(r["test"]=="app_restart_persistence" for r in rows):break
  time.sleep(.25)
 else:raise SystemExit('Persistence relaunch did not finish')
 rows=first+rows
 (output/'results.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n')
 for row in rows:print(str(row['test'])+': '+('PASS' if row['passed'] else 'FAIL'))
 if not all(row['passed'] for row in rows):raise SystemExit('iSH regression failed; see '+str(output/'results.json'))
 print('PASS: '+str(output/'results.json'))
if __name__=='__main__':main()
