#!/bin/bash
# Assembla $ROOT/npu/overlay (albero pronto da copiare in $ROOT/overlay prima di build-iso.sh).
# Prerequisiti: ./build-fastrpc.sh ; ./83hl-npu-extract-dsp.sh ; (opz.) qairt/ + ./build-qnn-test-model.sh
# Uso: build-npu-payload.sh [--no-qairt]
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}
N=$ROOT/npu; O=$N/overlay; P=$O/usr/lib/83hl/npu
[ -f $N/stage/usr/local/lib/libcdsprpc.so.1.0.0 ] || { echo "manca stage: ./build-fastrpc.sh"; exit 1; }
[ -f $N/dsp/cdsp/fastrpc_shell_unsigned_3 ] || { echo "manca dsp: ./83hl-npu-extract-dsp.sh"; exit 1; }
rm -rf "$O"; install -d "$P/debs" "$O/usr/local/sbin" "$O/usr/local/bin"
install -m755 $N/83hl-npu-setup "$O/usr/local/sbin/"; install -m755 $N/83hl-npu-test "$O/usr/local/bin/"
cp -al $N/stage "$P/stage"
install -d "$P/dsp"; cp -al $N/dsp/cdsp "$P/dsp/cdsp"
cp -l $N/build/debs/libyaml-0-2_*.deb $N/build/debs/libbsd0_*.deb $N/build/debs/libmd0_*.deb "$P/debs/"
Q=$(ls -d $N/qairt/qairt/*/ 2>/dev/null | sort -V | tail -1 || true)
if [ "${1:-}" != "--no-qairt" ] && [ -n "$Q" ]; then
  V=$(basename "$Q"); D=$P/qairt/$V; install -d "$D/bin" "$D/lib/hexagon-v73"
  cp -al "$Q/bin/aarch64-oe-linux-gcc11.2" "$D/bin/"; cp -al "$Q/lib/aarch64-oe-linux-gcc11.2" "$D/lib/"
  cp -al "$Q/lib/hexagon-v73/unsigned" "$D/lib/hexagon-v73/"; cp -l "$Q/LICENSE.pdf" "$Q/NOTICE.txt" "$D/"
  chmod 755 "$D"/bin/aarch64-oe-linux-gcc11.2/*
  [ -f $N/qnn-test/libqnn_model_8bit_quantized.so ] && cp -al $N/qnn-test "$P/qnn-test"
fi
( cd "$O" && find . -type f | sort | xargs sha256sum > "$N/overlay.SHA256SUMS" )
du -sh "$O"; find "$O" -maxdepth 6 -type d | sed "s|$O||" | sort | head -40
