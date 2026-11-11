#!/usr/bin/python3 -I
"""Crea un archivio cpio newc non compresso da accodare all'initrd.
Uso: mkcpio.py <out.cpio> <dest-nel-cpio>=<file-sorgente> ...  (le directory padre vengono create)"""
import sys, os
out = open(sys.argv[1], 'wb'); ino = [1000]; dirs = set()
def entry(name, mode, data=b''):
    ino[0] += 1
    nb = name.encode() + b'\0'
    h = b'070701' + b''.join(b'%08X' % v for v in (ino[0], mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(nb), 0))
    out.write(h + nb); out.write(b'\0' * ((-(110 + len(nb))) % 4))
    out.write(data); out.write(b'\0' * ((-len(data)) % 4))
for arg in sys.argv[2:]:
    dest, src = arg.split('=', 1)
    parts = dest.split('/')
    for i in range(1, len(parts)):
        d = '/'.join(parts[:i])
        if d not in dirs: dirs.add(d); entry(d, 0o40755)
    entry(dest, 0o100644, open(src, 'rb').read())
entry('TRAILER!!!', 0)
out.write(b'\0' * ((-out.tell()) % 512)); out.close()
