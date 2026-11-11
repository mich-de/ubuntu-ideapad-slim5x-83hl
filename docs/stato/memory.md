# memory.md — Ubuntu 26.04.1 su Lenovo IdeaPad Slim 5x 14Q8X9 (83HL)
## Hardware/firmware
- SoC X1P42100 (Purwa), pannello **LCD** LEN140WUXGA (EDID LEN9120) → DTB `x1p42100-lenovo-ideapad-slim5x-lcd`.
- SMBIOS: LENOVO | IdeaPad Slim 5 14Q8X9 | 83HL | LENOVO_MT_83HL_BU_idea_FM_IdeaPad Slim 5 14Q8X9 | LENOVO | LNVNB161216.
- Secure Boot ON (requisito utente, non disattivare). db UEFI: solo Windows PCA 2011 + Windows UEFI CA 2023 → serve abilitare "3rd Party UEFI CA" nel BIOS. BitLocker OFF su C: e D:.
## Decisioni
- Kernel Ubuntu 7.0 + DTB da albero Glathe (`src/glathe`, branch jg/ubuntu-qcom-x1e-7.3.y). Nessun DTB 83HL in Ubuntu né in mainline (serie upstream 6/9/2026 non mergiata).
- Secure Boot: GRUB in lockdown rifiuta `devicetree` → DTB+hwids dentro il UKI stubble (ukify), firmato con MOK. Mai usare /boot/dtb.
- CHID calcolati con `tools/chid.py` (algoritmo systemd), validati: 8/8 uguali al JSON systemd 83HL OLED.
- ISO: chiave MOK in `keys/` (privata, NON va sulla ISO). Sistema installato: chiave MOK propria generata in /etc/83hl/mok, hook /etc/kernel/postinst.d/zz-83hl-uki rifirma ogni kernel.
- Bug trovato: alsa-ucm-conf regex `Ideapad.*5` non matcha DMI `IdeaPad` → fix `Idea[Pp]ad` (83hl-fix-ucm + hook apt).
- Iris (video HW) non supportato dal kernel 7.0: decodifica software.
## Convenzioni
- Nella shell di Claude `grep` è un alias ugrep (legge UTF-16): negli script usare python/iconv per gli INF Windows.
## Driver aggiuntivi (2026-11-10)
- Video HW: iris v7.0 + backport serie purwa v7 (clock BSE in power_on_hw prima di hwmode, x1p42100_data = sm8550_data con clk x1p42100, fw vpu30_p1_s7, num_vpp_pipe=1) + videocc-x1p42100 (Glathe, compilato con header clk 7.0). Pacchetto dkms/83hl-drivers-1.0.
- EC ventola: stesso EC Qualcomm di riferimento della CRD: i2c5 (= I2C6 Windows) @0x76, IRQ gpio66. Driver qcom-hamoa-ec (Glathe) portato a API 7.0; patch: stato 0 = debug off (auto) invece di PWM 0. Blacklist di default (/etc/modprobe.d/83hl-ec.conf), comando 83hl-ec.
- Conversione GPIO Windows->Linux (Qualcomm direct-connect): pin/64 = indice negli Interrupt di GIO0._CRS -> GSIV-32 = SPI -> pdc-ranges (hamoa.dtsi) -> pdc_map (pinctrl-x1e80100.c). Verificata su gpio 92/3/67.
- Moduli firmati MOK (CONFIG_INTEGRITY_MACHINE_KEYRING=y, CA non richiesta). Prebuilt per 7.0.0-30 e -43 in /usr/lib/83hl/modules, installati in updates/83hl da 83hl-sign-modules (chiamato dall'hook kernel); kernel futuri via DKMS.
- Toolchain: gcc-15 = stesso compilatore Ubuntu. Header 7.0.0-30/-43 installati in WSL.
- 83HL: db di fabbrica = solo Windows PCA 2011 + Windows UEFI CA 2023; KEK = MS KEK CA 2011 + KEK 2K CA 2023; PK = Lenovo "Ideapad Products". Nessuna opzione BIOS 3rd Party CA (PUCN55WW).
- 83HL Linux: firmware ADSP/CDSP/GPU DEVE stare nell'initramfs (remoteproc parte a ~1 s, senza retry).
- 83HL Linux: la MOK non entra nel keyring del kernel (efivars qseecom arrivano dopo load_uefi_certs) → cert MOK inserito in
  system_extra_cert con 83hl-kernel-cert; altrimenti i moduli firmati MOK sono rifiutati in lockdown.
- 83HL: MokManager/firmware non leggono ISO9660 → file per MokManager su partizione FAT. BIOS senza toggle 3rd Party CA:
  db modificato in Setup Mode (backup/secureboot-orig).
- 83HL: videocc_x1p42100 + qcom_iris (backport) caricati = reset del PC: tenerli in blacklist finché non corretti.
- 83HL: DTB 7.3 + driver iris backportato su 7.0 → servono `iommus` (0x1940, 0x1947) sul nodo iris principale (blocco `&iris` in
  dts/...-83hl.dts); senza, reset del PC. Da togliere con kernel che ha iris 7.3 in-tree. Confermato su hardware 2026-11-11 (v6): blacklist video tolta.
- 83HL: firmware CDSP corretto = pacchetto qcnspmcdm_ext_cdsp8380 30.0.222.0 (quello attivo in Windows). CDSP avviato da initrd
  resta "running" ma sordo su glink (causa aperta).
- Script con `set -o pipefail`: mai `cmd | grep -q` (SIGPIPE). Report 83hl-test contengono NUL: `grep -a`.
- 83HL: NPU non funzionante su Linux (CDSP sordo su glink, qualcomm/fastrpc#405, specifico X1P-42-100). Non è un difetto del kit.
- 83HL: EC a 0x76 (qcom-hamoa-ec) NON esiste; EC Lenovo vero su i2c5 @0x60 (protocollo ECNR/ECNW nel DSDT): driver locale lenovo-83hl-ec, sola lettura, mai scrivere registri EC.
- 83HL NPU: Windows tiene votati per il CDSP in corsa cx/mxa/mxc (384), xo, bus EBI1+CLK_CTL (RCDS.bin in D:\drivers e DriverStore);
  modulo locale cdsp-keepalive-83hl li replica a comando (ipotesi da provare su hardware).
- Export driver Windows dell'utente: D:\drivers.
- 83HL: audio altoparlanti confermato funzionante dall'utente (v6); il timeout `qcom-apm CMD [1001021]` a 36 s è innocuo.
- 83HL live USB: /cdrom tiene il disco intero → 83HL-LOG montabile solo via loop+offset (`/usr/local/lib/83hl-log.sh`); staccare la chiavetta uccide il sistema live. Comando unico di prova: `sudo 83hl-finale`.

- Verdetti test: "intent request timed out" del CDSP appare solo dopo una richiesta fastrpc (~32 s): mai giudicare il CDSP senza forzare una richiesta. hwmon esistente != EC funzionante.
