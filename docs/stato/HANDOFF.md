# HANDOFF — Ubuntu 26.04 su Lenovo IdeaPad Slim 5x 14Q8X9 (83HL), Secure Boot ON

## 1. Obiettivo sessione
Far funzionare Ubuntu 26.04.1 arm64 sul laptop dell'utente (Snapdragon X Plus X1P42100, pannello LCD) con
**Secure Boot sempre attivo**, massimo supporto periferiche, chiavetta live+installazione pronta, e pubblicare
studio e driver su GitHub per la community.


## 0. AGGIORNAMENTO 2026-11-11 (priorità)
- Chiavetta: firmware dice "EFI USB Device (SanDisk) boot failed". Causa verificata: db contiene solo Windows PCA 2011 +
  Windows UEFI CA 2023, manca Microsoft UEFI CA 2011 (3rd party). BIOS PUCN55WW = ultimo, nessuna voce "3rd Party CA".
- Soluzione scelta (opzione 2): BIOS → Reset to Setup Mode → da Windows admin eseguire
  `backup/secureboot-orig/83hl-sb-apply.ps1` (db = originale + UEFI CA 2011 + 2023, ripristina KEK/dbx se cancellati,
  PK Lenovo per ultima). Backup chiavi originali nella stessa cartella. BitLocker spento. Fallback: "Restore Factory Keys".
- 2026-11-11: MOK registrata, Ubuntu live AVVIATO con Secure Boot ON. Prossimo: utente lancia sudo 83hl-test → report su 83HL-LOG.
- Shim ora parte (MokManager ok). Il firmware Qualcomm NON legge ISO9660: MokManager non vede la partizione Ubuntu → copiato MOK-83HL.der su 83HL-LOG (F:). TODO build-iso.sh: mettere il .der anche su 83HL-LOG/ESP e correggere LEGGIMI (volume 83HL-LOG, niente voce 3rd party).
- FATTO 2026-11-11 00:31: reset + script OK (PK/KEK/dbx originali, db = originale + UEFI CA 2011 + 2023, SetupMode=0). Utente deve riattivare Secure Boot nel BIOS e provare la chiavetta. §6.0 completato.


## 0b. REPORT HARDWARE 2026-11-11 e ISO v4 (priorità)
Report in `reports/` (83hl-report-20261111-001341.txt, npu.txt). OK: DTB, GPU msm, backlight, tastiera, touchpad,
Wi-Fi, BT, webcam, impronte, SD, sospensione deep. KO e cause VERIFICATE:
1. ADSP/CDSP offline: firmware non nell'initrd (remoteproc a 0,8 s, -2, nessun retry) → audio (lpass pinctrl
   attende clk da ADSP), batteria 0%, USB-C, NPU. GPU sqe/gmu caricati solo a 72 s → GNOME su llvmpipe.
   Fix v4: `tools/mkcpio.py` crea /casper/83hl-fw.img (fw ADSP/CDSP/zap + gen71500 sqe/gmu .zst), grub carica
   2 initrd; sistema installato: `overlay/etc/dracut.conf.d/83hl-firmware.conf` + `overlay/etc/initramfs-tools/hooks/
   83hl-firmware` + update-initramfs in 83hl-install-target.
2. Moduli 83HL (iris, videocc, EC) rifiutati in lockdown: load_uefi_certs gira a 0,36 s, efivars (qseecom
   uefisecapp) arrivano a 0,68 s → MOK mai nel keyring. Fix v4: `overlay/usr/local/sbin/83hl-kernel-cert` inserisce
   il cert MOK in system_extra_cert (CONFIG_SYSTEM_EXTRA_CERTIFICATE=y, 4104 B) dell'Image (zboot zstd decompresso,
   72 MB) usando System.map; chiamato da 83hl-build-uki (SYSMAP, default /boot/System.map-$UNAME). Verificato offline.
3. Correzioni: 83hl-test copia report anche se 83HL-LOG già montata; MOK-83HL.der anche su 83HL-LOG; LEGGIMI aggiornato.
FATTO: ISO v4 (sha256 4f559333…abda) scritta e verificata sulla chiavetta 01:31, raccogli.sh ricopiato. Prossimo: utente rifà test
(script `raccogli.sh` su 83HL-LOG: va ricopiato dopo la riscrittura).


