from pathlib import Path
import subprocess,tempfile,os
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-context270-') as d:
    binary=Path(d)/'tests'
    subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-fblocks','-Wno-incompatible-pointer-types',str(root/'tests/AgentContext270Tests.m'),str(root/'App/AI/Core/TFAIContextProjection.m'),str(root/'App/AI/Providers/TFAIRegistry.m'),'-framework','Foundation','-o',str(binary)],check=True)
    subprocess.run([str(binary)],env={**os.environ,'DYLIX_PROVIDER_RESOURCES':str(root/'Resources/AIProviders')},check=True,timeout=120)
