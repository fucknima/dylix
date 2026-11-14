from pathlib import Path
import argparse,json,subprocess,time,shutil
r=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('--device',action='append',required=True);a=p.parse_args()
def run(*args):return subprocess.check_output(list(map(str,args)),text=True).strip()
for device in a.device:
 bundle='com.xuegao.theosmobilecompiler';run('xcrun','simctl','install',device,r/'build/simulator/TheosMobileCompiler.app');home=Path(run('xcrun','simctl','get_app_container',device,bundle,'data'))
 for mode in ('optimization252',):
  path=home/f'Documents/{mode}-results.json';path.unlink(missing_ok=True)
  run('xcrun','simctl','launch','--terminate-running-process',device,bundle,'--data-settings237','--'+mode)
  deadline=time.monotonic()+65
  while not path.exists() and time.monotonic()<deadline:time.sleep(.2)
  assert path.exists(),(device,mode,'timed out')
  rows=json.loads(path.read_text());out=r/'build/optimization252-evidence';out.mkdir(exist_ok=True)
  shutil.copy2(path,out/f'{device}-{mode}.json')
  shutil.copy2(home/'Documents/optimization252-measurement.json',out/f'{device}-measurement.json')
  for image in (home/'Documents').glob(mode+'-*.png'):shutil.copy2(image,out/f'{device}-{image.name}')
  assert rows and all(x['passed'] for x in rows),rows
  if mode=='update250':
   time.sleep(.5)
   run('xcrun','simctl','io',device,'screenshot',out/f'{device}-official-dialog.png')
  print(device,mode,'PASS',len(rows),flush=True)
