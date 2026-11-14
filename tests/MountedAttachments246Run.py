"""Exercise mounted attachments in the already-built production simulator App."""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import time

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--device', action='append', required=True)
args = parser.parse_args()

def run(*argv):
    return subprocess.check_output([str(x) for x in argv], text=True).strip()

for device in args.device:
    bundle = 'com.xuegao.theosmobilecompiler'
    run('xcrun', 'simctl', 'install', device, root / 'build/simulator/TheosMobileCompiler.app')
    documents = Path(run('xcrun', 'simctl', 'get_app_container', device, bundle, 'data')) / 'Documents'
    result = documents / 'mounted246-results.json'
    result.unlink(missing_ok=True)
    run('xcrun', 'simctl', 'launch', '--terminate-running-process', device, bundle, '--session239', '--mounted246')
    deadline = time.monotonic() + 35
    while not result.exists() and time.monotonic() < deadline:
        time.sleep(.25)
    assert result.exists(), f'{device}: mounted attachment integration timed out'
    rows = json.loads(result.read_text())
    evidence = root / 'build/data246-evidence'
    evidence.mkdir(exist_ok=True)
    shutil.copy(result, evidence / f'{device}.json')
    shutil.copy(documents / 'data246-single-file.png', evidence / f'{device}-single-file.png')
    shutil.copy(documents / 'data248-attachment-menu.png', evidence / f'{device}-attachment-menu248.png')
    assert len(rows) == 13 and all(row['passed'] for row in rows), rows
    print(f'{device}: PASS {len(rows)} mounted attachment integration checks')
