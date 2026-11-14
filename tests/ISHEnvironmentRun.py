from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-environment-') as temp:
    binary=Path(temp)/'tests'
    subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-fblocks','-Wno-incompatible-pointer-types',str(root/'tests/ISHEnvironmentTests.m'),str(root/'App/AI/Sandbox/TFAIISHEnvironment.m'),'-framework','Foundation','-lsqlite3','-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True,timeout=60)
