#!/bin/bash
# Compila i DTB 83HL. Se esiste dts/<nome>-83hl.dts (aggiunte locali) usa quello, altrimenti l'originale di Glathe.
# Uso: build-dtb.sh [lcd|oled]
set -e
ROOT=${ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}
V=${1:-lcd}; K=${GLATHE:-$ROOT/src/glathe}; L=$ROOT/dts; O=$ROOT/out; mkdir -p $O
N=x1p42100-lenovo-ideapad-slim5x-$V.dts
SRC=$K/arch/arm64/boot/dts/qcom/$N; [ -f $L/${N%.dts}-83hl.dts ] && SRC=$L/${N%.dts}-83hl.dts
PP=$(mktemp)
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I $K/arch/arm64/boot/dts/qcom -I $K/include -I $K/arch/arm64/boot/dts -I $K/scripts/dtc/include-prefixes \
  "$SRC" -o $PP
dtc -@ -I dts -O dtb -q -o $O/${N%.dts}.dtb $PP
rm -f $PP; ls -la $O/${N%.dts}.dtb
