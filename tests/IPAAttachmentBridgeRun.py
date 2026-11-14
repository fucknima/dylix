from pathlib import Path
import subprocess,tempfile,os
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-ipa-bridge-') as work:
 p=Path(work);home=p/'home';home.mkdir();exe=p/'test'
 subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-fblocks','-Wno-incompatible-pointer-types','-Wno-deprecated-declarations',str(root/'tests/IPAAttachmentBridgeTests.m'),str(root/'App/AI/Attachments/TFAIDirectoryAccess.m'),str(root/'App/AI/ClassDump/TFAIClassDumpExecution.m'),'-framework','Foundation','-o',str(exe)],check=True)
 subprocess.run([str(exe),str(p/'fixtures')],env={**os.environ,'CFFIXED_USER_HOME':str(home)},check=True,timeout=30)
