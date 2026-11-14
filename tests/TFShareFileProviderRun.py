from pathlib import Path
import subprocess, tempfile, sys
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-share-provider-') as temp:
    binary = Path(temp) / 'test'
    sources = ['tests/TFShareFileProviderTests.m', 'ShareExtension/TFShareFileProvider.m', 'ShareExtension/TFShareFolderArchive.m', 'App/ArchiveImport.m', 'App/TheosMakefile.m']
    subprocess.run(['xcrun', 'clang', '-isysroot', '/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk', '-fobjc-arc', '-fblocks', '-Wno-incompatible-pointer-types', *[str(root / p) for p in sources], '-framework', 'Foundation', '-framework', 'UniformTypeIdentifiers', '-larchive', '-o', str(binary)], check=True)
    subprocess.run([str(binary), *sys.argv[1:]], check=True)