## 0c. v4 SI RIAVVIA AL BOOT → ISO v5 (2026-11-11 notte)
- v4: reset a ~27,6 s (fase udev). Foto: `videodev` caricato a 27,287 nello stesso punto in cui la v3 aveva
  "Lockdown: (udev-worker): unsigned module loading" → ora i moduli 83HL (videocc_x1p42100/qcom_iris) si caricano
  (certificato OK) e ~0,3 s dopo il PC si resetta. Sospetto n.1: videocc/iris. Sospetto n.2: audio (primo probe con ADSP up).
- v5: `overlay/etc/modprobe.d/83hl-video.conf` (blacklist iris+videocc), `83hl-risky-test video|ec` (traccia con sync su
  83HL-LOG prima di ogni passo), 83hl-test non fa più modprobe EC, voci GRUB di riserva "senza audio" e
  "senza ADSP/CDSP/GPU anticipati", raccogli.sh dentro 83HL-LOG. Build: out/build-v5.log.
- v5 (sha256 8f68f94a…95bc) scritta e verificata sulla chiavetta. In attesa del test utente.
- Da fare dopo test v5: trovare il bug videocc/iris (clock ID 7.3 vs driver 7.0? power domain MMCX? firmware qcvss).


## 0d. TEST v5 RIUSCITO (2026-11-11 ~02:00) (superato da §0e)
Report: `reports/v5/83hl-report-20261111-005736.txt`, `reports/v5/npu.txt`. Avviato con voce "debug" (firmware anticipato attivo,
moduli video in blacklist): NESSUN riavvio → conferma che il reset v4 veniva da videocc_x1p42100/qcom_iris.
OK ora: ADSP+CDSP running, scheda audio X1E80100 + UCM, batteria, USB-C typec, GPU fw (sqe/gmu) caricato a 1,7 s, più tutto
ciò che era già OK (Wi-Fi, BT, webcam, impronte, SD, tastiera, touchpad, backlight, deep sleep).
Aperti:
1. NPU: CDSP online ma `qcom,fastrpc 32300000.remoteproc:glink-edge...: failed to create endpoint` (-12) a 35,8 s, e
   `qcom_q6v5_pas 32300000.remoteproc: timeout waiting for subsystem event response` a 6,6 s → /dev/fastrpc-cdsp assente.
   ADSP fastrpc invece ok ("no reserved DMA memory" solo avviso). Ipotesi: canale glink CDSP non risponde (PD/pd-mapper
   cdspr.jsn? fastrpc caricato tardi? nodo DT fastrpc cdsp). Anche: `libcdsprpc non vista da ldconfig` (/usr/local/lib).
2. Video HW: videocc/iris resettano il PC → blacklist. Debug con `sudo 83hl-risky-test video` (traccia su 83HL-LOG).
   Ipotesi: ID clock DTB 7.3 vs driver gcc 7.0 (clocks=<0x28 0x34 0x158>), power domain MMCX, firmware qcvss8380_pa.
3. "Accelerazione 3D KO" è probabilmente FALSO: il test usa `glxinfo` con DISPLAY=:0 (assente/wayland). Sostituire con
   controllo robusto (es. gnome-shell ha /dev/dri/renderD128 aperto, o eglinfo) e chiedere all'utente se la grafica è fluida.
4. Audio: scheda presente ma `qcom-apm gprsvc:service:2:1: CMD timeout [1001021]` a 36 s → chiedere all'utente se si sente.
5. EC ventola: mai provato (`sudo 83hl-risky-test ec`).
6. Poi: installazione (`sudo /cdrom/83hl/83hl-install-target`), aggiornare GitHub (kernel-cert, mkcpio, initramfs, sb-apply,
   scoperte: no 3rd party CA nel BIOS, MokManager non legge ISO9660, MOK non entra nel keyring). Mai pubblicare keys/, QAIRT, firmware.

