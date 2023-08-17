#! /bin/sh

set -e
set -x

# https://github.com/yamt/wasi-libc/tree/dynamic-linking-__main_void.o-revert 
#WASI_SDK=${WASI_SDK:-/Volumes/PortableSSD/git/component-linking-demo/wasi-sdk/build/install/opt/wasi-sdk}
#CC=${WASI_SDK}/bin/clang

#WASI_SYSROOT=${WASI_SDK}/share/wasi-sysroot
WASI_SYSROOT=/Users/yamamoto/git/wasi-libc/sysroot

#LLVM_HOME=/Volumes/PortableSSD/llvm/llvm
LLVM_HOME=/Volumes/PortableSSD/llvm/build
#LLVM_HOME=/Volumes/PortableSSD/git/component-linking-demo/wasi-sdk/build/install/opt/wasi-sdk
RESOURCE_DIR=/Volumes/PortableSSD/llvm/llvm/lib/clang/17
#RESOURCE_DIR=${WASI_SDK}/lib/clang/17
CC=${LLVM_HOME}/bin/clang
CFLAGS="${CFLAGS} --sysroot ${WASI_SYSROOT}"
CFLAGS="${CFLAGS} -resource-dir ${RESOURCE_DIR}"

# built with
#  TOYWASM_ENABLE_DYLD=ON
#  TOYWASM_ENABLE_DYLD_DLFCN=ON
TOYWASM=${TOYWASM:-toywasm}

CFLAGS="${CFLAGS} -O3"
CFLAGS="${CFLAGS} -I./libdl"

# https://reviews.llvm.org/D155542
#CFLAGS="${CFLAGS} -mextended-const"

# CFLAGS="${CFLAGS} -mtail-call"

CLINKFLAGS="-Xlinker --experimental-pic"
#CLIBLINKFLAGS="-shared -fvisibility=default -mexec-model=reactor"
CLIBLINKFLAGS="-shared -fvisibility=default"

#CRT1=$(${CC} --print-file-name crt1-reactor.o)

CPICFLAGS="${CFLAGS} -fPIC"

${CC} ${CPICFLAGS} ${CLINKFLAGS} ${CLIBLINKFLAGS} -o libbar.so bar.c
# see the comment in native.sh
${CC} ${CPICFLAGS} ${CLINKFLAGS} ${CLIBLINKFLAGS} -o libfoo.so foo.c libbar.so
${CC} ${CPICFLAGS} ${CLINKFLAGS} ${CLIBLINKFLAGS} -o libbaz.so baz.c
BUILD_PIE=${BUILD_PIE:-0}
if [ ${BUILD_PIE} -ne 0 ]; then
${CC} ${CPICFLAGS} ${CLINKFLAGS} \
-Xlinker -pie \
-Xlinker --export-if-defined=__main_argc_argv \
-Xlinker --import-memory \
-o main \
main.c \
main2.c \
libfoo.so libbar.so libdl/libdl.so
else
# clang doesn't have DynamicNoPIC for non-darwin targets. just use -fPIC.
#PIC=-mdynamic-no-pic
PIC=-fPIC
${CC} -v ${CFLAGS} ${CLINKFLAGS} \
-g \
${PIC} \
-nodefaultlibs \
-Xlinker --export-if-defined=__main_argc_argv \
-Xlinker --unresolved-symbols=import-dynamic \
-Xlinker --export-table \
-Xlinker --growable-table \
-Xlinker --export=__stack_pointer \
-Xlinker --export=__heap_base \
-Xlinker --export=__heap_end \
-z stack-size=16384 \
-o main \
main.c \
main2.c \
libfoo.so libbar.so libdl/libdl.so
fi

${TOYWASM} --wasi \
--dyld \
--dyld-dlfcn \
--dyld-path . \
--dyld-path ${WASI_SYSROOT}/lib/wasm32-wasi \
--dyld-path ./libdl \
"$@" main
