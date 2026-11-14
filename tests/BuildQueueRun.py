from pathlib import Path
import subprocess,tempfile,os
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-queue-') as folder:
 p=Path(folder);(p/'UIKit').mkdir();(p/'UIKit/UIKit.h').write_text('#import <Foundation/Foundation.h>\n@class UIViewController;\n')
 exe=p/'tests';home=p/'home';home.mkdir()
 subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-I'+str(p),'-fobjc-arc','-fblocks','-Wno-incomplete-implementation',str(root/'tests/BuildQueueTests.m'),'-framework','Foundation','-o',str(exe)],check=True)
 subprocess.run([str(exe)],env={**os.environ,'CFFIXED_USER_HOME':str(home)},check=True,timeout=20)
