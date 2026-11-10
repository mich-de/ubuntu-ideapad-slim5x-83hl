#!/bin/bash
# Compila qualcomm/fastrpc (libcdsprpc, cdsprpcd, fastrpc_test, fastrpc-healthcheck) senza autotools,
# replicando src/Makefile.am e test/Makefile.am. Gira in WSL aarch64 (Ubuntu 26.04 = stessa ABI del target).
# Output: $ROOT/npu/stage  (albero da copiare in / sul sistema target, vedi 83hl-npu-setup)
# Uso: build-fastrpc.sh
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}
N=$ROOT/npu
S=$N/src/fastrpc
SR=$N/build/sysroot            # libyaml-dev, libbsd-dev, libmd-dev estratti con apt-get download + dpkg-deb -x
O=$N/build/obj
ST=$N/stage
CC=${CC:-gcc-15}
PREFIX=/usr/local
LIBDIR=$PREFIX/lib
CONFIG_BASE_DIR=/usr/share/qcom
TESTLIBDIR=$LIBDIR/fastrpc_test
TESTDSPDIR=$PREFIX/share/fastrpc_test

[ -d "$S/src" ] || { echo "manca $S (git clone https://github.com/qualcomm/fastrpc)"; exit 1; }
[ -f "$SR/usr/include/yaml.h" ] || { echo "manca sysroot dev in $SR"; exit 1; }

rm -rf "$O" "$ST"; mkdir -p "$O" "$ST"
INC="-I$S/inc -I$SR/usr/include -isystem $SR/usr/include/aarch64-linux-gnu/bsd -DLIBBSD_OVERLAY"
HARD="-O2 -g0 -fPIC -Wformat -Werror=format-security -Werror=implicit-function-declaration -fstack-protector-strong -fstack-clash-protection -mbranch-protection=standard"
BASE="$HARD -fno-short-enums -U_DEBUG -DARM_ARCH_7A -DLE_ENABLE -DENABLE_UPSTREAM_DRIVER_INTERFACE -DUSE_SYSLOG \
 -DCONFIG_BASE_DIR=\"$CONFIG_BASE_DIR\" -DMACHINE_NAME_PATH=\"/sys/firmware/devicetree/base/model\" \
 -DPARSE_YAML -DDEFAULT_DSP_SEARCH_PATHS=\";/usr/lib/rfsa/adsp;/usr/lib/dsp;\" $INC"
LDL="-L$SR/usr/lib/aarch64-linux-gnu -Wl,-z,relro -Wl,-z,now"

# sorgenti LIBDSPRPC_SOURCES da src/Makefile.am (+ fastrpc_config_parser.c per non-Android)
SRCS=$(python3 -I - "$S/src/Makefile.am" <<'EOF'
import re,sys
t=open(sys.argv[1]).read().replace('\\\n',' ')
m=re.search(r'^LIBDSPRPC_SOURCES\s*=\s*(.*)$',t,re.M)
print(' '.join(m.group(1).split()+['fastrpc_config_parser.c']))
EOF
)
LSRCS="adsp_default_listener.c adsp_default_listener_stub.c adsp_default_listener1_stub.c"

build_lib() { # nome dominio
  local name=$1 dom=$2 objs=() o
  mkdir -p "$O/$name"
  for f in $SRCS; do
    o="$O/$name/$(echo "$f" | tr / _).o"
    $CC $BASE -DDEFAULT_DOMAIN_ID=$dom -c "$S/src/$f" -o "$o"; objs+=("$o")
  done
  $CC -shared -Wl,-soname,lib$name.so.1 $LDL -o "$O/lib$name.so.1.0.0" "${objs[@]}" -ldl -lm -lyaml -lbsd -lpthread
}
build_listener() { # nome dominio libdsprpc
  local name=$1 dom=$2 base=$3 objs=() o
  mkdir -p "$O/$name"
  for f in $LSRCS; do
    o="$O/$name/$f.o"; $CC $BASE -DDEFAULT_DOMAIN_ID=$dom -c "$S/src/$f" -o "$o"; objs+=("$o")
  done
  $CC -shared -Wl,-soname,lib$name.so.1 $LDL -L"$O" -o "$O/lib$name.so.1.0.0" "${objs[@]}" -l:lib$base.so.1.0.0
}

