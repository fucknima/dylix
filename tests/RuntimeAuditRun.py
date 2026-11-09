#!/usr/bin/env python3
"""Exercise production runtime pagination, install tracking, retention and redaction."""
from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
sdk=Path('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')
if not sdk.exists():sdk=Path(subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip())
with tempfile.TemporaryDirectory(prefix='dylix-runtime-audit-') as folder:
    exe=Path(folder)/'audit'
    files=['tests/RuntimeAuditTests.m','App/AI/Sandbox/TFAIISHRuntime.m','App/AI/Permissions/TFAIPolicy.m']
    subprocess.run(['xcrun','clang','-isysroot',str(sdk),'-fobjc-arc','-fblocks','-DDYLIX_HAS_ISH=0','-Wno-nullability-completeness',*[str(root/f) for f in files],'-framework','Foundation','-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,timeout=30)
