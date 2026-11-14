from pathlib import Path
import json,os,plistlib,subprocess,time
root=Path(__file__).resolve().parents[1];out=root/'build/document257-ui';app=out/'Document257.app';app.mkdir(parents=True,exist_ok=True)
def run(*args):return subprocess.check_output(list(map(str,args)),text=True).strip()
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable':'Document257','CFBundleIdentifier':'com.dylix.document257','CFBundleName':'Dylix 文件整理验证','CFBundleDisplayName':'Dylix 文件整理验证','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1','UIDeviceFamily':[1,2],'MinimumOSVersion':'15.0','UIFileSharingEnabled':True,'LSSupportsOpeningDocumentsInPlace':True,'UILaunchScreen':{}}))
run('xcrun','--sdk','iphonesimulator','clang','-target','arm64-apple-ios15.0-simulator','-fobjc-arc','-fblocks',root/'tests/DocumentPresentation257UI.m','-framework','UIKit','-framework','Foundation','-o',app/'Document257')
run('codesign','--force','--sign','-',app)
device=os.environ.get('DYLIX_TEST_DEVICE','A406534F-7D2B-4F72-AB5D-AC9AF178049C');run('xcrun','simctl','install',device,app);container=Path(run('xcrun','simctl','get_app_container',device,'com.dylix.document257','data'));result=container/'Library/document257-verification.json';result.unlink(missing_ok=True)
run('xcrun','simctl','launch','--terminate-running-process',device,'com.dylix.document257');end=time.monotonic()+30
while not result.exists() and time.monotonic()<end:time.sleep(.2)
assert result.exists(),'native fixture did not complete'
data=json.loads(result.read_text());assert data['nativeFixtureExitCode']==0 and data['nativeHiddenFilteringPassed'],data
(out/'verification.json').write_text(json.dumps(data,ensure_ascii=False,indent=2));run('xcrun','simctl','io',device,'screenshot',out/'root.png');print(json.dumps(data,ensure_ascii=False))
