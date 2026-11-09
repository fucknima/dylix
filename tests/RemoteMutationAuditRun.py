#!/usr/bin/env python3
"""Compile and test the exact production queued mutation method with fixture I/O."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'App/Remote/DXRemoteWorkspace.m').read_text()
start=source.index('- (void)mutate:')
end=source.index('- (void)input:',start)
sdk=Path('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')
if not sdk.exists():sdk=Path(subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip())
with tempfile.TemporaryDirectory(prefix='dylix-remote-mutation-') as folder:
    folder=Path(folder);exe=folder/'audit'
    (folder/'RemoteMutationProduction.inc').write_text(source[start:end])
    subprocess.run(['xcrun','clang','-isysroot',str(sdk),'-fobjc-arc','-fblocks','-Wno-nullability-completeness','-I'+str(folder),str(root/'tests/RemoteMutationAuditTests.m'),str(root/'App/AI/Permissions/TFAIPolicy.m'),'-framework','Foundation','-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,timeout=30)
