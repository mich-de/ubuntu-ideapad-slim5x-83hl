# Ubuntu 26.04 on Lenovo IdeaPad Slim 5x 14Q8X9 (83HL) — with Secure Boot ON

Build kit, device tree additions, kernel drivers and hardware analysis to run **Ubuntu 26.04.1 (arm64)**
on the **Lenovo IdeaPad Slim 5x 14Q8X9, machine type 83HL** (Snapdragon X Plus **X1P42100** "Purwa",
Adreno X1-45, LCD panel), **keeping UEFI Secure Boot enabled**.

> **Status: boot-tested on one machine** (Ubuntu 26.04.1, kernel 7.0.0-43, Secure Boot ON). Works: boot, GPU, display, audio,
> Wi-Fi, Bluetooth, webcam, fingerprint, SD, battery, USB-C, video decode/encode, deep suspend.
> **Not working yet:** NPU and fan/temperature EC. Full table: [`docs/STATUS.md`](docs/STATUS.md).
> Experimental — test reports and issues welcome (use the "Test report" issue template).

> **Secure Boot first:** if the stick is rejected ("boot failed"), your firmware db lacks *Microsoft UEFI CA 2011*:
> follow [`secureboot/README.md`](secureboot/README.md).

Italian end-user instructions: [`overlay-iso/LEGGIMI.txt`](overlay-iso/LEGGIMI.txt).

