#!/usr/bin/env python3
"""Run the production iSH adapter/terminal on an ARM64 iOS Simulator.

This intentionally uses a small harness because Dylix's existing LLVM simulator
frameworks are x86_64-only. The runtime and terminal sources are identical.
"""
import argparse
import io
import tarfile
import zipfile
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
 p=argparse.ArgumentParser();p.add_argument('--terminal263',action='store_true');p.add_argument('--backup262',action='store_true');p.add_argument('--shared260',action='store_true');p.add_argument('--packages253',action='store_true');p.add_argument('--resources247',action='store_true');p.add_argument('--resource-origin');p.add_argument('--data237',action='store_true');p.add_argument('--directory-check227',type=int,choices=[1,2]);p.add_argument('--workspace227',action='store_true');p.add_argument('--root-check227',type=int,choices=[1,2,3]);p.add_argument('--root227',action='store_true');p.add_argument('--browser-ui',action='store_true');p.add_argument('--environment-ui',action='store_true');p.add_argument('--reverse-only',action='store_true');p.add_argument('--device',default='booted');p.add_argument('--packages',action='store_true');p.add_argument('--network',action='store_true');a=p.parse_args()
 output=ROOT/'build/ish-regression';app=output/'DylixISHProof.app';app.mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env.update({'LC_ALL':'C','LANG':'C'})
 run([sys.executable,ROOT/'scripts/build_ish.py','--platform','simulator'],env=env)
 shutil.copyfile(ROOT/'tests/MachOSignatureVerify.py',app/'MachOSignatureVerify.py')
 shutil.copytree(ROOT/'Resources/iSH',app/'iSH',dirs_exist_ok=True)
 if a.resources247:
  for name in ['developer-tools.tar','reverse-tools.tar']:(app/'iSH'/name).unlink(missing_ok=True)
  catalog=json.loads((ROOT/'Resources/DownloadResources.json').read_text())
  for entry in catalog:
   if a.resource_origin:entry['url']=a.resource_origin+'/downloads/dylix/v1/'+entry['file']
  if a.resource_origin:
   catalog.extend([
    dict(id='bad-hash',file='bad-hash.bin',sha256='0'*64,bytes=9,url=a.resource_origin+'/fixture.bin'),
    dict(id='missing-resource',file='missing.bin',sha256='0'*64,bytes=4096,url=a.resource_origin+'/missing.bin'),
    dict(id='oversized-resource',file='oversized.bin',sha256='0'*64,bytes=3,url=a.resource_origin+'/fixture.bin'),
   ])
  (app/'DownloadResources.json').write_text(json.dumps(catalog))
  shutil.copy2(ROOT/'build/device/TheosMobileCompiler.app/SDK26Resource.plist',app/'SDK26Resource.plist')
 shutil.copytree(ROOT/'Resources/Terminal',app/'Terminal',dirs_exist_ok=True)
 shutil.copytree(ROOT/'Resources/AgentSkills',app/'AgentSkills',dirs_exist_ok=True)
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
 with zipfile.ZipFile(app/'data237.ipa','w') as z:z.writestr('Payload/Fixture.app/marker.txt','IPA_SAME_SESSION_OK')
 info={'CFBundleExecutable':'DylixISHProof','CFBundleIdentifier':'com.dylix.ishproof','CFBundleName':'DylixISHProof','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','MinimumOSVersion':'15.0','UIDeviceFamily':[1,2],'UILaunchScreen':{}}
 (app/'Info.plist').write_bytes(plistlib.dumps(info))
 libs=ROOT/'build/ish/simulator'
 command=['xcrun','--sdk','iphonesimulator','clang','-target','arm64-apple-ios15.0-simulator','-fobjc-arc','-fno-modules','-DDYLIX_HAS_ISH=1','-I'+str(ROOT/'Vendor/iSH'),'-I'+str(libs/'meson')]
 command += [ROOT/p for p in ['App/AI/Attachments/TFAIDirectoryPickerDiagnostics.m','App/Incoming/TFShareGroups.m','ShareExtension/TFShareFileProvider.m','ShareExtension/TFShareFolderArchive.m','App/AI/Sandbox/TFAIISHRuntime.m','App/AI/Sandbox/DXLinuxToolBatch.m','App/AI/Resources/DXResourceStore.m','App/SDKResources.m','App/ArchiveImport.m','App/TheosMakefile.m','App/AI/Attachments/TFAIDirectoryRegistry.m','App/AI/Attachments/TFAIDirectoryAccess.m','App/AI/Sandbox/TFAIISHRootCatalog.m','App/AI/Sandbox/TFAIISHRootCatalogUI.m','App/AI/Sandbox/TFAIISHMirrors.m','App/AI/Sandbox/TFAIISHRemote.m','App/AI/Sandbox/TFAIISHEnvironment.m','App/AI/Sandbox/TFAIISHEnvironmentUI.m','App/AI/Sandbox/TFAIISHSkillView.m','App/AI/Agent/TFAIAgentContext.m','App/AI/Sandbox/TFAIISHExports.m','App/AI/Sandbox/TFAIISHTerminal.m','App/AI/Sandbox/TFAIISHHub.m','App/AI/Attachments/TFAIDirectoryRegistryUI.m','App/AI/Backup/DXBackup.m','App/AI/Backup/DXBackupTask.m','App/AI/Backup/DXBackupUI.m','App/AI/Sandbox/TFAIISHPreview.m','App/AI/Sandbox/TFAIISHMCPTransport.m','App/AI/Sandbox/TFAIISHFiles.m','App/AI/Agent/TFAIWebDOM.m','App/AI/Agent/TFAIReadOnlyBrowser.m','App/AI/Tools/TFAIWebTools.m','App/AI/Core/AIPolicy.m','App/AI/Agent/TFAIMCP.m','App/AI/Registry/TFAIToolRegistry.m','App/AI/Permissions/TFAIPolicy.m','tests/ISHRuntimeIOSRegression.m']]
 command += [libs/n for n in ['libish.a','libish_emu.a','libfakefs.a','libish_rootfs.a']]
 for framework in ['QuartzCore','UIKit','Foundation','CoreFoundation','CoreGraphics','WebKit','UniformTypeIdentifiers','Security']:command+=['-framework',framework]
 # Simulator uses an embedded entitlements section, as Xcode does; ad-hoc
 # restricted signature entitlements cannot launch on the host kernel.
 entitlements=output/'proof-entitlements.plist';entitlements.write_bytes(plistlib.dumps({'application-identifier':'DYLIXPROOF.com.dylix.ishproof','keychain-access-groups':['DYLIXPROOF.com.dylix.ishproof']}))
 command+=['-Xlinker','-sectcreate','-Xlinker','__TEXT','-Xlinker','__entitlements','-Xlinker',entitlements,'-lsqlite3','-lresolv','-larchive','-o',app/'DylixISHProof'];run(command,env=env)
 run(['codesign','--force','--sign','-',app],env=env)
 if a.resources247:subprocess.run(['xcrun','simctl','uninstall',a.device,'com.dylix.ishproof'],check=False,capture_output=True)
 run(['xcrun','simctl','install',a.device,app],env=env)
 data=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.device,'com.dylix.ishproof','data'],text=True).strip())
 result=data/'Documents/ish-regression.json'
 if result.exists():result.unlink()
 run(['xcrun','simctl','launch','--terminate-running-process',a.device,'com.dylix.ishproof',*(['--terminal263'] if a.terminal263 else []),*(['--backup262'] if a.backup262 else []),*(['--shared260'] if a.shared260 else []),*(['--packages253'] if a.packages253 else []),*(['--resources247'] if a.resources247 else []),*(['--data237'] if a.data237 else []),*(['--directory-check227',str(a.directory_check227)] if a.directory_check227 else []),*(['--workspace227'] if a.workspace227 else []),*(['--root227'] if a.root227 else []),*(['--root-check227',str(a.root_check227)] if a.root_check227 else []),*(['--browser-ui'] if a.browser_ui else []),*(['--environment-ui'] if a.environment_ui else []),*(['--test-packages'] if a.packages else []),*(['--test-network'] if a.network else []),*(['--test-reverse-only'] if a.reverse_only else [])],env=env)
 deadline=time.monotonic()+720
 while time.monotonic()<deadline:
  if result.exists():
   try: rows=json.loads(result.read_text())
   except (ValueError,OSError):rows=[]
   if any(r['test']==('terminal263_finished' if a.terminal263 else 'backup262_finished' if a.backup262 else 'shared260_finished' if a.shared260 else 'packages253_finished' if a.packages253 else 'resources247_finished' if a.resources247 else 'data237_finished' if a.data237 else 'directory227_finished' if a.directory_check227 else 'root227_check_finished' if a.root_check227 else 'workspace227_finished' if a.workspace227 else 'root227_scheduled' if a.root227 else 'browser_ui' if a.browser_ui else 'environment_ui' if a.environment_ui else 'reverse_suite_finished' if a.reverse_only else 'terminal_webview_roundtrip') for r in rows):break
  time.sleep(.25)
 else:raise SystemExit('iSH runtime tests did not finish in 720 seconds; inspect simulator crash logs.')
 if a.terminal263:
  (output/'terminal263-results.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
  print(json.dumps(rows,ensure_ascii=False,indent=2))
  run(['xcrun','simctl','io',a.device,'screenshot',output/'terminal263.png'],env=env)
  if not all(r['passed'] for r in rows):raise SystemExit('Terminal binding regression failed')
  return
 if a.backup262:
  (output/'backup262-results.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
  print(json.dumps(rows,ensure_ascii=False,indent=2))
  if not all(r['passed'] for r in rows):raise SystemExit('Backup notification regression failed')
  return
 if a.shared260:
  combined=rows
  for stage in ['restart','overwrite']:
   run(['xcrun','simctl','terminate',a.device,'com.dylix.ishproof'],env=env)
   if stage=='overwrite':
    run(['xcrun','simctl','install',a.device,app],env=env)
    data=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.device,'com.dylix.ishproof','data'],text=True).strip())
    result=data/'Documents/ish-regression.json'
   result.unlink(missing_ok=True)
   run(['xcrun','simctl','launch',a.device,'com.dylix.ishproof','--shared260-check'],env=env)
   until=time.monotonic()+90
   while time.monotonic()<until:
    try: checks=json.loads(result.read_text())
    except (ValueError,OSError):checks=[]
    if any(r['test']=='shared260_finished' for r in checks):break
    time.sleep(.25)
   else:raise SystemExit('shared260 '+stage+' timed out')
   for row in checks:row['stage']=stage
   combined+=checks
  (output/'shared260-results.json').write_text(json.dumps(combined,ensure_ascii=False,indent=2))
  print(json.dumps(combined,ensure_ascii=False,indent=2))
  if not all(r['passed'] for r in combined):raise SystemExit('shared260 failed')
  return
 run(['xcrun','simctl','io',a.device,'screenshot',output/'terminal.png'],env=env)
 if a.packages253 or a.resources247 or a.data237 or a.directory_check227 or a.environment_ui or a.browser_ui or a.workspace227 or a.root227 or a.root_check227:
  print(json.dumps(rows,ensure_ascii=False,indent=2))
  if not all(r['passed'] for r in rows):raise SystemExit('Environment UI failed')
  return
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
 for stage in ['seed','backup','restore','reset']:
  result.unlink(missing_ok=True)
  run(['xcrun','simctl','launch','--terminate-running-process',a.device,'com.dylix.ishproof','--maintenance-'+stage],env=env)
  deadline=time.monotonic()+120
  while time.monotonic()<deadline:
   if result.exists():
    try: maintenance=json.loads(result.read_text())
    except (ValueError,OSError):maintenance=[]
    if any(r['test']=='maintenance_'+stage for r in maintenance):break
   time.sleep(.25)
  else:raise SystemExit('Maintenance '+stage+' did not finish')
  rows+=maintenance
 (output/'results.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n')
 for row in rows:print(str(row['test'])+': '+('PASS' if row['passed'] else 'FAIL'))
 if not all(row['passed'] for row in rows):raise SystemExit('iSH regression failed; see '+str(output/'results.json'))
 print('PASS: '+str(output/'results.json'))
if __name__=='__main__':main()
