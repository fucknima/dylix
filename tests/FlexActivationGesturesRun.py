"""Production recognizers + real UIKit events, with a test-only four-finger injector."""
from pathlib import Path
import argparse,json,plistlib,subprocess,tempfile,time,shutil
p=argparse.ArgumentParser();p.add_argument('--device',default='A406534F-7D2B-4F72-AB5D-AC9AF178049C');args=p.parse_args()
root=Path(__file__).resolve().parents[1];flex=root/'Plugins/FLEX';out=root/'build/flex-activation';out.mkdir(parents=True,exist_ok=True)
app=out/'FlexActivation.app';app.mkdir(exist_ok=True);bundle='app.dylix.tests.flex-activation'
(app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier=bundle,CFBundleExecutable='FlexActivation',CFBundleName='FlexActivation',CFBundlePackageType='APPL',CFBundleVersion='1',CFBundleShortVersionString='1.0',MinimumOSVersion='15.0',UIDeviceFamily=[1,2],UILaunchScreen={})))
# Only the test event injector allows 4 fingers; production AI gesture limits stay unchanged.
driver=(flex/'FLEXDylixTouchDriver.m').read_text();assert driver.count('paths.count>2')==1
driver=driver.replace('paths.count>2','paths.count>4');(out/'TestFourFingerInjector.m').write_text(driver)
def run(*cmd):
 r=subprocess.run([str(c) for c in cmd],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr);r.check_returncode()
 return r.stdout
run('xcrun','--sdk','iphonesimulator','clang','-target','arm64-apple-ios15.0-simulator','-fobjc-arc','-fblocks','-w','-I',flex,root/'tests/FlexActivationGestures.m',flex/'FLEXManager+ThreeFingerTap.m',flex/'UIGestureRecognizer+Blocks.m',out/'TestFourFingerInjector.m','-framework','UIKit','-framework','Foundation','-framework','CoreGraphics','-o',app/'FlexActivation')
run('codesign','--force','--sign','-',app);run('xcrun','simctl','install',args.device,app)
data=Path(run('xcrun','simctl','get_app_container',args.device,bundle,'data').strip());result=data/'Documents/activation-results.json';result.unlink(missing_ok=True)
run('xcrun','simctl','launch','--terminate-running-process',args.device,bundle);end=time.monotonic()+30
while not result.exists() and time.monotonic()<end:time.sleep(.2)
assert result.exists(),'gesture integration did not complete'
rows=json.loads(result.read_text());(out/(args.device+'-results.json')).write_text(json.dumps(rows,ensure_ascii=False,indent=2))
for r in rows:print(('PASS ' if r['passed'] else 'FAIL ')+r['name']+(' '+json.dumps(r,ensure_ascii=False) if not r['passed'] else ''))
assert all(r['passed'] for r in rows),'gesture integration failed'
