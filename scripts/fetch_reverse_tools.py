#!/usr/bin/env python3
"""Bundle official signed ARM64 radare2/Ghidra packages, isolated from base Alpine.
See reverse-tools.json for pinned URLs, hashes and license disclosures.
"""
import sys,tarfile,json,re,hashlib,concurrent.futures
from pathlib import Path
from fetch_ish_packages import download
base='https://dl-cdn.alpinelinux.org/alpine/edge/'
cache=Path('/tmp/dylix-alpine-reverse');cache.mkdir(exist_ok=True)
# Default is reproducible: restore the checked-in version, never silently move edge.
manifest_path=Path(__file__).resolve().parents[1]/'Resources/iSH/reverse-tools.json'
if manifest_path.exists() and '--refresh' not in sys.argv:
 manifest=json.loads(manifest_path.read_text());rows=manifest['packages']
 for row in rows:
  path=cache/row['file'];download(row['url'],path)
  if hashlib.sha256(path.read_bytes()).hexdigest()!=row['sha256']:
   raise SystemExit('Pinned package hash mismatch: '+row['file'])
 target=manifest_path.with_suffix('.tar');temporary=target.with_suffix('.tar.partial')
 with tarfile.open(temporary,'w') as archive:
  for row in rows:
   path=cache/row['file'];item=archive.gettarinfo(str(path),arcname='packages/'+row['file']);item.uid=item.gid=0;item.uname=item.gname='root';item.mtime=0
   with path.open('rb') as stream:archive.addfile(item,stream)
 if hashlib.sha256(temporary.read_bytes()).hexdigest()!=manifest['sha256']:
  temporary.unlink();raise SystemExit('Pinned archive hash mismatch')
 temporary.replace(target);print('Restored pinned reverse kit: '+manifest['sha256']);raise SystemExit(0)
pkgs={};provides={}
for repo in ['main','community','testing']:
 p=cache/(repo+'-APKINDEX.tar.gz');download(base+repo+'/aarch64/APKINDEX.tar.gz',p)
 with tarfile.open(p) as t:s=t.extractfile('APKINDEX').read().decode()
 for b in s.split('\n\n'):
  e=dict(l.split(':',1) for l in b.splitlines() if ':' in l)
  if 'P' not in e:continue
  e['repo']=repo;pkgs[e['P']]=e
  for v in e.get('p','').split():provides[re.split('[<>=~]',v)[0]]=e
selected={};todo=['r2ghidra','radare2']
while todo:
 name=re.split('[<>=~]',todo.pop())[0]
 if name.startswith('!'):continue
 p=pkgs.get(name) or provides.get(name)
 if not p:raise ValueError(name)
 if p['P'] in selected:continue
 selected[p['P']]=p;todo+=p.get('D','').split()
for name in ['radare2','r2ghidra']:
 if selected[name]['V']!='6.2.6-r0':raise SystemExit('Runtime adapter pins 6.2.6-r0; update and retest it before refreshing engine versions')
def fetch(p):
 name=p['P']+'-'+p['V']+'.apk';path=cache/name;url=base+p['repo']+'/aarch64/'+name;download(url,path)
 return dict(name=p['P'],version=p['V'],file=name,url=url,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bytes=path.stat().st_size,license=p.get('L',''),origin=p.get('o',p['P']),sourceCommit=p.get('c',''),sourceRecipe='https://gitlab.alpinelinux.org/alpine/aports/-/tree/'+p.get('c','master')+'/'+p['repo']+'/'+p.get('o',p['P']))
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(fetch,selected.values()))
rows.sort(key=lambda r:r['file']);out=Path(__file__).resolve().parents[1]/'Resources/iSH';target=out/'reverse-tools.tar'
with tarfile.open(target,'w') as tar:
 for r in rows:
  p=cache/r['file'];i=tar.gettarinfo(str(p),arcname='packages/'+r['file']);i.uid=i.gid=0;i.uname=i.gname='root';i.mtime=0
  with p.open('rb') as f:tar.addfile(i,f)
manifest=dict(repository=base,architecture='aarch64',tools=['radare2','r2ghidra'],signatureVerification='Official Alpine APK signatures required',sha256=hashlib.sha256(target.read_bytes()).hexdigest(),packages=rows)
(out/'reverse-tools.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest,indent=2))
