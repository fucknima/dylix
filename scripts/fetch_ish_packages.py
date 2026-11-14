#!/usr/bin/env python3
"""Prepare an optional OFFICIAL, signed Alpine developer-tool kit.

Official APKs plus the separately built standalone ldid with matching source.
No third-party mirrors, installers, or host command execution by the guest.
The guest apk manager must still verify every package signature at install time.
"""
import argparse,concurrent.futures,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE='https://dl-cdn.alpinelinux.org/alpine/v3.21/'
TOOLS=['python3','py3-pip','nodejs','npm','git','curl','binutils','file','make','patch','tar','xz','zip','unzip','dpkg','llvm19','libplist','bash']
def download(url,path):
 if path.is_file() and path.stat().st_size:return
 temporary=path.with_suffix(path.suffix+'.partial')
 subprocess.run(['curl','--fail','--location','--retry','3','--connect-timeout','20','--max-time','900','--continue-at','-','--silent','--show-error',url,'-o',str(temporary)],check=True)
 temporary.replace(path)
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--cache',type=Path,default=Path('/tmp/dylix-alpine-official'));args=parser.parse_args();args.cache.mkdir(parents=True,exist_ok=True)
 packages={};providers={}
 for repo in ['main','community']:
  index=args.cache/(repo+'-APKINDEX.tar.gz');download(BASE+repo+'/aarch64/APKINDEX.tar.gz',index)
  with tarfile.open(index) as archive:text=archive.extractfile('APKINDEX').read().decode()
  for block in text.split('\n\n'):
   entry=dict(line.split(':',1) for line in block.splitlines() if ':' in line)
   if not entry.get('P'):continue
   entry['repo']=repo;packages[entry['P']]=entry
   for provide in entry.get('p','').split():providers.setdefault(re.split(r'[<>=~]',provide)[0],entry)
 selected={};pending=list(TOOLS)
 while pending:
  dep=pending.pop();dep=re.split(r'[<>=~]',dep)[0]
  if dep.startswith('!'):continue
  pkg=packages.get(dep) or providers.get(dep)
  if not pkg:raise RuntimeError('No official provider for '+dep)
  if pkg['P'] in selected:continue
  selected[pkg['P']]=pkg;pending.extend(pkg.get('D','').split())
 def fetch(pkg):
  name=pkg['P']+'-'+pkg['V']+'.apk';path=args.cache/name;download(BASE+pkg['repo']+'/aarch64/'+name,path)
  return {'name':pkg['P'],'version':pkg['V'],'file':name,'url':BASE+pkg['repo']+'/aarch64/'+name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'license':pkg.get('L',''),'origin':pkg.get('o',pkg['P'])}
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(fetch,selected.values()))
 rows.sort(key=lambda r:r['file']);out=ROOT/'Resources/iSH';out.mkdir(parents=True,exist_ok=True);target=out/'developer-tools.tar'
 with tarfile.open(target,'w') as archive:
  for row in rows:
   info=archive.gettarinfo(str(args.cache/row['file']),arcname='packages/'+row['file']);info.uid=info.gid=0;info.uname=info.gname='root';info.mtime=0
   with (args.cache/row['file']).open('rb') as stream:archive.addfile(info,stream)
  guest=out/'GuestTools/ldid';meta=json.loads((out/'GuestTools/ldid.json').read_text())
  if hashlib.sha256(guest.read_bytes()).hexdigest()!=meta['sha256']:raise RuntimeError('Guest ldid checksum mismatch; run scripts/build_guest_ldid.py')
  item=archive.gettarinfo(str(guest),arcname='bin/ldid');item.uid=item.gid=0;item.uname=item.gname='root';item.mode=0o755;item.mtime=0
  with guest.open('rb') as stream:archive.addfile(item,stream)
 manifest={'repository':BASE,'architecture':'aarch64','tools':TOOLS,'signatureVerification':'Alpine apk verification required; never --allow-untrusted','sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'packages':rows,'guestTools':{'ldid':meta},'aliases':{'lipo':'llvm-lipo','otool':'llvm-otool','nm':'llvm-nm'}}
 (out/'developer-tools.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'packages':len(rows),'archive_bytes':target.stat().st_size,'sha256':manifest['sha256']}))
if __name__=='__main__':main()