## 0e. ANALISI v5 e ISO v6 (2026-11-11 ~02:30) (superato da §0f)
Cause trovate offline:
- **Video (reset v4)**: il DTB 7.3 ha gli `iommus` di iris solo nei sottonodi `non-pixel`/`pixel` (binding nuovo); il driver iris
  backportato su 7.0 (dkms) li vuole sul nodo principale → iris senza IOMMU → reset. Fix: `dts/...-lcd-83hl.dts` blocco `&iris`
  (iommus 0x1940+0x1947, delete dei sottonodi). NON ancora provato su hardware: blacklist resta, prova `sudo 83hl-risky-test video`.
  Ipotesi "ID clock 7.3 vs 7.0" SMENTITA (header gcc e videocc identici; videocc dkms = 7.3 salvo const).
- **NPU**: firmware CDSP giusto (pacchetto 30.0.222.0 = quello attivo in Windows, oem304). CDSP parte a 1,0 s, registra qrtr/canali
  glink, poi non risponde (ssctl QMI timeout a 6,6 s, open_ack glink fastrpc mai arrivato). DT cdsp = hamoa standard. Causa NON
  determinata. Esperimento v6: `sudo 83hl-risky-test npu` (stop/start CDSP a sistema pronto + bind fastrpc + npu-test, con traccia).
  Se funziona → fix permanente: non avviare il CDSP dall'initrd (toglierlo da 83hl-fw.img / avvio tardivo con unit systemd).
- `libcdsprpc non vista da ldconfig`: falso KO (`set -o pipefail` + `grep -q` → SIGPIPE). Corretto con funzione `inld`.
- 3D: test ora `gpu3d` (gnome-shell con /dev/dri/renderD* aperto, oppure `eglinfo -B -p surfaceless`); sezioni nuove nel report
  "GPU 3D" e "DSP / GLINK / QRTR"; riga riepilogo "NPU: /dev/fastrpc-cdsp".
- Audio `qcom-apm CMD timeout [1001021]` (GET_SPF_STATE a 36 s): scheda comunque registrata; serve conferma a orecchio dall'utente.
- Report con byte NUL (model DT): usare `grep -a`.
ISO v6: sha256 2cf70118…c403 (out/build-v6.log), DTB con iommus iris verificato dentro la ISO.
script `C:\Users\mich-de\AppData\Local\Temp\83hl-writeusb.ps1`, aggiornare `$exp`). In attesa dell'utente: 83hl-test, risky-test npu/video/ec.
Dopo i test: se video ok togliere blacklist `overlay/etc/modprobe.d/83hl-video.conf`; installazione; push GitHub (con conferma).

## 0f. TEST v6 e ISO v7 (2026-11-11 ~02:45) (superato da §0g)
Report in `reports/v6/` (2 report, risky-npu/video/ec). Esiti:
- **Video: RISOLTO** dal fix iommus (iris carica senza reset, video2 decoder/video3 encoder, wireplumber li elenca). Blacklist
  `83hl-video.conf` TOLTA; voce GRUB di riserva ora "senza audio e decoder video" (module_blacklist anche iris/videocc).
  Decodifica reale non ancora vista (utente: aprire un filmato).
