from pathlib import Path
import tempfile, subprocess, zipfile, json
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='session239-') as temp:
    work=Path(temp); binary=work/'tests'
    subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk','-fobjc-arc','-fblocks','-Wno-incompatible-pointer-types',str(root/'tests/SessionArchive239Tests.m'),str(root/'App/AI/Sessions/TFAISessionArchive.m'),'-framework','Foundation','-larchive','-o',str(binary)],check=True)
    bad=[]
    for idx, entries in enumerate([
        {'../escape':'bad'},
        {'resources/Library/Preferences/settings.plist':'bad'},
        {'session.json':json.dumps({'messages':['bad']})},
    ]):
        p=work/f'bad{idx}.zip'
        with zipfile.ZipFile(p,'w') as z:
            z.writestr('DylixSession.json',json.dumps({'format':'dylix-session/1'}))
            if 'session.json' not in entries:z.writestr('session.json',json.dumps({'messages':[]}))
            for k,v in entries.items():z.writestr(k,v)
        bad.append(str(p))
    subprocess.run([str(binary),str(work),*bad],check=True,timeout=30)
