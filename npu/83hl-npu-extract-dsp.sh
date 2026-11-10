#!/bin/bash
# Estrae le librerie lato DSP del CDSP (fastrpc_shell_3, fastrpc_shell_unsigned_3, *_skel.so, libc++ Hexagon)
# dal DriverStore di Windows. Sceglie il pacchetto qcnspmcdm_ext_cdsp8380 il cui qccdsp8380.mbn ha lo STESSO
# sha256 del firmware usato da Linux: shell e firmware devono essere della stessa build (CDSP.HT.x-NNNNN).
# Sola lettura su Windows. Uso: 83hl-npu-extract-dsp.sh [radice_windows] [firmware_mbn] [destinazione]
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}
WIN=${1:-/mnt/c}
FW=${2:-$ROOT/overlay/usr/lib/firmware/qcom/x1p42100/LENOVO/83HL/qccdsp8380.mbn}
DST=${3:-$ROOT/npu/dsp/cdsp}
FR="$WIN/Windows/System32/DriverStore/FileRepository"
[ -f "$FW" ] || { echo "KO: firmware $FW assente"; exit 1; }
H=$(sha256sum "$FW" | cut -d' ' -f1); SRC=
for d in "$FR"/qcnspmcdm_ext_cdsp8380.inf_arm64_*/; do
  [ -f "$d/qccdsp8380.mbn" ] && [ "$(sha256sum "$d/qccdsp8380.mbn" | cut -d' ' -f1)" = "$H" ] && { SRC=$d; break; }
done
[ -n "$SRC" ] || { echo "KO: nessun pacchetto qcnspmcdm_ext_cdsp8380 con firmware sha256 $H"; exit 1; }
[ -f "$SRC/CDSP/fastrpc_shell_unsigned_3" ] || { echo "KO: $SRC/CDSP senza fastrpc_shell_unsigned_3"; exit 1; }
mkdir -p "$DST"
for f in "$SRC"/CDSP/*; do case "$f" in *.txt) ;; *) install -m644 "$f" "$DST/";; esac; done
bld() { grep -a -o 'CDSP\.HT\.[0-9a-z.]*-[0-9]*' "$1" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}'; }
{ echo "sorgente: $(basename "$SRC")"; echo "firmware sha256: $H"; echo "build firmware: $(bld "$FW")"; echo "build shell: $(bld "$DST/fastrpc_shell_unsigned_3")"; } > "$DST/SOURCE.txt"
( cd "$DST" && sha256sum $(ls | grep -v -e SOURCE.txt -e SHA256SUMS.txt) > SHA256SUMS.txt )
cat "$DST/SOURCE.txt"; ls -la "$DST"
[ "$(bld "$FW")" = "$(bld "$DST/fastrpc_shell_unsigned_3")" ] || { echo "KO: build shell diversa dal firmware"; exit 1; }
