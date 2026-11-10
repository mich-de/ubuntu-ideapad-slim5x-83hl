# NPU Hexagon (CDSP) su Lenovo 83HL — Ubuntu 26.04 arm64, kernel 7.0.0-30/-43, Secure Boot ON

Stato: tutto preparato e collaudato **fuori dall'hardware** (WSL). Nessuna prova reale sul DSP: vedi "Solo su hardware".

## Fattibilità

| Livello | Giudizio | Motivo |
|---|---|---|
| Kernel + DT: avvio CDSP, `/dev/fastrpc-cdsp` e `-secure` | **alta probabilità** | tutto già presente, nessuna patch |
| FastRPC end-to-end su **unsigned PD** (`fastrpc_test`) | **alta probabilità** | shell unsigned Lenovo della stessa build del firmware |
| Inferenza QNN HTP (`qnn-net-run`) | **incerto** | X1E/X1P su Linux non è target ufficiale QAIRT; `soc_id` Purwa ignoto |
| **Signed PD** con moduli propri / skel QNN | **impossibile** in pratica | serve firma Qualcomm/OEM o testsig per-device, non ottenibili |
| Driver `accel/qda` | non applicabile | solo RFC, non nel kernel Ubuntu 7.0 |

Secure Boot UEFI non incide: non servono moduli kernel esterni (niente da firmare con MOK).

## Evidenze

**Kernel Ubuntu 7.0** (`/usr/src/linux-headers-7.0.0-30-generic/.config`): `CONFIG_QCOM_FASTRPC=m` (r.3021), `CONFIG_QCOM_Q6V5_PAS=m` (12464),
`CONFIG_RPMSG_QCOM_GLINK_SMEM=m` (12486), `CONFIG_QCOM_PD_MAPPER=m` (12604), `CONFIG_DMABUF_HEAPS_SYSTEM=y` (11314), `CONFIG_QCOM_SOCINFO=m` (12619).
Moduli presenti nel pacchetto 7.0.0-43: `kernel/drivers/misc/fastrpc.ko.zst` (alias `of:N*T*Cqcom,fastrpc`, firmato Ubuntu),
`drivers/remoteproc/qcom_q6v5_pas.ko.zst` (contiene `qcom,x1e80100-cdsp-pas`), `qcom_pd_mapper.ko.zst` (contiene `qcom,x1p42100`).
→ **nessun modulo da compilare**, cartella `modules/` non creata.

**Device tree** (Glathe `arch/arm64/boot/dts/qcom/`): `hamoa.dtsi` r.9679 `remoteproc_cdsp` (`qcom,x1e80100-cdsp-pas`), r.9727-9815 nodo
`glink-edge/fastrpc` (`qcom,fastrpc`, `label="cdsp"`, `qcom,non-secure-domain`, compute-cb 1-8 e 10-13); `purwa.dtsi` r.7 include `hamoa.dtsi`;
`x1p42100-lenovo-ideapad-slim5x.dtsi` r.1233-1238 `status="okay"` + firmware 83HL. Verificato anche nel DTB compilato
`$ROOT/out/x1p42100-lenovo-ideapad-slim5x-lcd.dtb`. → **nessuna patch DTS**, nessun `.dtsi` aggiuntivo creato.

**Unsigned PD nel driver** (`src/linux-7.0/drivers/misc/fastrpc.c`): r.2401 `qcom,non-secure-domain`; r.2414-2420 per CDSP `unsigned_support=true`
e due device node; r.1274-1288 `is_session_rejected()` blocca solo device non sicuro su canale sicuro; r.1443 `FASTRPC_MODE_UNSIGNED_MODULE`.
Lato utente `fastrpc_apps_user.c` r.277-278 (`fastrpc_shell_` / `fastrpc_shell_unsigned_`), r.3244.

