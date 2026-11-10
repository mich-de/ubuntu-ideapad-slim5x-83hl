#!/usr/bin/env python3
# Legge uno zip remoto via HTTP Range: list / extract di membri selezionati (regex).
import sys,io,re,zipfile,urllib.request,os
class R(io.RawIOBase):
    def __init__(s,url):
        s.url=url; s.pos=0
        q=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0','Range':'bytes=0-0'})
        with urllib.request.urlopen(q,timeout=60) as r:
            s.url=r.geturl(); s.size=int(r.headers['Content-Range'].split('/')[1])
    def seekable(s): return True
    def readable(s): return True
    def tell(s): return s.pos
    def seek(s,o,w=0):
        s.pos = o if w==0 else s.pos+o if w==1 else s.size+o; return s.pos
    def readinto(s,b):
        n=min(len(b),s.size-s.pos)
        if n<=0: return 0
        q=urllib.request.Request(s.url,headers={'User-Agent':'Mozilla/5.0','Range':'bytes=%d-%d'%(s.pos,s.pos+n-1)})
        for k in range(8):
            try:
                with urllib.request.urlopen(q,timeout=300) as r: d=r.read()
                break
            except Exception as e:
                import time; time.sleep(3)
                if k==7: raise
        b[:len(d)]=d; s.pos+=len(d); return len(d)
url,cmd=sys.argv[1],sys.argv[2]
z=zipfile.ZipFile(io.BufferedReader(R(url),buffer_size=4<<20))
if cmd=='list':
    for i in z.infolist(): print(i.file_size,i.filename)
else:
    rx=re.compile(sys.argv[3]); out=sys.argv[4]
    for i in z.infolist():
        if rx.search(i.filename) and not i.is_dir():
            p=os.path.join(out,i.filename)
            if os.path.exists(p) and os.path.getsize(p)==i.file_size: continue
            os.makedirs(os.path.dirname(p),exist_ok=True)
            with z.open(i) as f, open(p,'wb') as o:
                while (d:=f.read(4<<20)): o.write(d)
            if (i.external_attr>>16)&0o111: os.chmod(p,0o755)
            print(i.file_size,i.filename)
