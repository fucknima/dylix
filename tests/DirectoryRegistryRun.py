from pathlib import Path
import subprocess,tempfile,os
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-directory-') as folder:
 exe=Path(folder)/'test';home=Path(folder)/'home';home.mkdir()
 subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-fblocks','-Wno-nullability-completeness',str(root/'App/AI/Attachments/TFAIDirectoryRegistry.m'),str(root/'App/AI/Attachments/TFAIDirectoryAccess.m'),str(root/'tests/DirectoryRegistryTests.m'),'-framework','Foundation','-o',str(exe)],check=True)
 # CFFIXED_USER_HOME isolates AppSupport without changing HOME.
 subprocess.run([str(exe),str(Path(folder)/'folders')],env={**os.environ,'CFFIXED_USER_HOME':str(home)},check=True)
