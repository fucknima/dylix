from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-update250-') as tmp:
 exe=Path(tmp)/'test';html=Path(tmp)/'homepage.html'
 subprocess.run(['curl','--fail','--max-time','25','-s','https://dylib.cn/','-o',str(html)],check=True)
 subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-framework','Foundation',str(r/'tests/AppUpdate250Tests.m'),str(r/'App/AI/Resources/DXAppUpdate.m'),'-o',str(exe)],check=True)
 subprocess.run([str(exe),str(html)],check=True,timeout=40)
