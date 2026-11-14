"""Verify real thin Mach-O CodeDirectory page hashes, not just LC presence."""
import hashlib,struct,sys
if sys.argv[1]=='--vfs':
 import ctypes,errno,os,stat
 libc=ctypes.CDLL(None,use_errno=True);libc.syscall.restype=ctypes.c_long
 def chmodat(fd,path,mode,flags):
  ctypes.set_errno(0);r=libc.syscall(452,fd,ctypes.c_char_p(path.encode()),mode,flags);return r,ctypes.get_errno()
 os.makedirs('/workspace/chmod228',exist_ok=True)
 fd=os.open('/workspace/chmod228',os.O_RDONLY)
 try:
  with open('/workspace/chmod228/item','w') as f:f.write('original')
  assert chmodat(fd,'item',0o640,0x100)[0]==0
  assert stat.S_IMODE(os.stat('/workspace/chmod228/item').st_mode)==0o640
  try:os.unlink('/workspace/chmod228/link')
  except FileNotFoundError:pass
  os.symlink('item','/workspace/chmod228/link')
  assert chmodat(fd,'link',0o777,0x100)[1]==errno.EOPNOTSUPP
  assert stat.S_IMODE(os.stat('/workspace/chmod228/item').st_mode)==0o640
  assert chmodat(fd,'item',0o777,0x800000)[1]==errno.EINVAL
  assert chmodat(fd,'missing',0o777,0x100)[1]==errno.ENOENT
  before=stat.S_IMODE(os.stat('/skills').st_mode)
  denied=chmodat(-100,'/skills',0o777,0x100)
  assert denied[0]==-1 and denied[1] in (errno.EROFS,errno.EPERM,errno.EACCES),denied
  assert stat.S_IMODE(os.stat('/skills').st_mode)==before
  assert chmodat(fd,'',0o750,0x1000)[0]==0
  assert stat.S_IMODE(os.fstat(fd).st_mode)==0o750
 finally:os.close(fd)
 print('FCHMODAT2_VFS_BOUNDARIES_OK');sys.exit(0)
b=open(sys.argv[1],'rb').read();assert b[:4]==b'\xcf\xfa\xed\xfe'
n=struct.unpack_from('<I',b,16)[0];at=32;signature=None
for _ in range(n):
 cmd,size=struct.unpack_from('<II',b,at);assert size>=8 and at+size<=len(b)
 if cmd==0x1d:signature=struct.unpack_from('<II',b,at+8)
 at+=size
if '--unsigned' in sys.argv:
 assert signature is None;print('UNSIGNED_CONFIRMED');sys.exit(0)
assert signature
start,length=signature;s=b[start:start+length];magic,total,count=struct.unpack_from('>III',s)
assert magic==0xfade0cc0 and total<=len(s);verified=0
for i in range(count):
 slot,offset=struct.unpack_from('>II',s,12+8*i)
 if slot not in (0,0x1000):continue
 cd=s[offset:];magic,size,version,flags,hashoff,ident,special,slots,limit=struct.unpack_from('>9I',cd)
 assert magic==0xfade0c02 and size<=len(cd) and limit<=start
 hashsize,hashtype,platform,page=struct.unpack_from('4B',cd,36);assert hashtype in (1,2,3) and page<=20
 algorithm=hashlib.sha1 if hashtype==1 else hashlib.sha256
 for j in range(slots):
  chunk=b[j*(1<<page):min((j+1)*(1<<page),limit)]
  assert algorithm(chunk).digest()[:hashsize]==cd[hashoff+j*hashsize:hashoff+(j+1)*hashsize]
 verified+=1
assert verified
print('CODEDIRECTORY_HASHES_VERIFIED',verified)
