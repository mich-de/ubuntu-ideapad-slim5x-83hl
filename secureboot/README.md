# Secure Boot: "EFI USB Device boot failed" on the 83HL

**Symptom:** the Ubuntu stick is rejected by the firmware ("EFI USB Device (...) boot failed") with Secure Boot ON.
**Cause (verified):** the 83HL firmware `db` (BIOS PUCN55WW, latest) holds only *Windows Production PCA 2011* and
*Windows UEFI CA 2023*. It lacks **Microsoft Corporation UEFI CA 2011** (the "3rd party" CA), which signs shim.
This BIOS has **no "Allow 3rd party CA" option**, so the only way is to put the CA into `db` yourself.

> ⚠️ This rewrites firmware key variables. Tested **only on one 83HL**. If you get it wrong the machine can refuse to boot
> signed images until you use *Restore Factory Keys* in the BIOS. BitLocker: suspend/disable it first (key change
> changes the PCR 7 measurement). Keep the backups.

## Procedure (Windows on the laptop + any Linux/WSL with python3 and openssl)
1. **Back up** (PowerShell *as Administrator*, Secure Boot still ON): `secureboot\dump-keys.ps1` → `PK.bin KEK.bin db.bin dbx.bin`.
   Copy them somewhere safe (not only on this PC).
2. Get the two public Microsoft certificates (PEM or DER) from Microsoft's
   [secureboot_objects](https://github.com/microsoft/secureboot_objects) repository and check the SHA-256 fingerprint:
   - Microsoft Corporation UEFI CA 2011 — `48:E9:9B:99:1F:57:FC:52:F7:61:49:59:9B:FF:0A:58:C4:71:54:22:9B:9F:8D:60:3A:C4:0D:35:00:24:85:07`
   - Microsoft UEFI CA 2023 — `F6:12:4E:34:12:5B:EE:3F:E6:D7:9A:57:4E:AA:7B:91:C0:E7:BD:9D:92:9C:1A:32:11:78:EF:D6:11:DA:D9:01`
3. Build the new db (YOUR current db + the certs, duplicates skipped):
   `python3 secureboot/make-db-esl.py db.bin db-new.esl ca2011.crt ca2023.crt`
   (output is byte-identical to what worked on the author's machine when fed the same inputs).
4. BIOS → Security → Secure Boot → **Reset to Setup Mode** (wording varies: "Clear all keys"), F10, boot Windows.
5. PowerShell *as Administrator*, with `PK.bin KEK.bin dbx.bin db-new.esl` in the same folder:
   `secureboot\apply-keys.ps1` — it aborts unless SetupMode=1, restores dbx/KEK, writes db, restores the vendor PK **last**.
   Check `apply-log.txt`: `SetupMode now=0` and `db ok=True KEK ok=True PK ok=True`.
6. BIOS: re-enable Secure Boot. Boot the stick → shim → MokManager → **Enroll key from disk** → `MOK-83HL.der`.

## Gotchas found on the way
- The Qualcomm UEFI cannot read ISO9660: MokManager does not see the Ubuntu partition. The stick therefore carries
  `MOK-83HL.der` also on the FAT partition `83HL-LOG`.
- `microsoft/secureboot_objects` has no signed DB updates for 3rd-party CAs, so a signed online update is not an option here.
- Fallback if anything goes wrong: BIOS → *Restore Factory Keys*; your `*.bin` backups let you compare.