- **3D: OK** (gnome-shell ha renderD128 aperto).
- **NPU: NON risolto.** Riavvio tardivo CDSP → /dev/fastrpc-cdsp compare ma `glink-edge: intent request timed out` ogni 10 s,
  GET_DSP_INFO -110; a boot IPCRTR e fastrpc "failed to create endpoint", ssctl mai visto. Il CDSP annuncia i canali poi tace.
  Stesso difetto in qualcomm/fastrpc#405 (ASUS Vivobook S16 X1P-42-100, stesso fw CDSP.HT.2.9.c1-00079-HAMOA-1, aperto 29/9/2026,
  nessuna risposta; clk/pd_ignore_unused non aiuta). Su X1E80100 il CDSP risponde (#418) → specifico Purwa. purwa-iot usa
  qcom/x1e80100/cdsp.mbn (firma generica, non caricabile su retail). Possibile azione: aggiungere i nostri dati alla #405 (conferma utente).
- **EC: non applicabile.** 0x76 su i2c5 = segnaposto EC Qualcomm (-ENXIO). EC vero Lenovo: i2c5 @0x60, 100 kHz, DSDT `\_SB.I2C6`
  ECNR/ECNW (~riga 65147-65260 di acpi/DSDT1.dsl): write [0xB0, reg] + read 6 byte (stato, len, dati); [0xB1, reg, val]. Nodo DT
  rimosso, prove EC tolte da 83hl-test/risky-test/LEGGIMI. dkms qcom-hamoa-ec e 83hl-ec restano nel kit ma inutili (da togliere
  in una pulizia futura). Driver Lenovo EC = sviluppo nuovo, solo se l'utente lo chiede.
- Audio: sink Speaker/HDMI e microfoni presenti in wpctl; manca conferma a orecchio.
- 83hl-npu-setup: `cp --remove-destination` (Text file busy su cdsprpcd).
ISO v7: `out/build-v7.log`. DA FARE: verifica contenuto, scrittura chiavetta con conferma (aggiornare `$exp` in 83hl-writeusb.ps1 e
copiare la ISO in Downloads), test utente (boot normale, filmato, audio), poi installazione e push GitHub (con conferma).

## 0g. ISO v8: driver EC Lenovo + prova firmware NPU (2026-11-11 ~03:00) (superato da §0h)
Utente: "devi risolvere tutto prima di fare chiavetta" (ha rifiutato la scrittura della v7). Fatto offline, NON provato su hardware:
- **EC**: nuovo driver `dkms/83hl-drivers-1.0/ec/lenovo-83hl-ec.c` (hwmon sola lettura: temp1-6 = reg 0x90-0x95, fan1/2 = 0x9A/0x9C
  16 bit LE, target 0x9E/0xA0). Protocollo: write block cmd 0x62 [0xB0, reg, 0,0,0], read block cmd 0x61 6 byte (byte0 = valore).
  DT: `embedded-controller@60` compat `lenovo,ideapad-slim5x-83hl-ec`, i2c5 portato a 100 kHz. Prebuilt in overlay per -30/-43
  (build-video.sh), sorgenti copiati a mano in overlay/usr/src/83hl-drivers-1.0 (rsync assente). Mai scritture verso l'EC.
  Voce GRUB di riserva: module_blacklist anche lenovo_83hl_ec. Se i valori letti sono assurdi: guardare la riga dmesg
  "EC Lenovo 83HL: reg 0x90 -> <6 byte>" (forse il valore non è il byte 0).
- **NPU**: `83hl-risky-test npu` ora prova firmware attuale (30.0.222) + alternativi in overlay/usr/lib/83hl/npu/cdsp-alt/
  {30.0.140,30.0.216,30.0.219} (dal DriverStore; proprietari, MAI su GitHub), con stop/start CDSP e verdetto automatico.
  Se nessuno risponde: resta problema upstream (#405); idee successive: confronto con Windows (PEP/qcnspmcdm), sessione Claude
  direttamente su Ubuntu installato per debug interattivo.
- 83hl-test: righe "EC Lenovo" e sezione "EC LENOVO".
ISO v8: sha256 20de37ee…7254, contenuto verificato (EC .ko e sorgente, cdsp-alt, DTB con EC@60 e iommus iris; v7 mai scritta). Chiavetta: SOLO con conferma esplicita dell'utente.

## 0h. ISO v9: voti CDSP stile Windows (2026-11-11 ~03:15) (superato da §0i)
Utente: niente chiavetta finché non è "tutto risolto"; ha indicato `D:\drivers` (export driver Windows, 212 pacchetti).
SCOPERTA (da `qcsubsys_ext_cdsp8380.inf_*/RCDS.bin`, formato "AeoB", decodificato con stringhe + valori a 32 bit dopo ogni nome):
- \_SB.NSP0 P0 (avvio): /arc/client/rail_cx, rail_mxa, rail_mxc, rail_nsp = 0x180 (384, turbo); rail_xo = 0x80;
  BUSARB CDSP_PROC→EBI1 e CDSP_PROC→CLK_CTL = 1/1. P1 (in corsa): SOLO rail_nsp = 0 (il resto resta votato). P2: tutto 0.
  ADSP (RADS.bin): P1 vuoto. Linux pas: proxy cx/mxc/nsp + xo rilasciati all'handover, mai mxa né CLK_CTL → ipotesi forte per
  "CDSP parte poi tace" su Purwa (fastrpc#405). NON ancora provata.
- Nuovo modulo `dkms/83hl-drivers-1.0/npu/cdsp-keepalive-83hl.c` + nodo DT root `cdsp-keepalive` (cx, mx, mxc; xo; icc ebi/clkctl).
  Non vota finché `echo 1 > /sys/bus/platform/drivers/cdsp-keepalive-83hl/*/active`; parametri `active`, `level` (384), `mask`
  (1 rail, 2 xo, 4 bus). Altri INF utili: IgnoreWdogEnabled, UefiLoadedSubsysDetectionConfig=1, thermal QMI cdsp_sw 0x43.
- `83hl-risky-test npu`: 1) fw attuale senza voti 2) con voti mask 7 3) se ok bisezione mask 4) altrimenti fw cdsp-alt con voti.
  Se funziona: fix permanente = `options cdsp_keepalive_83hl active=1 mask=<minimo>` in modprobe.d + modulo nell'initrd PRIMA
  di qcom_q6v5_pas (o softdep), poi valutare livello più basso di 384 per i consumi.
