#!/usr/bin/env python3
"""Build standalone Linux/aarch64 ldid from the bundled matching source.
Requires macOS clang++ and DYLIX_LLD pointing to LLVM's ELF linker.
Dependencies are pinned by SHA256 in GuestTools/ldid.json. No host installation.
After rebuilding run fetch_ish_packages.py to regenerate the offline kit.
"""
import hashlib,json,os,subprocess,tarfile,tempfile
from pathlib import Path
from fetch_ish_packages import download
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'Resources/iSH/GuestTools';meta=json.loads((out/'ldid.json').read_text())
archive=out/'ldid-source.tar.gz'
if hashlib.sha256(archive.read_bytes()).hexdigest()!=meta['sourceArchiveSHA256']:raise SystemExit('ldid source hash mismatch')
linker=Path(os.environ.get('DYLIX_LLD','ld.lld'))
cache=Path('/tmp/dylix-alpine-official');cache.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='dylix-guest-ldid-') as folder:
 base=Path(folder);root=base/'sysroot';source=base/'source';root.mkdir();source.mkdir()
 for row in meta['buildDependencies']:
  path=cache/row['file'];download(row['url'],path)
  if hashlib.sha256(path.read_bytes()).hexdigest()!=row['sha256']:raise SystemExit('Pinned dependency hash mismatch: '+row['file'])
  with tarfile.open(path) as t:
   # Official, hash-pinned packages in a fresh disposable sysroot, never App data.
   t.extractall(root,members=[m for m in t if m.name.startswith(('usr/','lib/'))])
 with tarfile.open(archive) as t:t.extractall(source)
 src=next(source.glob('*/ldid.cpp'));cpp=root/'usr/include/c++/14.2.0';gcc=root/'usr/lib/gcc/aarch64-alpine-linux-musl/14.2.0'
 # Invoke the already trusted lld explicitly through a tiny driver; basename
 # selects ELF mode even when DYLIX_LLD names the generic lld executable.
 driver=base/'ld.lld';driver.write_text('#!/bin/sh\nexec '+"'"+str(linker.resolve()).replace("'","'\"'\"'")+"'"+' -flavor gnu "$@"\n');driver.chmod(0o755)
 cmd=['clang++','--target=aarch64-alpine-linux-musl','--sysroot='+str(root),'--ld-path='+str(driver),'-B'+str(gcc),'-L'+str(gcc),'-isystem',str(cpp),'-isystem',str(cpp/'aarch64-alpine-linux-musl'),'-isystem',str(cpp/'backward'),'-std=c++11','-O2','-Wno-deprecated-declarations','-DLDID_VERSION="'+meta['version']+'"',str(src),'-lcrypto','-lplist-2.0','-lstdc++','-o',str(out/'ldid')]
 subprocess.run(cmd,check=True)
 meta['sha256']=hashlib.sha256((out/'ldid').read_bytes()).hexdigest();(out/'ldid.json').write_text(json.dumps(meta,indent=2)+'\n')
 print('Built standalone guest ldid '+meta['sha256'])
