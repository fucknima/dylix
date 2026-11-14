"""Verify the lean deliverable, pinned website payloads and offline SDK extraction."""
from pathlib import Path
import hashlib
import json
import plistlib
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()

def run(*args):
    return subprocess.check_output(list(map(str, args)), text=True).strip()

ipa = ROOT / 'build/Dylix-1.1.1-build247-unsigned.ipa'
app = ROOT / 'build/device/TheosMobileCompiler.app'
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert not any(name.endswith(('developer-tools.tar', 'reverse-tools.tar', '/SDK26.zip')) or '/GuestTools/' in name for name in names)
    for required in ['SDK.zip', 'SDKResource.plist', 'SDK26Resource.plist', 'DownloadResources.json']:
        assert f'Payload/TheosMobileCompiler.app/{required}' in names, required
    info = plistlib.loads(archive.read('Payload/TheosMobileCompiler.app/Info.plist'))
    assert info['CFBundleShortVersionString'] == '1.1.1'
    assert str(info['CFBundleVersion']) == '247'
    assert info['DTSDKName'] == 'iphoneos26.0'

catalog = json.loads((ROOT / 'Resources/DownloadResources.json').read_text())
assert json.loads((app / 'DownloadResources.json').read_text()) == catalog
for entry in catalog:
    path = ROOT / 'build/website-resources247/downloads/dylix/v1' / entry['file']
    assert path.stat().st_size == entry['bytes']
    assert digest(path) == entry['sha256']

with tempfile.TemporaryDirectory(prefix='dylix247-sdk-') as temporary:
    tmp = Path(temporary)
    exe = tmp / 'sdk'
    sdk = '/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk'
    if not Path(sdk).exists():
        sdk = run('xcrun', '--sdk', 'macosx', '--show-sdk-path')
    run('xcrun', 'clang', '-isysroot', sdk, '-fobjc-arc', '-framework', 'Foundation', '-larchive',
        ROOT/'tests/SDKResourcesHarness.m', ROOT/'App/SDKResources.m',
        ROOT/'App/AI/Resources/DXResourceStore.m', ROOT/'App/ArchiveImport.m',
        ROOT/'App/TheosMakefile.m', '-o', exe)
    path = Path(run(exe, app, tmp/'cache'))
    assert (path/'usr/include/stdio.h').is_file()
    marker = path/'.complete'
    before = marker.stat().st_mtime_ns
    assert run(exe, app, tmp/'cache') == str(path)
    assert marker.stat().st_mtime_ns == before

run('codesign', '--verify', '--deep', '--strict', app)
previous = ROOT / 'build/Dylix-1.1.1-build246-unsigned.ipa'
result = dict(passed=True, build=247, version='1.1.1', sdk=info['DTSDKName'],
              ipaBytes=ipa.stat().st_size, ipaSHA256=digest(ipa),
              previousIPABytes=previous.stat().st_size,
              reductionPercent=round(100*(1-ipa.stat().st_size/previous.stat().st_size), 2),
              optionalPayloadsAbsent=True, stagedHashesVerified=3,
              offlineSDK164Extraction=True, offlineSDKCacheReuse=True,
              codesignVerification=True, productionWebsiteDeployed=False)
output = ROOT / 'build/data247-evidence/verification.json'
output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(result, ensure_ascii=False, indent=2))
