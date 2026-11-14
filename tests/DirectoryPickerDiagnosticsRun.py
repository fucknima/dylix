from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-picker-identity-') as temp:
    binary = Path(temp) / 'test'
    sources = ['tests/DirectoryPickerDiagnosticsTests.m', 'App/AI/Attachments/TFAIDirectoryPickerDiagnostics.m', 'App/Incoming/TFShareGroups.m']
    subprocess.run(['xcrun', 'clang', '-isysroot', '/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk', '-fobjc-arc', '-fblocks', '-Wno-incompatible-pointer-types', *[str(root / p) for p in sources], '-framework', 'Foundation', '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
