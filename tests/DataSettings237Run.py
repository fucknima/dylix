"""Verify production settings routing and cold-start restore on booted simulators."""
from pathlib import Path
import argparse,hashlib,json,subprocess,time,uuid
root=Path(__file__).resolve().parents[1]
def run(*args):
 return subprocess.check_output([str(x) for x in args],text=True).strip()
def wait(check):
 for _ in range(150):
  if check():return
  time.sleep(.2)
 raise AssertionError('Simulator workflow timed out')
parser=argparse.ArgumentParser();parser.add_argument('--device');args=parser.parse_args()
devices=json.loads(run('xcrun','simctl','list','devices','booted','--json'))
for device in [d for group in devices['devices'].values() for d in group if 'iPhone' in d['name'] or 'iPad' in d['name']]:
 ident=device['udid']
 if args.device and ident!=args.device:continue
 bundle='com.xuegao.theosmobilecompiler'
 run('xcrun','simctl','install',ident,root/'build/simulator/TheosMobileCompiler.app')
 home=Path(run('xcrun','simctl','get_app_container',ident,bundle,'data'));result=home/'Documents/data-settings237.json';rows=[]
 for route in range(3):
  result.unlink(missing_ok=True)
  run('xcrun','simctl','launch','--terminate-running-process',ident,bundle,'--data-settings237','--data-route='+str(route))
  wait(result.exists);rows.extend(json.loads(result.read_text()));print(device['name'],'route',route,rows[-1],flush=True)
 assert len(rows)==3 and all(r['passed'] for r in rows),rows
 run('xcrun','simctl','terminate',ident,bundle)
 # Real production startup applies this plan before opening any chat/project store.
 base=home/'Library/Application Support/DylixRestore';pending=base/'pending.json';assert not pending.exists()
 stage=base/str(uuid.uuid4());stage.mkdir(parents=True)
 project='Documents/Projects/Backup237Fixture/Tweak.xm';chat='Library/Application Support/TweakForgeAI/Sessions/general/backup237-fixture.json'
 assert not (home/project).exists() and not (home/chat).exists()
 payloads={project:b'// COLD_START_RESTORE_OK\n',chat:json.dumps({'projectRoot':'/old/container/Documents/Projects/Backup237Fixture','messages':[]}).encode()}
 records=[]
 for path,data in payloads.items():
  file=stage/path;file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(data)
  records.append({'path':path,'category':'projects' if path==project else 'chats','sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
 (stage/'manifest.json').write_text(json.dumps({'format':'dylixbak/1','sourceHome':'/old/container','categories':['projects','chats'],'files':records,'includesSecrets':False}))
 pending.write_text(json.dumps({'stage':stage.name,'categories':['projects','chats']}))
 run('xcrun','simctl','launch',ident,bundle)
 wait(lambda:not pending.exists());assert (home/project).read_bytes()==payloads[project]
 assert json.loads((home/chat).read_text())['projectRoot']==str(home.resolve()/'Documents/Projects/Backup237Fixture')
 (home/project).unlink();(home/project).parent.rmdir();(home/chat).unlink()
 print(json.dumps({'device':device['name'],'settings':rows,'coldStartRestore':True},ensure_ascii=False))
