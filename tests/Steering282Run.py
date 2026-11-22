import os
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-context-runtime-') as d:
    p=Path(d);(p/'UIKit').mkdir();(p/'WebKit').mkdir()
    (p/'UIKit/UIKit.h').write_text('#import <Foundation/Foundation.h>\n@class UIViewController;\nextern NSString *UIApplicationDidEnterBackgroundNotification;\n')
    (p/'WebKit/WebKit.h').write_text('#import <Foundation/Foundation.h>\n@class WKWebView;\n')
    files=['tests/Steering282Tests.m','App/AI/Core/TFAIContextProjection.m','App/AI/Core/TFAIRecovery.m','App/AI/Usage/TFAIUsageStore.m','App/AI/Providers/TFAIRegistry.m','App/AI/Registry/TFAIToolRegistry.m','App/AI/Persona/TFAIPersona.m','App/Remote/DXFlexBridge.m']
    binary=p/'tests'
    subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-I'+str(p),'-fobjc-arc','-fblocks','-Wno-incomplete-implementation','-Wno-nullability-completeness',*[str(root/f) for f in files],'-framework','Foundation','-o',str(binary)],check=True)
    subprocess.run([str(binary)],env={**os.environ,"DYLIX_USAGE_TEST_DIRECTORY":str(binary.parent/"usage")},check=True,timeout=60)
