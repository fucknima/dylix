from pathlib import Path
import argparse,subprocess,time,json,shutil
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--device',action='append',required=True);args=p.parse_args()
def run(*a):return subprocess.check_output(list(map(str,a)),text=True).strip()
for device in args.device:
 bundle='com.xuegao.theosmobilecompiler';run('xcrun','simctl','install',device,root/'build/simulator/TheosMobileCompiler.app');home=Path(run('xcrun','simctl','get_app_container',device,bundle,'data'));result=home/'Documents/storage258-results.json';result.unlink(missing_ok=True);run('xcrun','simctl','launch','--terminate-running-process',device,bundle,'--storage258-test');end=time.monotonic()+125
 while not result.exists() and time.monotonic()<end:time.sleep(.2)
 assert result.exists(),'UI regression timeout'
 rows=json.loads(result.read_text());out=root/'build/storage258';out.mkdir(exist_ok=True);shutil.copy2(result,out/(device+'-results.json'))
 for image in (home/'Documents').glob('storage258-*.png'):shutil.copy2(image,out/(device+'-'+image.name))
 print(json.dumps({'device':device,'checks':len(rows),'failures':[x for x in rows if not x['passed']]},ensure_ascii=False),flush=True);assert all(x['passed'] for x in rows)