## Why this exists
- Ubuntu's kernel (7.0) ships **no device tree for the 83HL**. The board DTS exists only out of tree
  ([Jens Glathe's tree](https://github.com/jglathe/linux_ms_dev_kit)) and as an upstream series not yet merged.
- With Secure Boot on, GRUB runs in **lockdown** and refuses `devicetree`, so the usual "load a DTB from GRUB" trick fails.
- Several pieces (video decoder, embedded controller) are missing in the 7.0 kernel for this SoC.

## What this kit does
| Area | Approach |
|---|---|
| **Boot with Secure Boot** | Extract `.linux` from Canonical's stubble UKI, rebuild it with `ukify` embedding **only the 83HL DTB** + **83HL hwids (CHIDs)** + stubble SBAT, sign it with a local **MOK**. shim → GRUB → our UKI. Enrol the key once via MokManager ("Enroll key from disk"). |
| CHIDs | Computed with [`tools/chid.py`](tools/chid.py) (same algorithm as `systemd/src/fundamental/chid.c`); 8/8 SMBIOS CHIDs match systemd's published 83HL OLED file, 3 extra EDID-based ones for the LCD panel (LEN9120). |
| Installed system | [`83hl-install-target`](overlay-iso/83hl/83hl-install-target) generates a **new per-machine MOK**, re-signs kernels, queues the key with `mokutil`. A kernel hook (`zz-83hl-uki`) re-wraps and re-signs every future kernel. |
| Firmware | [`tools/extract-firmware.sh`](tools/extract-firmware.sh) copies GPU zap, Iris, ADSP, CDSP firmware from the Windows DriverStore (highest driver version, UTF-16 INF aware). **Not redistributed here.** |
| Audio | **Bug fix**: alsa-ucm-conf matches `Ideapad.*5`, but the 83HL DMI says `IdeaPad` → speakers never configured. `83hl-fix-ucm` + apt hook make it `Idea[Pp]ad`. Topology symlink to the Romulus/T14s one. |
| **Video decode (Iris)** | Backport of the upstream "media: iris: add support for purwa platform" v7 series onto the **v7.0** driver (BSE clock in `iris_vpu_power_on_hw`, `x1p42100_data` = SM8550 data with X1P42100 clocks, `vpu30_p1_s7` fw, `num_vpp_pipe = 1`) + `videocc-x1p42100`. See [`docs/patches/`](docs/patches/). |
| **Fan / EC** | ❌ The 83HL EC is **Lenovo's**, on `i2c5` @ **0x60** (100 kHz, ACPI `\_SB.I2C6` `ECNR/ECNW`). Read-only hwmon driver `lenovo-83hl-ec` probes but still reads zeros (debugging). The Qualcomm-reference `qcom-hamoa-ec` (0x76 is only a placeholder here) is kept but unused. |
| Fingerprint (Goodix 27c6:650a) | Already in libfprint; udev rule disables autosuspend + `fprintd` restart after resume. |
| Modules & Secure Boot | All extra modules are **MOK-signed** (Ubuntu has `CONFIG_INTEGRITY_MACHINE_KEYRING=y`). Prebuilt for 7.0.0-30/-43, DKMS package [`dkms/83hl-drivers-1.0`](dkms/83hl-drivers-1.0) for later kernels. |
| Firmware early boot | `tools/mkcpio.py` builds `/casper/83hl-fw.img` (ADSP/CDSP/GPU firmware) loaded as 2nd initrd; installed system uses `dracut`/`initramfs-tools` hooks. Without it audio, battery, USB-C and GPU come up late or never. |
| Test | [`83hl-finale`](overlay/usr/local/bin/83hl-finale) runs [`83hl-test`](overlay/usr/local/bin/83hl-test) prints an OK/KO summary and a full report onto a FAT partition (`83HL-LOG`) appended to the USB image. |

## Findings that may help other Snapdragon X laptops
### Windows ACPI GPIO → Linux TLMM GPIO (Qualcomm "direct-connect" interrupts)
GPIO numbers in `GpioInt(... "\\_SB.GIO0" ...)` that are multiples of 64 are not TLMM pins:
1. `index = pin / 64` → entry in the `Interrupt()` list of `\_SB.GIO0._CRS` → GSIV
2. `SPI = GSIV − 32`
3. SPI → PDC pin through `qcom,pdc-ranges` (hamoa.dtsi)
4. PDC pin → GPIO through `x1e80100_pdc_map[]` (pinctrl-x1e80100.c)

Verified on this machine: lid `0x340` → gpio92, touchpad `0x380` → gpio3, keyboard `0x180` → gpio67, EC `0x140` → **gpio66**.

### Windows `I2Cn` = Linux `i2c(n-1)`
The EC sits on Windows `\_SB.I2C6`, which is Linux `&i2c5` (same bus as the four PTN3222 eUSB2 repeaters).

### Sensors: there are none
`QCOM0693/QCOM0694` ("All-Ways Aware Sensor Platform") and `QCOM06D9` ("Human Presence Sensor") have **no `_CRS`**,
the DSDT reports platform `CRD08380` and only the CRD sensor configuration is installed: they are reference-firmware
placeholders. Windows' own sensor APIs return `null` for every sensor type. Details: [`analysis/sensors/`](analysis/sensors/).

### Device tree compatibility with Ubuntu 7.0
Missing drivers in the stock 7.0 kernel for this DTB: `qcom,x1p42100-iris`, `qcom,x1p42100-videocc`, `qcom,hamoa-crd-ec`
(all provided here), plus `qcom,x1p42100-camcc`, `qcom,spmi-adc5-gen3`, `qcom,x1e80100-ctcu` (not needed).

## Repository layout
```
scripts/      build-iso.sh  build-dtb.sh  build-video.sh
tools/        extract-firmware.sh  chid.py  dtb-compat-check.py
dts/          83HL DTS wrapper (adds the EC node) on top of Glathe's DTS
dkms/         83hl-drivers-1.0: iris (X1P42100), videocc-x1p42100, qcom-hamoa-ec
overlay/      files installed into the live session and the installed system
overlay-iso/  83hl-install-target, LEGGIMI.txt (user instructions, Italian)
acpi/         DSDT/SSDT dumped from Windows on an 83HL (BIOS 1.55), .aml + decompiled .dsl
analysis/     sensors investigation with evidence
npu/          Hexagon NPU: FastRPC userspace build, DSP extraction, QAIRT fetch, setup/test scripts
secureboot/   fix for firmware db lacking Microsoft UEFI CA 2011 (dump, build db, apply)
docs/         STATUS.md, sample test reports, driver diffs, upstream purwa v7 series (mbox)
```

## Building
Requirements (Ubuntu 26.04 arm64, native or WSL2 on the laptop): `xorriso squashfs-tools device-tree-compiler cpp
mtools dosfstools systemd-ukify sbsigntool python3-pefile gcc-15 make kmod`, plus `linux-headers-7.0.0-30-generic`
(the ISO kernel) and any other target kernel.

```sh
git clone --depth 1 --filter=blob:none --sparse -b jg/ubuntu-qcom-x1e-7.3.y \
    https://github.com/jglathe/linux_ms_dev_kit.git src/glathe
(cd src/glathe && git sparse-checkout set arch/arm64/boot/dts/qcom include/dt-bindings include/uapi/linux scripts/dtc/include-prefixes)
# MOK for the live image (keep MOK.key private!)
mkdir -p keys && openssl req -new -x509 -newkey rsa:2048 -nodes -days 36500 -sha256 \
  -subj "/CN=83HL kernel signing (local MOK)/" -addext "extendedKeyUsage=codeSigning" \
  -keyout keys/MOK.key -out keys/MOK.crt && openssl x509 -in keys/MOK.crt -outform DER -out keys/MOK.der
# Ubuntu ISO + helper packages
mkdir -p iso debs hdr   # put ubuntu-26.04.1-desktop-arm64.iso in iso/
(cd debs && apt-get download systemd-ukify sbsigntool stubble python3-pefile mokutil python3-zstandard python3-libfdt libfdt1)
(cd hdr && apt-get download linux-modules-7.0.0-30-generic)
scripts/build-video.sh 7.0.0-30-generic 7.0.0-43-generic
scripts/build-iso.sh     # runs build-dtb.sh and extract-firmware.sh (needs the Windows partition at /mnt/c)
```
Write `out/ubuntu-26.04.1-83hl-arm64.iso` **raw (DD mode)** to a USB stick, then:
1. Boot it (F12). shim → MokManager → *Enroll key from disk* → `MOK-83HL.der` (on the FAT partition `83HL-LOG`).
2. Pick "Ubuntu 83HL". **Never unplug the stick** while it runs.
3. In a terminal: `sudo 83hl-finale` — runs the checks and writes reports to `83HL-LOG`. Attach them to a "Test report" issue
   (review for serials/MAC first).
4. Install with the Ubuntu installer, then **before rebooting** run `sudo /cdrom/83hl/83hl-install-target`
   (new per-machine MOK + signed UKI + firmware in the initramfs; `mokutil` asks for a password for MokManager).


## Known limits
- Hexagon **NPU**: *CDSP boots but does not answer FastRPC* ([qualcomm/fastrpc#405](https://github.com/qualcomm/fastrpc/issues/405)); stack prepared in [`npu/`](npu/) (kernel `fastrpc` + DT already complete; open-source `libcdsprpc` built from source; DSP unsigned shell and `libc++` extracted from the Lenovo Windows driver, same build as the CDSP firmware; QAIRT 2.47 downloaded by script, not redistributed). FastRPC on unsigned PD: likely. QNN HTP inference: uncertain (real `soc_id` unknown).
- No ambient-light / presence / orientation sensors exist on this model (see above).
- Iris in browsers is still experimental; use V4L2 M2M players (mpv, GStreamer, ffmpeg).

## Credits
- **Jens Glathe** — 83HL device tree and X1P42100 work ([linux_ms_dev_kit](https://github.com/jglathe/linux_ms_dev_kit)).
- Qualcomm/Linaro kernel developers — Iris purwa series, `qcom-hamoa-ec`, Snapdragon X upstreaming.
- systemd (`ukify`, CHID/hwids), Canonical (`stubble`, shim/GRUB signing), libfprint, alsa-ucm-conf.

## License
Kernel code (`dkms/`) and scripts: **GPL-2.0** (see `LICENSE`). Device tree files keep their original
BSD-3-Clause headers. ACPI tables are dumps of the vendor firmware, provided for interoperability research.
No Qualcomm/Lenovo firmware binaries are included. No warranty: you can make the machine unbootable from Linux
(Windows stays untouched) — keep the Windows boot entry and BitLocker recovery key at hand.
