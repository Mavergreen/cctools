# platform: host-agnostic
#   usage: . build/toolchain.sh
#          Sets CLANG22_BIN (the pinned clang22's bin, from build/fetch-clang22.sh) and LIPO, OTOOL, NM and
#          STRINGS (its Mach-O readers, which every host has; 10.9's own are Command Line Tools stubs),
#          and defines cct_build_root, which prints $MAVERICKS_BUILD_ROOT/cctools (default
#          ${TMPDIR}/mm-build/cctools).
: "${MAVERICKS_ROOT:=$(cd "$(dirname "$0")/.." && pwd)}"
. "$MAVERICKS_ROOT/build/msc.sh"
cct_build_root() { _cbr="${TMPDIR:-/tmp}"; printf '%s/cctools\n' "${MAVERICKS_BUILD_ROOT:-${_cbr%/}/mm-build}"; }
CLANG22_BIN="$(sh "$MAVERICKS_ROOT/build/fetch-clang22.sh")/bin" || return 1
LIPO="$CLANG22_BIN/llvm-lipo"; OTOOL="$CLANG22_BIN/llvm-otool"; NM="$CLANG22_BIN/llvm-nm"; STRINGS="$CLANG22_BIN/llvm-strings"
export CLANG22_BIN LIPO OTOOL NM STRINGS
