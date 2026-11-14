from pathlib import Path
import subprocess,plistlib,time,json
r=Path(__file__).resolve().parents[1];out=r/'build/update264';app=out/'UpdateProof.app';app.mkdir(parents=True,exist_ok=True)
def run(*a):return subprocess.check_output(list(map(str,a)),text=True).strip()
(app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleExecutable='UpdateProof',CFBundleIdentifier='com.dylix.updateproof264',CFBundleName='UpdateProof',CFBundlePackageType='APPL',CFBundleVersion='1',CFBundleShortVersionString='1.1.2',MinimumOSVersion='15.0',UIDeviceFamily=[1,2],UILaunchScreen={})))
run('xcrun','--sdk','iphonesimulator','clang','-target','arm64-apple-ios15.0-simulator','-fobjc-arc',r/'tests/AppUpdate264UI.m',r/'App/AI/Resources/DXAppUpdate.m',r/'App/AI/Resources/DXAppUpdateUI.m','-framework','UIKit','-framework','Foundation','-framework','WebKit','-framework','CoreGraphics','-o',app/'UpdateProof')
run('codesign','--force','--sign','-',app)
for device in ['A406534F-7D2B-4F72-AB5D-AC9AF178049C','740A5459-AA5D-4F93-BBC6-94FB9F8809C1']:
 run('xcrun','simctl','install',device,app);home=Path(run('xcrun','simctl','get_app_container',device,'com.dylix.updateproof264','data'))
 for phase in ['initial','restore']:
  result=home/'Documents'/f'{phase}.json';result.unlink(missing_ok=True)
  run('xcrun','simctl','launch','--terminate-running-process',device,'com.dylix.updateproof264',phase)
  deadline=time.monotonic()+25
  while not result.exists() and time.monotonic()<deadline:time.sleep(.2)
  assert result.exists(),(device,phase,'timeout')
  rows=json.loads(result.read_text());(out/f'{device}-{phase}.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));print(device,phase,rows,flush=True);assert rows and all(x['passed'] for x in rows)
 run('xcrun','simctl','io',device,'screenshot',out/f'{device}.png')
