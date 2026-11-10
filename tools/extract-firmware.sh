#!/bin/bash
# Estrae i firmware Qualcomm 83HL dal DriverStore di Windows (versione driver più alta per ogni INF).
# Uso: extract-firmware.sh [radice_windows] [destinazione]
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}
WIN=${1:-/mnt/c}; DST=${2:-$ROOT/overlay/usr/lib/firmware/qcom/x1p42100/LENOVO/83HL}
FR="$WIN/Windows/System32/DriverStore/FileRepository"
mkdir -p "$DST"
pick() { # $1=nome inf -> cartella con DriverVer più alta
  for d in "$FR"/$1.inf_arm64_*/; do
    # INF spesso in UTF-16LE: decodifica con BOM, poi estrae la versione dopo la virgola
    v=$(python3 -I -c 'import sys,re;b=open(sys.argv[1],"rb").read();t=b.decode("utf-16") if b[:2] in (b"\xff\xfe",b"\xfe\xff") else b.decode("utf-8","ignore");m=re.search(r"(?im)^\s*DriverVer\s*=\s*[^,]*,\s*([0-9.]+)",t);print(m.group(1) if m else "0")' "$d/$1.inf")
    echo "$v $d"
  done | sort -V | tail -1 | cut -d' ' -f2-
}
declare -A FILES=(
  [qcdx8380]="qcdxkmsucpurwa.mbn qcvss8380_pa.mbn"
  [qcsubsys_ext_adsp8380]="qcadsp8380.mbn adsp_dtbs.elf adspr.jsn adsps.jsn adspua.jsn battmgr.jsn"
  [qcnspmcdm_ext_cdsp8380]="qccdsp8380.mbn cdsp_dtbs.elf cdspr.jsn"
)
for inf in "${!FILES[@]}"; do
  d=$(pick $inf); echo "$inf <- $(basename "$d")"
  for f in ${FILES[$inf]}; do install -m644 "$d/$f" "$DST/$f"; done
done
( cd "$DST" && sha256sum * > SHA256SUMS.txt && ls -la )
