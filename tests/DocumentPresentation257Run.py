from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='tf-document-layout-') as work:
    binary=Path(work)/'tests'
    subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-fblocks','-Wno-incompatible-pointer-types',str(root/'tests/DocumentPresentation257Tests.m'),'-framework','Foundation','-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
