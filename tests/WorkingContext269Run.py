from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-working269-') as d:
    binary=Path(d)/'tests'
    subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-fblocks','-Wno-incompatible-pointer-types',str(root/'tests/WorkingContext269Tests.m'),'-framework','Foundation','-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