- EC: vedi §0g (driver lenovo-83hl-ec, non provato).
- Audio: CONFERMATO funzionante dall'utente (altoparlanti), 2026-11-11.
ISO v9 SCRITTA E VERIFICATA SULLA CHIAVETTA 02:52 (in attesa dei test utente: 83hl-test, risky-test npu, 83hl-test, filmato). sha256 77e45066…75e4, contenuto verificato (2 moduli nuovi, sorgente keepalive, 3 fw cdsp-alt, DTB con keepalive+EC@60+iommus iris; v7/v8 mai scritte). Chiavetta SOLO con conferma esplicita.

## 0i. v9 "comando non trovato" → ISO v10 con `83hl-finale` (2026-11-11 ~09:50) — STATO ATTUALE, PARTIRE DA QUI
- Test v9: nessun report, solo `npu.txt` con "Input/output error" su /usr/local/*; utente: "83hl-test: comando non trovato".
- CAUSA (verificata nei journal v5/v6): il live monta il DISCO INTERO su /cdrom → la partizione 83HL-LOG non si monta
  ("/dev/sda3: Can't open blockdev"); l'utente staccava/riattaccava la chiavetta per montarla ("usb 5-1: USB disconnect" a 125 s
  in v5 e 155 s in v6, "Failed unmounting cdrom.mount", ritorno come sdb in high-speed) → rootfs live morto. In v5/v6 i comandi
  andavano solo perché già in cache. NON è un difetto dei driver v9 (il desktop v9 partiva normalmente).
- Fix v10: `overlay/usr/local/lib/83hl-log.sh` (`log83_mount`: mount normale, altrimenti loop con offset sul disco intero;
  collaudato su immagine ISO con disco occupato), usato da 83hl-test, 83hl-risky-test, 83hl-npu-test. Nuovo comando unico
  `sudo 83hl-finale` (test → ec.txt → risky npu → test → dmesg-finale.txt). raccogli.sh = `exec sudo 83hl-finale`. LEGGIMI:
  mai staccare la chiavetta. ATTENZIONE: non montare mai rw l'immagine ISO in out/ per prove (cambia l'hash): usare una copia.
- ISO v10 sha256 a373a9ce…24e9 SCRITTA E VERIFICATA sulla chiavetta 09:46. Contiene tutto di v9 (EC, keepalive NPU, video autoload).
- In attesa: utente avvia, `sudo 83hl-finale`, prove a mano (filmato), poi "report pronto" → leggere F:\ (report, ec.txt,
  risky-npu-*.txt, dmesg-finale.txt). Audio già confermato.

## 2. Stato corrente
- **ISO v3** `out/ubuntu-26.04.1-83hl-arm64.iso` (sha256 32eb11be…8344, con NPU + 83hl-sensors-test), copia in `C:\Users\mich-de\Downloads`.
  Scritta e verificata (hash riletto) sulla chiavetta SanDisk Ultra 28,6 GB (disco 1). Istruzioni utente: `F:\LEGGIMI.txt`
  (sorgente `overlay-iso/LEGGIMI.txt`).
- **Mai testata sull'hardware**: l'utente deve fare BIOS (CA 3rd party nel db, vedi §0; la voce BIOS NON esiste, LEGGIMI.txt da correggere) → MokManager (MOK-83HL.der) →
  "Ubuntu 83HL" → `sudo 83hl-test` → report su partizione 83HL-LOG (F:) → dire "report pronto".
- Sensori (presenza/luce/orientamento): **non esistono fisicamente** (segnaposto firmware CRD, null anche in Windows).
  Analisi in `sensors/` (README, evidence, 83hl-sensors-test). Da aggiungere `sensors/83hl-sensors-test` a `overlay/usr/local/bin/`.
- NPU: analisi completata e verificata (kernel fastrpc=m, DT CDSP+fastrpc ok, shell DSP unsigned + libc++ nella cartella CDSP/
  del driver Windows con la stessa build del firmware). Stack in `npu/` (README, 83hl-npu-setup/test, overlay 168 MB con QAIRT 2.47).
  **Integrato nella ISO v3** e sulla chiavetta. Script NPU pubblicati su GitHub (senza QAIRT né binari DSP).
- GitHub: pubblicato (pubblico) https://github.com/mich-de/ubuntu-ideapad-slim5x-83hl, 2 commit (kit + NPU).

## 3. Tentativi falliti ed errori risolti
- GRUB `devicetree` **vietato con Secure Boot** (lockdown) → DTB messo nel UKI stubble (ukify) e firmato MOK. Mai /boot/dtb.
- INF Windows in **UTF-16**: nella shell di Claude `grep` è alias ugrep (li legge), negli script no → usare python.
- `set -o pipefail` + `grep|head` → SIGPIPE casuali: usare `grep -m1`.
- UCM: file in conf.d è symlink → patchare `Qualcomm/x1e80100/x1e80100.conf` / `sed --follow-symlinks`.
- DTS locale con stesso nome del file incluso → include ricorsivo: suffisso `-83hl.dts`.
- PowerShell `[Math]::Min` su Int32 con valori >2 GB → cast `[long]`.
- `dpkg -i --force-depends` degli header ha rotto apt in WSL → risolto con `apt --fix-broken install`.
- Boot chiavetta rifiutato dal firmware ("boot failed"): shim firmato solo da Microsoft UEFI CA 2011, assente dal db Lenovo 83HL.
  Repo microsoft/secureboot_objects NON ha DB update firmati 3rd party → impossibile aggiungerla senza Setup Mode.
  powershell Get-SecureBootUEFI senza admin = "Accesso negato": usare Start-Process -Verb RunAs (UAC off, parte subito).
- Driver EC Qualcomm: `cur_state=0` = ventola SPENTA → patch: 0 = debug off (automatico EC); 83hl-ec rifiuta PWM<80.

## 4. Decisioni architetturali
- Kernel **Ubuntu 7.0** (aggiornabile) + DTB dall'albero Glathe `jg/ubuntu-qcom-x1e-7.3.y` + aggiunte locali (`dts/…-lcd-83hl.dts`: nodo EC).
- UKI: `.linux` estratto dal vmlinuz Canonical, ricostruito con stubble + solo DTB LCD + hwids 83HL (CHID calcolati con
  `tools/chid.py`, validati 8/8 contro systemd) + SBAT stubble, firmato MOK. Chiave ISO in `keys/` (privata, MAI pubblicare).
  Sistema installato: chiave MOK propria generata in `/etc/83hl/mok`, hook `/etc/kernel/postinst.d/zz-83hl-uki`.
- Moduli esterni `dkms/83hl-drivers-1.0`: iris backport purwa v7 su 7.0, videocc-x1p42100, qcom-hamoa-ec (API 7.0,
  patch sicurezza). Prebuilt per 7.0.0-30 e -43, firmati da `83hl-sign-modules`; kernel futuri via DKMS (firma MOK).
- EC: i2c5 @0x76, IRQ gpio66 (regola Windows→Linux: pin/64 → Interrupt GIO0._CRS → SPI → PDC → gpio). Blacklist di default.
- Firmware Qualcomm estratti dal DriverStore Windows (versione driver più alta), **non ridistribuibili**: lo script li estrae.

## 5. File creati/modificati (`/home/mich/lenovo`)
- Build: `build-iso.sh`, `build-dtb.sh`, `build-video.sh`, `tools/extract-firmware.sh`, `tools/chid.py`, `tools/dtb-compat-check.py`
- Sorgenti: `dts/x1p42100-lenovo-ideapad-slim5x-lcd-83hl.dts`, `dkms/83hl-drivers-1.0/` (iris/, clk/, ec/, dkms.conf)
- Overlay (finisce nella ISO e nel sistema): `overlay/` → 83hl-test, 83hl-ec, 83hl-build-uki, 83hl-sign-modules, 83hl-fix-ucm,
  hook kernel, udev impronta, system-sleep fprintd, apt hook UCM, modprobe EC, dkms framework, hwids JSON, DTB, firmware, moduli
- ISO: `overlay-iso/83hl/83hl-install-target`, `overlay-iso/LEGGIMI.txt`
- Analisi: `acpi/` (DSDT/SSDT), `sensors/`, `npu/` (parziale), `memory.md`, `handover.md`
- Secure Boot: `backup/secureboot-orig/` (PK/KEK/db/dbx originali, ca2011.crt, ca2023.crt, db-append.esl, db-new.esl, 83hl-sb-apply.ps1)
- Esterni: `src/glathe`, `src/linux-7.0`, `src/systemd`, `src/patches/purwa-v7.mbox`, `keys/` (PRIVATO), `debs/`, `hdr/`, `iso/`, `out/`
- Memoria Claude: `~/.claude/projects/-home-mich-lenovo/memory/83hl-linux-secureboot.md`

## 6. Prossimi passi
0. **PRIMA DI TUTTO** (Secure Boot): ricevere foto/voci di BIOS → Security → Secure Boot. Se c'è "Reset to Setup Mode"
   (o "Clear All Secure Boot Keys") + "Restore Factory Keys": utente fa Reset to Setup Mode, F10, torna in Windows;
   con conferma dell'utente lanciare da admin:
   `Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','<winpath>\83hl-sb-apply.ps1'`
   (cartella `backup/secureboot-orig`, via \\wsl$ o copiata in C:\). Verificare `apply-log.txt` (db/KEK/PK ok=True, SetupMode=0),
   poi F12 → chiavetta → MokManager (MOK-83HL.der) → test. Se manca Reset to Setup Mode: rivalutare (es. KeyTool/sbctl non disponibili su UEFI Qualcomm? verificare).
1. GitHub: https://github.com/mich-de/ubuntu-ideapad-slim5x-83hl, 4 commit (ultimo 5126f80: LEGGIMI riscritto). Copia di lavoro github/ubuntu-ideapad-slim5x-83hl; push: `git -c credential.helper= -c credential.helper="!/mnt/d/CentroAI/bin/gh.exe auth git-credential" push`, autore = quello dei commit precedenti (`-c user.name/email`). File npu/*.sh e tools/extract-firmware.sh nel repo usano $ROOT (versione ripulita): non sovrascriverli dai sorgenti.
2. NPU integrata (QAIRT proprietario: solo uso personale, mai su GitHub). Test: sudo 83hl-npu-setup && sudo 83hl-npu-test.
3. Fatto: sensors test in overlay e chiavetta v3. Per future riscritture (script admin
   `C:\Users\mich-de\AppData\Local\Temp\83hl-writeusb.ps1`, aggiornare `$exp`), solo con conferma utente.
4. Quando arriva il report (`F:\83hl-report-*.txt`): leggere RIEPILOGO e correggere i 🟡 (audio, luminosità, SD, sospensione, iris, EC).
5. Poi installazione: `sudo /cdrom/83hl/83hl-install-target` prima del riavvio.

## §0j — Esito prova v10 (11/11/2026, report in reports/v10/) — STATO ATTUALE
- OK su hardware: boot con video autoload (nessun reset), iris decoder/encoder + elementi GStreamer v4l2 (h264/h265/vp9/av1), 3D, audio, Wi-Fi, BT, webcam, impronte, SD, batteria, typec, log83_mount (loop+offset) funziona, 83hl-finale arriva a FINITO.
- NPU: ANCORA KO. Il verdetto "CDSP RISPONDE" di 83hl-risky-test è un FALSO POSITIVO: controllava dopo 14 s, ma "intent request timed out" compare solo quando qualcuno fa una richiesta (32 s dopo, da cdsprpcd). Quindi i voti keepalive (mask 1..7) e i fw cdsp-alt NON sono mai stati provati. Fix: in `try` forzare una richiesta (es. fastrpc-healthcheck / avvio cdsprpcd) e attendere >=35 s prima del verdetto.
- Note: modulo keepalive caricato a 27 s, CDSP parte a 1 s (builtin/initrd) → per un fix permanente serve nell'initrd prima di qcom_q6v5_pas. "sync_state() pending due to cdsp-keepalive" su rpmhpd/qnoc finché il modulo non fa probe.
- EC: driver fa probe su 5-0060 senza errori I2C ma legge 6 byte tutti 00 (temp e ventola 0). "[OK] EC Lenovo" in 83hl-test è falso positivo (controlla solo l'esistenza di hwmon). Protocollo ECNR da rivedere (count byte SMBus block? ritardo write→read? indirizzo/bus?). Le temperature SoC funzionano comunque via tsens.
- Standby: MAI provato davvero; il test controlla solo che "deep" sia in /sys/power/mem_sleep (s2idle [deep]). Nessun suspend nel dmesg.
- Decodifica reale di un filmato: nessuna traccia nel dmesg, da chiedere all'utente.
- Errori noti innocui già in v6: gpi b00000 timeout, qcom-apm CMD timeout, fastrpc probe -12 al boot.
- Prossimo passo consigliato: installare su SSD e proseguire NPU/EC/standby con sessione Claude direttamente su Ubuntu (niente più giri di chiavetta).

## §0k — Spazio per installazione (11/11/2026)
C: ridotta di 25 GB (359,45 -> 334,45 GB) su richiesta utente: 25 GB NON ALLOCATI tra C: e D: sul disco 0 (Micron 512). BitLocker spento, Secure Boot attivo. Nessuna partizione creata: la crea l installer Ubuntu ("spazio libero"). Poi `sudo /cdrom/83hl/83hl-install-target` PRIMA di riavviare.

## §0l — GitHub aggiornato (11/11/2026)
Commit 4c5d18c su https://github.com/mich-de/ubuntu-ideapad-slim5x-83hl: sorgenti v10 (dts, dkms ec/npu, overlay, scripts, tools/mkcpio.py) + `docs/stato/` (HANDOFF, memory, handover, log v10 piccoli). NON pubblicati: keys/, QAIRT, firmware, cdsp-alt, report completi e dmesg (seriali/MAC). Da Ubuntu: `git clone` del repo e leggere docs/stato/HANDOFF.md §0j-§0k. I firmware cdsp-alt e il payload NPU sono sulla chiavetta in /cdrom/83hl e nel sistema installato in /usr/lib/83hl/npu.

## §0m — Crash fastrpc e patch (11/11/2026, 16:12)
- Oops NULL deref in `fastrpc_internal_invoke+0x1d8` (= `fastrpc_invoke_send`, `cctx->rpdev->ept`, rpdev NULL dopo remove CDSP) durante `fastrpc_device_release`; il dump su `efi_pstore` è andato in deadlock sul mutex SCM (QSEECOM) → PC bloccato.
- CDSP continua a dare `dsp information is incorrect err: -110` anche con keepalive mask 7: NPU ancora KO.
- Patch: `dkms/83hl-drivers-1.0/fastrpc/fastrpc.c` (rpdev letto una volta con READ_ONCE, -EPIPE se NULL), registrata in dkms.conf (non ancora installata). Compila su 7.0.0-43.
- `83hl-nopstore.conf` (blacklist efi_pstore) pronto in root, non installato. Installare: `sudo cp 83hl-nopstore.conf /etc/modprobe.d/` + `sudo dkms build/install 83hl-drivers/1.0`.
