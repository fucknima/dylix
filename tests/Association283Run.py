from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
env={**os.environ,'TOOLCHAINS':'com.apple.dt.toolchain.XcodeDefault'}
with tempfile.TemporaryDirectory(prefix='dylix-association283-') as d:
 p=Path(d);(p/'UIKit').mkdir();(p/'WebKit').mkdir()
 (p/'UIKit/UIKit.h').write_text('#import <Foundation/Foundation.h>\n@class UIViewController;\n')
 (p/'WebKit/WebKit.h').write_text('#import <Foundation/Foundation.h>\n@class WKWebView;\n')
 for name in ['Association283Tests','AIV2SessionsTests']:
  subprocess.run(['xcrun','clang','-fobjc-arc','-fblocks','-Wno-incompatible-pointer-types','-Wno-nullability-completeness','-I'+d,str(root/'tests'/f'{name}.m'),str(root/'App/AI/Sessions/TFAISessions.m'),str(root/'App/AI/Core/TFAIRecovery.m'),'-framework','Foundation','-o',d+'/test'],check=True,env=env)
  subprocess.run([d+'/test'],check=True,env=env,timeout=30)