echo "[1/4] libcdsprpc / libadsprpc"
build_lib cdsprpc 3
build_lib adsprpc 0
echo "[2/4] listener"
build_listener cdsp_default_listener 3 cdsprpc
echo "[3/4] cdsprpcd"
$CC $HARD -I$S/inc -DDEFAULT_DOMAIN_ID=3 -DUSE_SYSLOG -DUSE_CDSP $S/src/dsprpcd.c -o $O/cdsprpcd -ldl -Wl,-z,relro -Wl,-z,now
echo "[4/4] test"
$CC $HARD -I$S/inc -DUSE_SYSLOG -Dtestlibdir=\"$TESTLIBDIR\" -Dtestdspdir=\"$TESTDSPDIR\" $S/test/fastrpc_test.c -o $O/fastrpc_test -ldl
$CC $HARD -I$S/inc -I$SR/usr/include -DUSE_SYSLOG -DCONFIG_BASE_DIR=\"$CONFIG_BASE_DIR\" -DLIBDIR=\"$LIBDIR\" -DPARSE_YAML \
  $S/test/fastrpc_healthcheck.c -o $O/fastrpc-healthcheck $LDL -ldl -lyaml

# stage
install -d $ST$LIBDIR $ST$PREFIX/sbin $ST$PREFIX/bin $ST$TESTLIBDIR $ST$TESTDSPDIR
for l in cdsprpc adsprpc cdsp_default_listener; do
  install -m644 $O/lib$l.so.1.0.0 $ST$LIBDIR/
  ln -sf lib$l.so.1.0.0 $ST$LIBDIR/lib$l.so.1; ln -sf lib$l.so.1 $ST$LIBDIR/lib$l.so
done
install -m755 $O/cdsprpcd $ST$PREFIX/sbin/
install -m755 $O/fastrpc_test $O/fastrpc-healthcheck $ST$PREFIX/bin/
install -m644 $S/test/linux/*.so $ST$TESTLIBDIR/
for a in v68 v75; do install -d $ST$TESTDSPDIR/$a; install -m644 $S/test/$a/*.so $ST$TESTDSPDIR/$a/; done
# include pubblici (servono per compilare stub propri / QNN)
install -d $ST$PREFIX/include/fastrpc; install -m644 $S/inc/{remote.h,rpcmem.h,AEEStdErr.h,AEEStdDef.h,dspqueue.h} $ST$PREFIX/include/fastrpc/ 2>/dev/null || true
# servizio + udev (solo CDSP: adsprpcd NON installato di proposito, vedi README)
install -d $ST/usr/local/lib/systemd/system $ST/etc/udev/rules.d $ST/usr/lib/sysusers.d
sed "s|@sbindir@|$PREFIX/sbin|g" $S/files/cdsprpcd.service.in > $ST/usr/local/lib/systemd/system/cdsprpcd.service
# regola dma_heap: upstream usa /bin/setfacl (pacchetto acl, non garantito) -> fallback chgrp/chmod
grep -E '^#|dma_heap|fastrpc-cdsp"|fastrpc-cdsp-secure"' $S/files/60-fastrpc.rules \
 | sed 's#RUN+="/bin/setfacl -m g:fastrpc:rw $env{DEVNAME}"#RUN+="/bin/sh -c '"'"'setfacl -m g:fastrpc:rw $env{DEVNAME} 2>/dev/null || { chgrp fastrpc $env{DEVNAME}; chmod g+rw $env{DEVNAME}; }'"'"'"#' > $ST/etc/udev/rules.d/60-83hl-fastrpc.rules
install -m644 $S/files/fastrpc.conf $ST/usr/lib/sysusers.d/fastrpc.conf
( cd $S && git log -1 --format='qualcomm/fastrpc %H %cd' ) > $ST$PREFIX/share/fastrpc_test/SOURCE
echo "OK: stage in $ST"; find $ST -type f | sed "s|$ST||" | sort
