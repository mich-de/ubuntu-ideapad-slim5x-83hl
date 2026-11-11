# handover.md
## Stato
ISO pronta: out/ubuntu-26.04.1-83hl-arm64.iso (copia in C:\Users\mich-de\Downloads), sha256 5ba01e84…a8.
Build riproducibile: ./build-iso.sh (usa build-dtb.sh, tools/extract-firmware.sh, overlay/, overlay-iso/, debs/, keys/).
Verificato offline: firma MOK del UKI, SBAT, hwids, md5 ISO, partizioni (ESP + 83HL-LOG FAT32), fix UCM nello strato live.
NON verificato: boot reale (impossibile da WSL).
## Prossimi passi (utente)
1. BIOS: Secure Boot ON + abilitare "Allow Microsoft 3rd Party UEFI CA".
2. Rufus (ARM64) in modalità DD sulla chiavetta.
3. F12 → USB → voce "Registra chiave 83HL" → Enroll key from disk → MOK-83HL.der → reboot.
4. Voce "Ubuntu 83HL" → terminale `sudo 83hl-test` → report su partizione 83HL-LOG → leggerlo da Windows.
5. Se ok: installare, poi PRIMA del riavvio `sudo /cdrom/83hl/83hl-install-target` (mokutil chiede password → MokManager al riavvio).
## Aggiornamento 22:55
ISO v2 (f016abdd…7752): + decodifica video HW (iris) + driver EC ventola (disattivato di default) + DTB con nodo EC.
Build: ./build-video.sh (moduli) poi ./build-iso.sh. Chiavetta SanDisk riscritta con v2.
## Problemi aperti
Audio/luminosità/SD/suspend da confermare col report. Rossi (NPU, sensori, EC ventola) fuori portata.

## 2026-11-11
- Chiavetta rifiutata da Secure Boot: db senza Microsoft UEFI CA 2011. BIOS PUCN55WW ultimo, senza toggle 3rd party.
- Pronto `backup/secureboot-orig/83hl-sb-apply.ps1` (da usare in Setup Mode). In attesa voci menu Secure Boot. Dettagli in HANDOFF.md §0 e §6.0.
- 2026-11-11 ~02:00: ISO v5 sulla chiavetta, avvio OK con Secure Boot. Funzionano ADSP/CDSP, audio (scheda), batteria, USB-C,
  GPU fw. Aperti: NPU (fastrpc CDSP endpoint), video HW (moduli resettano il PC, in blacklist), verifica 3D/audio reali, EC.
  Dettagli e ipotesi: HANDOFF.md §0d.
- 2026-11-11 02:18: ISO v6 (sha256 2cf70118…c403) scritta e verificata sulla chiavetta. Contiene: fix DTB iris (iommus sul nodo
  principale, non provato su hardware, blacklist video ancora attiva), `83hl-risky-test npu` (riavvio CDSP tardivo + diagnostica),
  test 3D corretto, fix ldconfig in 83hl-npu-setup. Resta: test utente (83hl-test, risky-test npu/video/ec, audio a orecchio),
  poi togliere blacklist video se ok, fix permanente NPU, installazione, push GitHub (con conferma). Dettagli: HANDOFF.md §0e.
- 2026-11-11 02:45: test v6: video e 3D OK, NPU KO (problema upstream fastrpc#405), EC 0x76 inesistente (EC Lenovo a 0x60).
  ISO v7 in costruzione (blacklist video tolta, EC rimosso). Resta: scrivere chiavetta, test filmato/audio, installazione, GitHub.
- 2026-11-11 03:15: ISO v9 pronta (sha256 77e45066…75e4), NON scritta su chiavetta: l'utente vuole conferma esplicita. Contiene driver EC Lenovo (sola lettura) e modulo cdsp-keepalive (voti Windows per il CDSP), entrambi non provati su hardware. Dettagli HANDOFF.md §0h.
- 2026-11-11: audio confermato funzionante dall'utente. Aperti solo NPU ed EC (da provare con la v9).
- 2026-11-11 02:52: ISO v9 scritta e verificata sulla chiavetta. In attesa dei test utente (EC e NPU).
- 2026-11-11 09:46: ISO v10 sulla chiavetta (verificata). Il 'comando non trovato' della v9 era dovuto allo stacco della chiavetta per montare 83HL-LOG; ora `sudo 83hl-finale` fa tutto senza staccarla. In attesa del report.

## Prova v10 (11/11/2026)
Vedi HANDOFF.md §0j: tutto OK tranne NPU (KO, test falso positivo, voti keepalive mai provati), EC (legge zeri), standby mai provato. Prossimo: installazione su SSD e debug da Ubuntu.

- 11/11: creati 25 GB non allocati su SSD interno per installare Ubuntu (vedi HANDOFF §0k).
