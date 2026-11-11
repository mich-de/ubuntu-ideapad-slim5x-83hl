# Hardware status (Ubuntu 26.04.1 arm64, kernel 7.0.0-43, Secure Boot ON) — 83HL, X1P42100, LCD

Verified on one machine (BIOS PUCN55WW). Sample reports: [`reports/v10/`](reports/v10/).

| Area | Status | Notes |
|---|---|---|
| Boot with Secure Boot (shim → GRUB → MOK-signed UKI + 83HL DTB) | ✅ | needs the db fix in [`../secureboot/`](../secureboot/) |
| GPU (Adreno, msm) 3D | ✅ | needs sqe/gmu/zap firmware early (initrd), see `tools/mkcpio.py` |
| Display, backlight, keyboard, touchpad | ✅ | |
| Wi-Fi, Bluetooth, webcam, SD, USB-C, battery | ✅ | |
| Audio (speakers, HDMI, mics) | ✅ | UCM fix (`Idea[Pp]ad`) + ADSP firmware in initrd |
| Fingerprint (Goodix 27c6:650a) | ✅ | libfprint |
| Video decode/encode (Iris) | ✅ | backport in `dkms/`; DTB needs `iommus` on the main iris node |
| Suspend (deep) | ✅ | lid close/open verified |
| Fan/temperatures via EC | ❌ experimental | real EC is Lenovo's at i2c5 @0x60 (not 0x76). Driver `lenovo-83hl-ec` probes but reads zeros |
| NPU (Hexagon, fastrpc-cdsp) | ❌ | CDSP boots then stays silent (glink); same as [qualcomm/fastrpc#405](https://github.com/qualcomm/fastrpc/issues/405) |
| Ambient light / presence / orientation sensors | n/a | placeholders in firmware, do not exist |

## Things learned (reusable on other Snapdragon X laptops)
- **ADSP/CDSP firmware must be in the initrd**, otherwise remoteproc fails at 0.8 s with -2 and never retries
  (no audio, no battery, no USB-C, GPU on llvmpipe).
- **MOK not in the kernel keyring** when modules load: `load_uefi_certs` runs before efivars exist (qseecom uefisecapp).
  Fix: embed the cert into the kernel's `system_extra_cert` (`overlay/usr/local/sbin/83hl-kernel-cert`).
- **Iris resets the SoC** if the DTB uses the new `non-pixel/pixel` sub-nodes with the backported driver: put `iommus` on the main node.
- **Never detach the USB stick** while the live system runs: the whole disk is mounted on /cdrom; the helper
  `log83_mount` mounts the `83HL-LOG` FAT partition via loop+offset instead.
- **Windows → Linux resource hints:** `RCDS.bin` in the Windows CDSP driver lists the rails Windows votes at start
  (`rail_cx/mxa/mxc/nsp=384, xo`, bus ebi/clkctl); Linux `pas` never votes `mxa`/clkctl. Hypothesis for the silent CDSP; the
  `cdsp-keepalive-83hl` module reproduces those votes. **Not proven to help.**

## Open work, good first issues
1. NPU: make the CDSP answer fastrpc requests (test with `sudo 83hl-risky-test npu`; waits ≥40 s after forcing a request).
2. EC: find why reads return zeros (ACPI `ECNR`: write cmd 0x62 [0xB0,reg,0,0,0], read cmd 0x61 ×6 bytes; `delay_us` module parameter).
3. Upstream: Iris purwa series, X1P42100 videocc, 83HL DTS.
