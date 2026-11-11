#!/usr/bin/env python3
"""Build a new Secure Boot 'db' ESL = your CURRENT db + extra X.509 certificates (skipping ones already present).

Usage: make-db-esl.py db.bin out-db-new.esl cert1.crt [cert2.crt ...]
  db.bin  : raw content of your firmware db (see secureboot/dump-keys.ps1)
  certs   : PEM or DER, e.g. Microsoft UEFI CA 2011 (3rd party) and 2023
The result is only written to a file; nothing touches the firmware here.
"""
import subprocess, struct, sys, uuid

X509 = uuid.UUID("a5c059a1-94e4-4aa7-87b5-ab155c2bf072").bytes_le
OWNER = uuid.UUID("77fa9abd-0359-4d32-bd60-28f4e78f784b").bytes_le   # Microsoft owner GUID

def to_der(path):
    raw = open(path, "rb").read()
    if raw.lstrip().startswith(b"-----BEGIN"):
        return subprocess.run(["openssl", "x509", "-outform", "DER"], input=raw, capture_output=True, check=True).stdout
    return raw

def existing_certs(db):
    out, i = set(), 0
    while i + 28 <= len(db):
        sig_type, lsize, hsize, ssize = db[i:i+16], *struct.unpack_from("<III", db, i + 16)
        if lsize < 28: break
        if sig_type == X509:
            p = i + 28 + hsize
            while p + ssize <= i + lsize:
                out.add(bytes(db[p+16:p+ssize])); p += ssize
        i += lsize
    return out

def esl(der):
    ssize = 16 + len(der)
    return X509 + struct.pack("<III", 28 + ssize, 0, ssize) + OWNER + der

def main():
    if len(sys.argv) < 4: sys.exit(__doc__)
    db = open(sys.argv[1], "rb").read()
    have, new = existing_certs(db), b""
    for c in sys.argv[3:]:
        der = to_der(c)
        if der in have: print("gia' presente:", c); continue
        new += esl(der); have.add(der); print("aggiunto:", c)
    open(sys.argv[2], "wb").write(db + new)

main()