**Firmware e librerie DSP** (Windows, pacchetto `qcnspmcdm_ext_cdsp8380.inf_arm64_f1b8ece7c9c58086`, DriverVer 30.0.0222):
`qccdsp8380.mbn` sha256 `4d2aa10a…5568` = quello già in `overlay/usr/lib/firmware/qcom/x1p42100/LENOVO/83HL/`; build `CDSP.HT.2.9.c1-00079-HAMOA-1`.
La cartella `CDSP/` contiene `fastrpc_shell_3`, `fastrpc_shell_unsigned_3`, `lib*_skel.so`, `libc++.so.1`, `libc++abi.so.1` della **stessa build**.
Il firmware è firmato Qualcomm (certificati nel file: `QMC Attestation Root CA 6`, `CASS - SBL4`), non con chiave Lenovo.

**Pacchetto `hexagon-dsp-binaries-qualcomm-hamoa-iot-evk`: scartato.** Shell di build `CDSP.HT.2.9.c1-00069` (≠ 00079), sha256 diverso
(`19bbafcc…` contro `bab7f85d…`), e non contiene `libc++.so.1`/`libc++abi.so.1` richiesti da `libQnnHtpV73Skel.so`. Che una shell di build diversa
venga rifiutata dal firmware è una deduzione, non verificata: si usa comunque quella Lenovo. Scartati anche `firmware-qcom-dsp` (nessun firmware
83HL/x1p42100) e `hexagonrpcd`/`libhexagonrpc` (non forniscono `libcdsprpc.so`, che `libQnnHtpV73Stub.so` ha in `NEEDED`). Tutti in `debs/non-usati/`.

**Userspace**: Ubuntu 26.04 non ha un pacchetto con `libcdsprpc` (`apt-cache search fastrpc` → solo hexagonrpcd e hexagon-dsp-binaries).
Compilato da sorgente `github.com/qualcomm/fastrpc` commit `8f592739` con `build-fastrpc.sh` (script dell'agente precedente: verificato
contro `src/Makefile.am`, funziona; corretta solo la regola udev che richiedeva `setfacl`).

**QAIRT**: zip pubblico senza login (`softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community/All/<ver>/v<ver>.zip`),
licenza proprietaria (`LICENSE.pdf`: uso/sviluppo consentiti, vietata la redistribuzione "standalone") → va bene sulla ISO personale, non pubblicarla.
- `lib/aarch64-ubuntu-gcc9.4` ha solo lo stub V68; lo stub V73 è in `lib/aarch64-oe-linux-gcc11.2` (gira su Ubuntu 26.04: provato `qnn-net-run --version`).
- La doc QAIRT 2.42 elenca SC8380XP (SoC model 60, V73) solo con toolchain Windows.
- Prova con `/sys/devices/soc0/soc_id` simulato a 555 (X1E80100): **2.42.0.251225** risponde `Dsp startup: Unsupported SoC model 60`;
  **2.47.0.260601** lo accetta, carica `libQnnHtpV73Stub.so` + il nostro `libcdsprpc.so` e si ferma solo all'apertura del device (`qnn_open failed 0x72`, atteso in WSL).
  → payload con **2.47**. Lo skel di Windows (`qcnspmcdm8380…/HTP/libQnnHtpV73SkelDrv.so`, AISW 2.42.0) non si usa: stub e skel devono essere della stessa versione.
- Il `soc_id` di X1P42100 non è in `include/dt-bindings/arm/qcom,ids.h` mainline (c'è solo `QCOM_ID_X1E80100 555`): non si sa se QAIRT lo riconosce.
  `83hl-npu-test` stampa il valore reale e, se QNN lo rifiuta, riprova con `soc_id` 555 in un mount namespace privato (ripiego non supportato).
- Firma: la doc Qualcomm "Windows HTP Library Loading" attribuisce la verifica di `*.cat`/skel a Windows; "unsigned" nel percorso SDK indica il tipo di PD.
  Su Linux nessuno verifica il catalogo; nell'unsigned PD il DSP non richiede firma (da confermare sull'hardware).

## File

