from pathlib import Path
import json,subprocess,time
root=Path(__file__).resolve().parents[1]
def run(*args):return subprocess.check_output([str(x) for x in args],text=True).strip()
info=json.loads(run('xcrun','simctl','list','devices','booted','--json'))
for d in [v for group in info['devices'].values() for v in group if 'iPhone' in v['name'] or 'iPad' in v['name']]:
    device=d['udid'];bundle='com.xuegao.theosmobilecompiler'
    run('xcrun','simctl','install',device,root/'build/simulator/TheosMobileCompiler.app')
    home=Path(run('xcrun','simctl','get_app_container',device,bundle,'data'))
    result=home/'Documents/session239-results.json';result.unlink(missing_ok=True)
    run('xcrun','simctl','launch','--terminate-running-process',device,bundle,'--session239')
    deadline=time.monotonic()+35
    while not result.exists() and time.monotonic()<deadline:time.sleep(.25)
    assert result.exists(),f'{d["name"]} integration timed out'
    rows=json.loads(result.read_text());print(d['name'],json.dumps(rows,ensure_ascii=False),flush=True)
    evidence=root/'build/data239-evidence';evidence.mkdir(exist_ok=True)
    (evidence/(device+'.json')).write_text(json.dumps(rows,ensure_ascii=False,indent=2))
    assert all(r['passed'] for r in rows),rows
