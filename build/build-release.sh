#!/bin/sh
# platform: host-agnostic -- builds every variant on x86_64 Linux, which only Linux can do in one place
#   usage: build/build-release.sh --version V --out DIR
#          What release.yml's build job runs in the locked container, and what a developer runs on x86_64
#          Linux to get the same artifacts: libdispatch, then cctools for linux-x86_64, mac-x86_64 and
#          mac-arm64, each smoked as far as this host can run it; the Mac stages merged into one
#          universal tree; the universal updater; and DIR/cctools-V.pkg and
#          DIR/cctools-V-linux-x86_64.tar.gz. Work happens under $MAVERICKS_BUILD_ROOT/cctools.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$here/.." && pwd)"; export MAVERICKS_ROOT
. "$here/toolchain.sh"
die() { echo "build-release: $*" >&2; exit 1; }
[ "$#" -eq 4 ] && [ "$1" = --version ] && [ "$3" = --out ] || { echo "usage: build/build-release.sh --version V --out DIR" >&2; exit 2; }
V=$2; out=$4
[ "$(uname -s)/$(uname -m)" = Linux/x86_64 ] || die "builds every variant on x86_64 Linux; elsewhere run build/build-cctools.sh for the variants this host can build"
b="$(cct_build_root)/release"
rm -rf "$b"; mkdir -p "$b" "$out"
smoke() { # STAGE WANT -- WANT 0: both halves pass; 77: the static half passes and the runtime half cannot run here
  rc=0; CCT_STAGE="$1" sh "$MAVERICKS_ROOT/tests/smoke-test.sh" > "$b/smoke.log" 2>&1 || rc=$?
  cat "$b/smoke.log" >&2
  [ "$rc" -eq "$2" ] && grep -q '^PASS static: ' "$b/smoke.log" || die "smoking $1 exited $rc, not $2"
}
sh "$here/build-libdispatch.sh" "$b/libdispatch"
LIBDISPATCH_PREFIX="$b/libdispatch" sh "$here/build-cctools.sh" --variant linux-x86_64 --stage "$b/stage-linux"
# spec: tests/smoke-test.sh -- as hands the assembly to a clang, and clang22's is the one here
CCTOOLS_CLANG_AS_EXECUTABLE="$CLANG22_BIN/clang"; export CCTOOLS_CLANG_AS_EXECUTABLE
( unset OTOOL; smoke "$b/stage-linux" 0 )
for a in x86_64 arm64; do
  sh "$here/build-cctools.sh" --variant "mac-$a" --stage "$b/stage-$a"
  smoke "$b/stage-$a" 77
done
sh "$here/merge.sh" --x86_64 "$b/stage-x86_64" --arm64 "$b/stage-arm64" --out "$b/stage-universal"
smoke "$b/stage-universal" 77
printf '%s\n' "$V" > "$MAVERICKS_ROOT/VERSION"
sh "$here/build-updater.sh" --out "$b/cctools-updater.app"
sh "$here/package-pkg.sh" --stage "$b/stage-universal" --updater-app "$b/cctools-updater.app" --version "$V" --out "$out"
sh "$here/package-linux.sh" --stage "$b/stage-linux" --version "$V" --out "$out"
echo "build-release: $out/cctools-$V.pkg and $out/cctools-$V-linux-x86_64.tar.gz" >&2
