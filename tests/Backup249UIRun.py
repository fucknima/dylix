"""Exercise real backup page, progress, selection size and bottom action."""
from pathlib import Path
import argparse,json,shutil,subprocess,time
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--device',action='append',required=True);args=p.parse_args()
def run(*args):return subprocess.check_output(list(map(str,args)),text=True).strip()
for device in args.device:
 bundle='com.xuegao.theosmobilecompiler'
 run('xcrun','simctl','install',device,root/'build/simulator/TheosMobileCompiler.app')
 home=Path(run('xcrun','simctl','get_app_container',device,bundle,'data'))
 result=home/'Documents/backup249-results.json';result.unlink(missing_ok=True)
 run('xcrun','simctl','launch','--terminate-running-process',device,bundle,'--data-settings237','--backup249')
 deadline=time.monotonic()+70
 while not result.exists() and time.monotonic()<deadline:time.sleep(.2)
 assert result.exists(),f'{device}: timed out'
 rows=json.loads(result.read_text());evidence=root/'build/data249-evidence';evidence.mkdir(exist_ok=True)
 shutil.copy(result,evidence/f'{device}.json')
 for path in (home/'Documents').glob('backup249-*.png'):shutil.copy(path,evidence/f'{device}-{path.name}')
 assert len(rows)>=11 and all(row['passed'] for row in rows),rows
 print(device,'PASS',len(rows),'backup UI checks',flush=True)
