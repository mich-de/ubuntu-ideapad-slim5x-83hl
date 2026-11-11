#!/bin/bash
# Crea la ISO Ubuntu 26.04.1 arm64 per Lenovo IdeaPad Slim 5x 14Q8X9 (83HL).
# - strato live con firmware 83HL, fix UCM, regole impronta, 83hl-test
# - /83hl sulla ISO: DTB, overlay.tar, 83hl-install-target
# - GRUB: voce predefinita con 'devicetree' 83HL
# - partizione FAT 83HL-LOG per i report di test
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}
cd $ROOT
ISO=iso/ubuntu-26.04.1-desktop-arm64.iso
OUT=out/ubuntu-26.04.1-83hl-arm64.iso
W=$(mktemp -d $ROOT/.work.XXXX); trap 'sudo rm -rf "$W"' EXIT
LIVE=casper/minimal.standard.live.squashfs

scripts/build-dtb.sh lcd
tools/extract-firmware.sh >/dev/null
# moduli 83HL (scripts/build-video.sh) e sign-file nell'overlay
[ -d out/modules ] || { echo "manca out/modules: lancia scripts/build-video.sh"; exit 1; }
mkdir -p overlay/usr/lib/83hl/modules overlay/usr/local/lib/83hl
cp -r out/modules/* overlay/usr/lib/83hl/modules/
rm -rf overlay/usr/src/83hl-drivers-1.0; mkdir -p overlay/usr/src; cp -r dkms/83hl-drivers-1.0 overlay/usr/src/
install -m755 /usr/src/linux-headers-$(ls out/modules | head -1)/scripts/sign-file overlay/usr/local/lib/83hl/sign-file
install -D -m644 out/x1p42100-lenovo-ideapad-slim5x-lcd.dtb overlay/usr/lib/83hl/x1p42100-lenovo-ideapad-slim5x-lcd.dtb
[ -f debs/stubble_9-1_arm64.deb ] || { echo "manca debs/ (apt-get download ...)"; exit 1; }

echo "== Kernel UKI firmato (chiave MOK della ISO)"
osirrox -indev "$ISO" -extract /casper/vmlinuz "$W/vmlinuz.orig" 2>/dev/null
mkdir -p "$W/stubble"; dpkg-deb -x debs/stubble_9-1_arm64.deb "$W/stubble"
KVI=$(python3 -I -c "import pefile,sys;pe=pefile.PE(sys.argv[1],fast_load=True);print([s.get_data()[:s.Misc_VirtualSize] for s in pe.sections if s.Name.startswith(b'.uname')][0].decode().strip(chr(0)).strip())" "$W/vmlinuz.orig")
dpkg-deb --fsys-tarfile hdr/linux-modules-${KVI}_*.deb | tar -xO ./boot/System.map-$KVI > "$W/System.map"
SYSMAP="$W/System.map" overlay/usr/local/sbin/83hl-build-uki "$W/vmlinuz.orig" "$W/vmlinuz" keys overlay/usr/lib/83hl overlay/usr/share/83hl/hwids \
  "$W/stubble/usr/lib/stubble/stubble.efi" "$W/stubble/usr/share/stubble/sbat" | tail -3

echo "== Overlay tar"
sudo tar --owner=0 --group=0 -C overlay -cpf "$W/overlay.tar" .

echo "== Strato live"
osirrox -indev "$ISO" -extract /$LIVE "$W/live.sfs" 2>/dev/null
sudo unsquashfs -q -d "$W/live" "$W/live.sfs"
sudo tar -C "$W/live" -xpf "$W/overlay.tar"
# x1e80100.conf della ISO (strato minimal) con la regex corretta, messo nello strato live
osirrox -indev "$ISO" -extract /casper/minimal.squashfs "$W/min.sfs" 2>/dev/null
sudo unsquashfs -q -d "$W/min" "$W/min.sfs" usr/share/alsa/ucm2/Qualcomm/x1e80100/x1e80100.conf \
  usr/lib/firmware/qcom/gen71500_sqe.fw.zst usr/lib/firmware/qcom/gen71500_gmu.bin.zst
sudo install -D -m644 "$W/min/usr/share/alsa/ucm2/Qualcomm/x1e80100/x1e80100.conf" "$W/live/usr/share/alsa/ucm2/Qualcomm/x1e80100/x1e80100.conf"
sudo sed -i 's/Ideapad\.\*5/Idea[Pp]ad.*5/' "$W/live/usr/share/alsa/ucm2/Qualcomm/x1e80100/x1e80100.conf"
grep -q 'Idea\[Pp\]ad' "$W/live/usr/share/alsa/ucm2/Qualcomm/x1e80100/x1e80100.conf"
echo "== Firmware ADSP/CDSP/GPU in un initrd aggiuntivo (i remoteproc partono prima di montare /)"
F=usr/lib/firmware/qcom; L=$F/x1p42100/LENOVO/83HL
A=(); for f in qcadsp8380.mbn adsp_dtbs.elf qccdsp8380.mbn cdsp_dtbs.elf qcdxkmsucpurwa.mbn; do A+=("$L/$f=overlay/$L/$f"); done
for f in gen71500_sqe.fw.zst gen71500_gmu.bin.zst; do A+=("$F/$f=$W/min/$F/$f"); done
python3 -I tools/mkcpio.py "$W/83hl-fw.img" "${A[@]}"; ls -la "$W/83hl-fw.img"
rm -f "$W/min.sfs"

echo "== Moduli video 83HL nella live (kernel della ISO)"
KV=$(python3 -I -c "import pefile,sys;pe=pefile.PE(sys.argv[1],fast_load=True);print([s.get_data()[:s.Misc_VirtualSize] for s in pe.sections if s.Name.startswith(b'.uname')][0].decode().strip(chr(0)).strip())" "$W/vmlinuz.orig")
echo "kernel ISO: $KV"
[ -d "overlay/usr/lib/83hl/modules/$KV" ] || { echo "manca out/modules/$KV: lancia scripts/build-video.sh $KV"; exit 1; }
MD="$W/kmods"; mkdir -p "$MD"; dpkg-deb -x hdr/linux-modules-${KV}_*.deb "$MD"; mkdir -p "$MD/lib"; ln -sfn ../usr/lib/modules "$MD/lib/modules"
mkdir -p "$MD/usr/lib/modules/$KV/updates/83hl"
for m in overlay/usr/lib/83hl/modules/$KV/*.ko; do
  install -m644 "$m" "$MD/usr/lib/modules/$KV/updates/83hl/"
  /usr/src/linux-headers-$KV/scripts/sign-file sha512 keys/MOK.key keys/MOK.crt "$MD/usr/lib/modules/$KV/updates/83hl/$(basename "$m")"
done
/usr/sbin/depmod -b "$MD" "$KV"
/usr/sbin/modinfo -b "$MD" -k "$KV" -F filename qcom_iris videocc_x1p42100
sudo mkdir -p "$W/live/usr/lib/modules/$KV/updates"
sudo cp -r "$MD/usr/lib/modules/$KV/updates/83hl" "$W/live/usr/lib/modules/$KV/updates/"
sudo cp "$MD"/usr/lib/modules/$KV/modules.* "$W/live/usr/lib/modules/$KV/"
rm -rf "$MD"
sudo mksquashfs "$W/live" "$W/live.new.sfs" -comp xz -b 131072 -xattrs -noappend -quiet
sudo chown "$(id -u)" "$W/live.new.sfs"

echo "== File ISO /83hl e grub.cfg"
mkdir -p "$W/83hl/debs"
cp debs/*.deb "$W/83hl/debs/"
cp keys/MOK.der "$W/83hl/MOK-ISO.der"
cp keys/MOK.der "$W/MOK-83HL.der"
cp "$W/overlay.tar" overlay-iso/83hl/83hl-install-target overlay/usr/local/bin/83hl-test "$W/83hl/"
osirrox -indev "$ISO" -extract /boot/grub/grub.cfg "$W/grub.orig" 2>/dev/null
python3 -I - "$W/grub.orig" "$W/grub.cfg" <<'EOF'
import sys
g=open(sys.argv[1]).read()
entry='''menuentry "Ubuntu 83HL - IdeaPad Slim 5x (Secure Boot)" {
    set gfxpayload=keep
    linux  /casper/vmlinuz $cmdline  --- quiet splash console=tty0
    initrd /casper/initrd
}
menuentry "Ubuntu 83HL - debug (testo, log completi)" {
    linux  /casper/vmlinuz $cmdline  --- console=tty0 ignore_loglevel
    initrd /casper/initrd
}
menuentry "Ubuntu 83HL - senza audio, decoder video ed EC (se la prima voce si riavvia)" {
    linux  /casper/vmlinuz $cmdline  --- console=tty0 ignore_loglevel module_blacklist=snd_soc_x1e80100,qcom_iris,videocc_x1p42100,lenovo_83hl_ec
    initrd /casper/initrd
}
menuentry "Ubuntu 83HL - senza ADSP/CDSP/GPU anticipati (se anche la precedente si riavvia)" {
    linux  /casper/vmlinuz $cmdline  --- console=tty0 ignore_loglevel 83hl.nofw
    initrd /casper/initrd
}
menuentry "Registra chiave 83HL (MokManager: Enroll key from disk)" {
    chainloader /EFI/boot/mmaa64.efi
}
'''
k='menuentry "Try or Install Ubuntu"'
assert k in g
g=g.replace(k, entry+k,1)
import re
g=re.sub(r'(^\s*initrd\s+/casper/initrd)\s*$', r'\1 /casper/83hl-fw.img', g, flags=re.M)
g=re.sub(r'(83hl\.nofw\n\s*initrd\s+/casper/initrd) /casper/83hl-fw.img', r'\1', g)
assert g.count('/casper/83hl-fw.img')==len(re.findall(r'initrd\s+/casper/initrd',g))-1>=4
open(sys.argv[2],'w').write(g)
EOF

echo "== md5sum.txt"
osirrox -indev "$ISO" -extract /md5sum.txt "$W/md5.orig" 2>/dev/null
chmod u+w "$W/md5.orig"
python3 -I - "$W" <<'EOF'
import sys,hashlib,os
w=sys.argv[1]
def md5(p):
    h=hashlib.md5()
    with open(p,'rb') as f:
        for c in iter(lambda:f.read(1<<20),b''): h.update(c)
    return h.hexdigest()
repl={'./casper/minimal.standard.live.squashfs':md5(w+'/live.new.sfs'),'./boot/grub/grub.cfg':md5(w+'/grub.cfg'),'./casper/vmlinuz':md5(w+'/vmlinuz')}
out=[]
for l in open(w+'/md5.orig'):
    h,p=l.rstrip('\n').split('  ',1)
    out.append(f'{repl.get(p,h)}  {p}')
for r,_,fs in os.walk(w+'/83hl'):
    for f in sorted(fs):
        q=os.path.join(r,f); out.append(f'{md5(q)}  ./'+os.path.relpath(q,w))
out.append(f'{md5(w+"/MOK-83HL.der")}  ./MOK-83HL.der')
out.append(f'{md5(w+"/83hl-fw.img")}  ./casper/83hl-fw.img')
open(w+'/md5sum.txt','w').write('\n'.join(out)+'\n')
EOF

echo "== Partizione 83HL-LOG (64 MB FAT32)"
truncate -s 64M "$W/log.img"; mkfs.vfat -n 83HL-LOG -F 32 "$W/log.img" >/dev/null
sed 's/$/\r/' overlay-iso/LEGGIMI.txt > "$W/LEGGIMI.txt"; mcopy -i "$W/log.img" "$W/LEGGIMI.txt" "$W/MOK-83HL.der" overlay-iso/raccogli.sh ::/   # MokManager non legge ISO9660: la chiave sta anche qui

echo "== ISO"
rm -f "$OUT"
xorriso -indev "$ISO" -outdev "$OUT" -boot_image any replay \
  -append_partition 3 0x0c "$W/log.img" \
  -map "$W/live.new.sfs" /$LIVE \
  -map "$W/grub.cfg" /boot/grub/grub.cfg \
  -map "$W/vmlinuz" /casper/vmlinuz \
  -map "$W/MOK-83HL.der" /MOK-83HL.der \
  -map "$W/83hl-fw.img" /casper/83hl-fw.img \
  -map "$W/md5sum.txt" /md5sum.txt \
  -map "$W/83hl" /83hl 2>&1 | grep -vE "^xorriso : UPDATE" | tail -15
sha256sum "$OUT" | tee "$OUT.sha256"
ls -la "$OUT"
