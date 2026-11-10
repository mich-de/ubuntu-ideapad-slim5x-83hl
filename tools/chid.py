#!/usr/bin/env python3
"""CHID come systemd-stub (src/fundamental/chid.c). Uso: chid.py 'Manuf|Family|Product|SKU|BBManuf|BBProduct' PANELID"""
import sys, hashlib, uuid
F = sys.argv[1].split('|'); panel = sys.argv[2] if len(sys.argv) > 2 else None
def norm(s):
    s = s.lstrip(' ').lstrip('0'); return s.rstrip(' ')
f = {0: norm(F[0]), 1: norm(F[1]), 2: norm(F[2]), 3: norm(F[3]), 4: norm(F[4]), 5: norm(F[5])}
if panel: f[11] = panel
T = {3:[0,1,2,3,4,5],4:[0,1,2,3],5:[0,1,2],6:[0,3,4,5],7:[0,3],8:[0,2,4,5],9:[0,2],10:[0,1,4,5],11:[0,1],13:[0,4,5],14:[0],
     'x0':[0,1,2,11],'x1':[0,1,11],'x2':[0,3,11]}
ns = uuid.UUID('70ffd812-4c7f-4c7d-0000-000000000000').bytes
for k, idx in T.items():
    if any(i not in f for i in idx): continue
    data = ns + '&'.join(f[i] for i in idx).encode('utf-16-le')
    print(k, uuid.UUID(bytes=hashlib.sha1(data).digest()[:16], version=5))
