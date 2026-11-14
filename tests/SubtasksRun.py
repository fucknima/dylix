from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-subtasks-') as folder:
 exe=Path(folder)/'test'
 subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-fblocks',str(root/'App/AI/Agent/TFAISubtasks.m'),str(root/'tests/SubtasksTests.m'),'-framework','Foundation','-o',str(exe)],check=True)
 subprocess.run([str(exe),str(Path(folder)/'tasks.json')],check=True)
