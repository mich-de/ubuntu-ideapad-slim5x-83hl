#!/usr/bin/env python3
"""Elenca i nodi di un DTB senza driver nel kernel. Uso: dtb-compat-check.py drv_compat.txt file.dtb [rif.dtb]
Con rif.dtb mostra solo i compatible mancanti NON presenti anche nel riferimento (che sul kernel funziona)."""
import sys, re, subprocess
def missing(dtb, drv):
    out = subprocess.run(['fdtdump', dtb], capture_output=True, text=True).stdout
    path, res = [], {}
    for line in out.splitlines():
        s = line.strip()
        if s.endswith('{'): path.append(s[:-1].strip())
        elif s.startswith('};'):
            if path: path.pop()
        elif s.startswith('compatible = '):
            c = re.findall(r'"([^"]+)"', s)
            if not any(x in drv for x in c): res[c[0]] = '/'.join(path[1:])
    return res
drv = set(open(sys.argv[1]).read().split())
m = missing(sys.argv[2], drv)
ref = set(missing(sys.argv[3], drv)) if len(sys.argv) > 3 else set()
for c, p in sorted(m.items()):
    if c not in ref: print(f'{c:45s} {p}')
