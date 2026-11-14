import os
from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
sdk=Path('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')
sdk=str(sdk) if sdk.exists() else subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
with tempfile.TemporaryDirectory(prefix='tf-runtime-budget-') as temp:
    temp=Path(temp);(temp/'UIKit').mkdir()
    (temp/'UIKit/UIKit.h').write_text('#import <Foundation/Foundation.h>\n@class UIViewController;\nextern NSString *UIApplicationDidEnterBackgroundNotification;\n')
    (temp/'WebKit').mkdir();(temp/'WebKit/WebKit.h').write_text('#import <Foundation/Foundation.h>\n@class WKWebView;\n')
    binary=temp/'tests'
    wrapper=temp/'runner.m'
    wrapper.write_text('#define main BudgetFixtureMain\n#import '+chr(34)+str(root/'tests/RunContinuity251Tests.m')+chr(34)+'\n#undef main\nint main(){@autoreleasepool{dispatch_semaphore_t done=dispatch_semaphore_create(0);__block int code=1;NSThread *worker=[[NSThread alloc]initWithBlock:^{code=BudgetFixtureMain();dispatch_semaphore_signal(done);}];worker.stackSize=64*1024*1024;[worker start];return dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,120*NSEC_PER_SEC))?2:code;}}\n')
    subprocess.run(['xcrun','clang','-isysroot',sdk,'-I'+str(temp),'-fobjc-arc','-fblocks','-Wno-incomplete-implementation','-Wno-nullability-completeness',str(wrapper),str(root/'App/AI/Core/TFAIRecovery.m'),str(root/'App/AI/Usage/TFAIUsageStore.m'),str(root/'App/AI/Providers/TFAIRegistry.m'),str(root/'App/AI/Core/TFAIContextProjection.m'),str(root/'App/AI/Registry/TFAIToolRegistry.m'),str(root/'App/AI/Persona/TFAIPersona.m'),str(root/'App/Remote/DXFlexBridge.m'),'-framework','Foundation','-o',str(binary)],check=True)
    # Large-stack worker accommodates synchronous fixture callbacks for 1,200 tools.
    subprocess.run([str(binary)],check=True)
