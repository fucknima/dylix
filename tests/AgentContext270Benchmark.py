from pathlib import Path
import subprocess,tempfile,os
actual=Path(__file__).resolve().parents[1]
root=Path(os.environ.get('DYLIX_TEST_SOURCE_ROOT',str(actual)))
with tempfile.TemporaryDirectory(prefix='dylix-benchmark270-') as d:
    binary=Path(d)/'tests'
    subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-fblocks','-Wno-incompatible-pointer-types',str(root/'tests/AgentContext270Benchmark.m'),str(root/'App/AI/Core/TFAIContextProjection.m'),str(root/'App/AI/Providers/TFAIRegistry.m'),'-framework','Foundation','-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True,timeout=120)
