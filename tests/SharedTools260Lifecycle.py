#!/usr/bin/env python3
"""Fresh test-only App install plus real fakefs legacy migration (never touches Dylix)."""
import argparse,json,plistlib,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--device',required=True);a=p.parse_args()
bundle='com.dylix.ishproof';app=ROOT/'build/ish-regression/DylixISHProof.app'
def ctl(*args):return subprocess.check_output(['xcrun','simctl',*args],text=True).strip()
def data():return Path(ctl('get_app_container',a.device,bundle,'data'))
def launch(flag):
 result=data()/'Documents/ish-regression.json';result.unlink(missing_ok=True)
 ctl('launch',a.device,bundle,flag)
 until=time.monotonic()+360
 while time.monotonic()<until:
  try:rows=json.loads(result.read_text())
  except (OSError,ValueError):rows=[]
  if any(x['test']=='shared260_finished' for x in rows):
   if not all(x['passed'] for x in rows):raise RuntimeError(rows)
   return rows
  time.sleep(.25)
 raise RuntimeError('Test-only app timed out')
# This explicit fixture cleanup is confined to the generated proof App.
subprocess.run(['xcrun','simctl','uninstall',a.device,bundle],capture_output=True)
ctl('install',a.device,str(app));rows=launch('--shared260')
ctl('terminate',a.device,bundle)
base=data()/'Library/Application Support/Dylix/iSH-v1'
shared='b3699d2b0a236797eb0b19394441f1795d2bdd9a55103d75a13783a4bc276d3c';legacy='e'*64
before=(base/shared/'meta.db').stat().st_ino
(base/shared).rename(base/legacy);(base/'shared-environment.plist').unlink()
checks=launch('--shared260-check')
plan=plistlib.loads((base/'shared-environment.plist').read_bytes())
passed=not (base/legacy).exists() and (base/shared/'meta.db').stat().st_ino==before and plan['sourceKey']==legacy and plan['state']=='complete'
rows+=checks+[dict(test='shared260_real_fakefs_legacy_migration_without_copy',passed=passed)]
output=ROOT/'build/ish-regression/shared260-fresh-migration-results.json';output.write_text(json.dumps(rows,ensure_ascii=False,indent=2))
print(json.dumps(rows,ensure_ascii=False,indent=2))
if not passed:raise SystemExit('Migration failed')
