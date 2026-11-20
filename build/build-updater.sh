#!/bin/sh
# platform: host-agnostic
#   usage: build/build-updater.sh --out APP
#          Builds the Sparkle updater (CMakeLists.txt) with the pinned clang22 and shipyard's
#          MavericksToolchain.cmake: x86_64 for 10.9 and, on Linux or a modern Mac, arm64 for 11.0, merged
#          into one universal APP with shipyard's lipo-merge-tree.sh. APP must not exist. Its version is
#          mavericks_resolve_version's, which reads VERSION when one exists.
# spec: INGREDIENTS.md "How the updater is built" -- Apple Silicon installs this pkg too, and an
#       x86_64-only updater would prompt for Rosetta there
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$here/.." && pwd)"; export MAVERICKS_ROOT
. "$here/toolchain.sh"
die() { echo "build-updater: $*" >&2; exit 1; }
[ "$#" -eq 2 ] && [ "$1" = --out ] || { echo "usage: build/build-updater.sh --out APP" >&2; exit 2; }
out=$2
case "$out" in /*) ;; *) out="$(pwd)/$out" ;; esac
[ ! -e "$out" ] && [ ! -L "$out" ] || die "$out already exists"
if [ "$(uname -s)" = Linux ]; then
  # platform: no cmake product runs on Linux yet; this is the container's, locked in build/linux/packages.lock
  sc="$(command -v cmake)"; slices="x86_64:10.9 arm64:11.0"
else
  sc="$(command -v shipyard-cmake || echo /usr/local/mavergreen/bin/shipyard-cmake)"
  slices="x86_64:10.9"
  [ "$(uname -r | cut -d. -f1)" = 13 ] || slices="$slices arm64:11.0"
fi
tc="$(dirname "$SHIPYARD_SCRIPTS")/MavericksToolchain.cmake"
mkdir -p "$(cct_build_root)"
work="$(mktemp -d "$(cct_build_root)/updater.XXXXXX")"
trap 'rm -rf "$work"' EXIT
for s in $slices; do
  a="${s%%:*}"; floor="${s#*:}"
  "$sc" -S "$MAVERICKS_ROOT" -B "$work/$a" -DCMAKE_TOOLCHAIN_FILE="$tc" ${MavericksShipyard_DIR:+-DMavericksShipyard_DIR="$MavericksShipyard_DIR"} -DCMAKE_OSX_ARCHITECTURES="$a" \
    -DCMAKE_OBJC_COMPILER="$CLANG22_BIN/clang" -DCMAKE_OBJC_COMPILER_TARGET="$a-apple-macos$floor" \
    -DCMAKE_OBJC_FLAGS=--no-default-config \
    -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld --ld-path=$CLANG22_BIN/ld64.lld" >&2 || die "the $a updater did not configure"
  "$sc" --build "$work/$a" >&2 || die "the $a updater did not build"
done
app=cctools-updater.app
mkdir -p "$(dirname "$out")"
case "$slices" in
  *arm64*)
    mkdir "$work/bin"; ln -s "$LIPO" "$work/bin/lipo"
    PATH="$work/bin:$PATH" sh "$SHIPYARD_SCRIPTS/lipo-merge-tree.sh" --a "$work/x86_64/$app" --b "$work/arm64/$app" \
      --out "$out" --require-archs "x86_64 arm64" >&2 ;;
  *) cp -Rp "$work/x86_64/$app" "$out" ;;
esac
echo "build-updater: updater at $out" >&2
