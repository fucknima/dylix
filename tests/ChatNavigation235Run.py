"""Build and verify real chat attachment rendering and native tab visibility."""
from pathlib import Path
import argparse,json,os,shutil,subprocess,time
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--skip-build',action='store_true');parser.add_argument('--device',action='append');args=parser.parse_args()
env=os.environ.copy();env.setdefault('DYLIX_SDK_26_0',str(root.parents[2]/'SDKDownloads/iOS-SDKs-26/iPhoneOS26.0.sdk'))
def run(*cmd):return subprocess.run([str(x) for x in cmd],check=True,env=env,capture_output=True,text=True).stdout.strip()
if not args.skip_build:run('python3',root/'scripts/build.py','--simulator')
if args.device:devices=args.device
else:
 inventory=json.loads(run('xcrun','simctl','list','devices','booted','--json'));devices=[]
 for kind in ('iPhone','iPad'):
  found=next((d['udid'] for group in inventory['devices'].values() for d in group if kind in d['name']),None)
  if found:devices.append(found)
assert devices,'Boot an iPhone or iPad simulator first'
out=root/'build/ui235';out.mkdir(parents=True,exist_ok=True)
for device in devices:
 run('xcrun','simctl','install',device,root/'build/simulator/TheosMobileCompiler.app')
 data=Path(run('xcrun','simctl','get_app_container',device,'com.xuegao.theosmobilecompiler','data'))/'Documents';result=data/'ui235-results.json';result.unlink(missing_ok=True)
 run('xcrun','simctl','launch','--terminate-running-process',device,'com.xuegao.theosmobilecompiler','--ui235-tests')
 deadline=time.monotonic()+40
 while not result.exists() and time.monotonic()<deadline:time.sleep(.2)
 assert result.exists(),f'{device}: integration test timed out'
 rows=json.loads(result.read_text())
 for artifact in data.glob('ui235-*'):shutil.copy2(artifact,out/(device+'-'+artifact.name))
 failed=[r['name'] for r in rows if not r['passed']]
 print(json.dumps({'device':device,'checks':len(rows),'failures':failed}))
 assert not failed,failed