| File | Scopo |
|---|---|
| `83hl-npu-setup` | sul target: installa fastrpc, librerie DSP, yaml, gruppo, udev, cdsprpcd, QAIRT. Idempotente, offline |
| `83hl-npu-test` | sul target: verifica catena con OK/KO, log in `/var/log/83hl-npu-test.log` e su `83HL-LOG` |
| `overlay/` | albero pronto per la ISO (168 MB, in gran parte QAIRT); hash in `overlay.SHA256SUMS` |
| `build-fastrpc.sh` → `stage/` | libcdsprpc, cdsprpcd, fastrpc_test, fastrpc-healthcheck |
| `83hl-npu-extract-dsp.sh` → `dsp/cdsp/` | librerie DSP dal DriverStore (pacchetto scelto per sha256 del firmware) |
| `fetch-qairt.sh`, `tools/rzip.py` → `qairt/` | scarica solo i file QAIRT necessari via HTTP Range |
| `build-qnn-test-model.sh` → `qnn-test/` | modello di prova conv+relu 8 bit dagli esempi QAIRT |
| `build-npu-payload.sh` | riassembla `overlay/` (`--no-qairt` per escludere il proprietario) |

## Integrazione nella ISO

```
cp -a $ROOT/npu/overlay/. $ROOT/overlay/    # poi ./build-iso.sh
```
Aggiunge `usr/local/sbin/83hl-npu-setup`, `usr/local/bin/83hl-npu-test`, `usr/lib/83hl/npu/{stage,dsp,debs,qairt,qnn-test}`.
Sul sistema avviato: `sudo 83hl-npu-setup && sudo 83hl-npu-test` (aggiungere la chiamata a `83hl-install-target` se la si vuole automatica).
Destinazioni: `/usr/local/{lib,sbin,bin}`, `/usr/share/qcom/x1p42100/LENOVO/83HL/dsp/cdsp/`, `/usr/share/qcom/conf.d/83hl.yaml`,
`/etc/udev/rules.d/60-83hl-fastrpc.rules`, `/opt/qairt/current`. Dopo un aggiornamento dei driver Windows rilanciare
`tools/extract-firmware.sh` + `83hl-npu-extract-dsp.sh` insieme (firmware e shell devono restare appaiati).

## Collaudo fatto (WSL)

Setup e test eseguiti in una root simulata (user namespace): installazione, seconda esecuzione idempotente, yaml col modello DT, caricamento
di tutte le librerie, percorso di ripiego `soc_id`. In quella sandbox restano KO attesi (niente systemd, `/usr/lib/sysusers.d` in sola lettura).
Non collaudabile: tutto ciò che tocca il DSP. Il backend CPU di QNN non si inizializza in WSL (causa non indagata), quindi il modello di prova
non ha un'esecuzione di riferimento.

## Solo su hardware

1. `remoteproc` CDSP in `running` con il firmware Lenovo (autenticazione PAS via TrustZone) e comparsa di `/dev/fastrpc-cdsp*`.
2. SMMU/compute-cb sotto l'hypervisor del firmware Windows.
3. Accettazione dell'unsigned PD e dei moduli non firmati (`fastrpc_test -U 1`).
4. Valore di `/sys/devices/soc0/soc_id` e reazione di QAIRT 2.47; efficacia del ripiego a 555.
5. Inferenza reale, prestazioni, comportamento in sospensione/ripresa, consumo a riposo con CDSP acceso.

## Rischi

- CDSP che non parte o va in crash-loop: per escluderlo del tutto mettere `status = "disabled"` su `&remoteproc_cdsp` nel DTS locale e ricompilare il DTB.
- `83hl-npu-setup` aggiunge al gruppo `fastrpc` tutti gli utenti con UID ≥ 1000.
- Il ripiego `soc_id` fa credere a QNN di essere su X1E80100 (12 core): possibili scelte di tuning errate.
- QAIRT 2.47 è un binario proprietario costruito per Qualcomm Linux (OE), non per Ubuntu: funziona il caricamento, non è garantito il resto.
