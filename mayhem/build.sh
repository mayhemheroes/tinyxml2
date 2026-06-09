#!/usr/bin/env bash
# tinyxml2/mayhem/build.sh — build the sanitized library + the xmltest libFuzzer harness (and its
# standalone reproducer), plus tinyxml2's own functional test suite (NORMAL flags) for mayhem/test.sh.
#
# tinyxml2 is a tiny single-translation-unit library (tinyxml2.cpp + tinyxml2.h), so the fuzz build
# compiles the library directly with $SANITIZER_FLAGS (so the FUZZED CODE is instrumented, not just
# the harness) and links it into the harness. The test suite is built separately with cmake using the
# project's normal flags so test.sh stays an honest PATCH oracle.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build knobs from the ENV, overridable. SANITIZER_FLAGS uses `=` (not `:=`) so an explicit empty
# value (--build-arg SANITIZER_FLAGS=) is honored → no-sanitizer build (natural crash).
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -g}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
export SANITIZER_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS

cd "$SRC"

CXXSTD="-std=c++11 -D_FILE_OFFSET_BITS=64"

# 1) Build the PROJECT (the library that the harness fuzzes) WITH $SANITIZER_FLAGS so the fuzzed code
#    is instrumented. Single TU; produce a sanitized static lib.
$CXX $SANITIZER_FLAGS $CXXSTD -c "$SRC/tinyxml2.cpp" -o /tmp/tinyxml2.san.o
ar rcs /tmp/libtinyxml2.san.a /tmp/tinyxml2.san.o

# 2a) The libFuzzer harness (the Mayhem target): harness + engine + sanitized lib.
$CXX $SANITIZER_FLAGS $CXXSTD -I"$SRC" \
     "$SRC/mayhem/xmltest.cpp" $LIB_FUZZING_ENGINE /tmp/libtinyxml2.san.a \
     -o /mayhem/xmltest

# 2b) Standalone (non-fuzzer) reproducer: same harness + LLVM's run-once driver instead of the engine.
#     Compile the C driver with $CC first so its LLVMFuzzerTestOneInput ref keeps C linkage (clang++
#     would mangle it and miss the harness's extern "C" definition). Respects $SANITIZER_FLAGS.
$CC $SANITIZER_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o
$CXX $SANITIZER_FLAGS $CXXSTD -I"$SRC" \
     "$SRC/mayhem/xmltest.cpp" /tmp/standalone_main.o /tmp/libtinyxml2.san.a \
     -o /mayhem/xmltest-standalone

# 2c) Second harness (OSS-Fuzz parity): xmltest2 exercises the LoadFile path. Same single-TU sanitized
#     lib; build the libFuzzer target plus its standalone reproducer (reusing the shared driver object).
$CXX $SANITIZER_FLAGS $CXXSTD -I"$SRC" \
     "$SRC/mayhem/xmltest2.cpp" $LIB_FUZZING_ENGINE /tmp/libtinyxml2.san.a \
     -o /mayhem/xmltest2
$CXX $SANITIZER_FLAGS $CXXSTD -I"$SRC" \
     "$SRC/mayhem/xmltest2.cpp" /tmp/standalone_main.o /tmp/libtinyxml2.san.a \
     -o /mayhem/xmltest2-standalone

# 3) tinyxml2's OWN functional test suite (the `xmltest` cmake target), built with the project's
#    NORMAL flags in a separate tree so mayhem/test.sh only RUNS it (never compiles). It reads/writes
#    resources/ relative to the repo root, so test.sh runs it from $SRC.
cmake -S "$SRC" -B "$SRC/build-tests" \
      -DCMAKE_BUILD_TYPE=Release -Dtinyxml2_BUILD_TESTING=ON \
      -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" >/dev/null
cmake --build "$SRC/build-tests" -j"$MAYHEM_JOBS" --target xmltest
