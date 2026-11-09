import os,sys
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
sdk=Path('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')
sdk=str(sdk) if sdk.exists() else subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
with tempfile.TemporaryDirectory(prefix='dylix-persona-runtime-') as folder:
 p=Path(folder);(p/'UIKit').mkdir();(p/'UIKit/UIKit.h').write_text('#import <Foundation/Foundation.h>\n@class UIViewController;\nextern NSString *UIApplicationDidEnterBackgroundNotification;\n');(p/'WebKit').mkdir();(p/'WebKit/WebKit.h').write_text('#import <Foundation/Foundation.h>\n@class WKWebView;\n');exe=p/'test'
 subprocess.run(['xcrun','clang','-isysroot',sdk,'-I'+str(p),'-fobjc-arc','-fblocks','-Wno-incomplete-implementation','-Wno-nullability-completeness',str(root/'tests'/(sys.argv[1] if len(sys.argv)>1 else 'AgentRuntimeTests.m')),str(root/'App/AI/Persona/TFAIPersona.m'),str(root/'App/AI/Core/TFAIRecovery.m'),str(root/'App/AI/Usage/TFAIUsageStore.m'),str(root/'App/AI/Providers/TFAIRegistry.m'),str(root/'App/AI/Core/TFAIContextProjection.m'),str(root/'App/Remote/DXFlexBridge.m'),str(root/'App/AI/Registry/TFAIToolRegistry.m'),'-framework','Foundation','-o',str(exe)],check=True)
 subprocess.run([str(exe)],env={**os.environ,"DYLIX_USAGE_TEST_DIRECTORY":str(exe.parent/"usage")},check=True,timeout=30)
