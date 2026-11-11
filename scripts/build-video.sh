#!/bin/bash
# Compila qcom-iris + videocc-x1p42100 (non firmati) per i kernel Ubuntu indicati -> out/modules/<kver>/
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}
D=$ROOT/dkms/83hl-drivers-1.0
for K in "${@:-7.0.0-30-generic 7.0.0-43-generic}"; do
  for k in $K; do
    O=$ROOT/out/modules/$k; mkdir -p "$O"
    B=$(mktemp -d); cp -r "$D"/. "$B"/
    make -s -C /usr/src/linux-headers-$k M=$B CC=gcc-15 modules -j8 2>&1 | grep -vE 'differs from the one|Skipping BTF' || true
    strip --strip-debug "$B/iris/qcom-iris.ko" "$B/clk/videocc-x1p42100.ko" "$B/ec/qcom-hamoa-ec.ko" "$B/ec/lenovo-83hl-ec.ko" "$B/npu/cdsp-keepalive-83hl.ko"
    install -m644 "$B/iris/qcom-iris.ko" "$B/clk/videocc-x1p42100.ko" "$B/ec/qcom-hamoa-ec.ko" "$B/ec/lenovo-83hl-ec.ko" "$B/npu/cdsp-keepalive-83hl.ko" "$O/"
    rm -rf "$B"; /usr/sbin/modinfo -F vermagic "$O/qcom-iris.ko" | sed "s/^/$k: /"
  done
done
