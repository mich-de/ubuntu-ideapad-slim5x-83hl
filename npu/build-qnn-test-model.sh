#!/bin/bash
# Compila il modello di esempio QAIRT (conv+relu 8 bit, 1x299x299x3) in una model-lib aarch64 per qnn-net-run.
# Replica share/QNN/converter/Makefile.oe-linux-aarch64-gcc11.2 con il g++ nativo (WSL aarch64 = stessa ABI del target).
# Output: $ROOT/npu/qnn-test/{libqnn_model_8bit_quantized.so,input.raw,input_list.txt}
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}
N=$ROOT/npu
Q=${QNN_SDK_ROOT:-$(ls -d $N/qairt/qairt/*/ | sort -V | tail -1)}; Q=${Q%/}
M=${1:-qnn_model_8bit_quantized}
# g++ non installato in WSL: cc1plus + header libstdc++ estratti con apt-get download in build/cxx (niente sudo)
X=$N/build/cxx
if command -v g++-15 >/dev/null; then CXX=${CXX:-g++-15}; LSTD=-lstdc++
else CXX="gcc-15 -B$X/usr/libexec/gcc/aarch64-linux-gnu/15 -isystem $X/usr/include/c++/15 -isystem $X/usr/include/aarch64-linux-gnu/c++/15"; LSTD=/usr/lib/aarch64-linux-gnu/libstdc++.so.6; fi
W=$N/build/qnnmodel; O=$N/qnn-test
rm -rf "$W"; mkdir -p "$W/jni" "$W/obj/binary" "$W/obj/o" "$O"
cp "$Q"/share/QNN/converter/jni/*.cpp "$Q"/share/QNN/converter/jni/*.hpp "$Q"/share/QNN/converter/jni/linux/QnnModelPal.cpp "$W/jni/"
cp "$Q/examples/QNN/converter/models/$M.cpp" "$W/jni/"
tar xf "$Q/examples/QNN/converter/models/$M.bin" -C "$W/obj/binary"
cd "$W"
objs=()
for r in obj/binary/*.raw; do o=obj/o/$(basename "${r%.raw}").o; objcopy -I binary -O elf64-littleaarch64 -B aarch64 "$r" "$o"; objs+=("$o"); done
for c in jni/*.cpp; do o=obj/o/$(basename "${c%.cpp}").cc.o
  $CXX -c -std=gnu++11 -D_LINUX_OE_SOURCE -fPIC -O3 -fno-exceptions -fno-rtti -Wno-write-strings -fvisibility=hidden \
    -DQNN_API='__attribute__((visibility("default")))' -Ijni -I"$Q/include/QNN" "$c" -o "$o"; objs+=("$o"); done
$CXX -shared -s -fPIC -fvisibility=hidden "${objs[@]}" -o "$O/lib$M.so" $LSTD
# input: primo raw float dell'esempio
cp "$Q/examples/QNN/converter/models/input_data_float/1x299x299x3_float_1.raw" "$O/input.raw"
echo "input.raw" > "$O/input_list.txt"
ls -la "$O"
