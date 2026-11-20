#!/bin/sh
# platform: host-agnostic -- refuses all but x86_64 Linux: a Mac has libdispatch and the blocks runtime in libSystem
#   usage: build/build-libdispatch.sh PREFIX
#          Builds swift-corelibs-libdispatch at the commit components/libdispatch/version pins (its second field) (GitHub's
#          tarball, verified against components/libdispatch/sha256) with the pinned clang22, as static
#          libdispatch.a and libBlocksRuntime.a with their headers, into PREFIX, for
#          build/build-cctools.sh --variant linux-x86_64. Static, so the shipped tools need no library
#          beside them and no rpath naming the build. Work happens in $MAVERICKS_BUILD_ROOT/cctools.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$here/msc.sh"
die() { echo "build-libdispatch: $*" >&2; exit 1; }
[ "$#" -eq 1 ] || { echo "usage: build/build-libdispatch.sh PREFIX" >&2; exit 2; }
[ "$(uname -s)/$(uname -m)" = Linux/x86_64 ] || die "builds on x86_64 Linux"
prefix=$1
tmp="${TMPDIR:-/tmp}"
broot="${MAVERICKS_BUILD_ROOT:-${tmp%/}/mm-build}/cctools"
mkdir -p "$broot"
work="$(mktemp -d "$broot/libdispatch.XXXXXX")"
clang22="$(sh "$SHIPYARD_SCRIPTS/fetch_clang22.sh" "$root/components/clang22")" || die "no clang22"
pins="$root/components/libdispatch"
sh "$SHIPYARD_SCRIPTS/fetch_pinned_source.sh" https://github.com/swiftlang/swift-corelibs-libdispatch \
  "$(awk '{ print $2 }' "$pins/version")" "$(tr -d '[:space:]' < "$pins/sha256")" "$work/src" >&2
maps="-ffile-prefix-map=$work=. -ffile-prefix-map=$(cd -P "$work" && pwd)=."
flags="--no-default-config --target=x86_64-unknown-linux-gnu -fuse-ld=lld"
# platform: no cmake product runs on Linux yet; this uses the container's, locked in build/linux/packages.lock
cmake -G Ninja -S "$work/src" -B "$work/obj" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=NO \
  -DBUILD_TESTING=NO -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_C_COMPILER="$clang22/bin/clang" -DCMAKE_CXX_COMPILER="$clang22/bin/clang++" \
  -DCMAKE_C_FLAGS="$flags $maps" -DCMAKE_CXX_FLAGS="$flags $maps" \
  -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld > "$work/configure.log" 2>&1 \
  || { tail -30 "$work/configure.log" >&2; die "configure failed"; }
cmake --build "$work/obj" > "$work/build.log" 2>&1 || { tail -30 "$work/build.log" >&2; die "build failed"; }
cmake --install "$work/obj" > /dev/null || die "install failed"
for f in lib/libdispatch.a lib/libBlocksRuntime.a include/dispatch/dispatch.h include/Block.h; do
  [ -f "$prefix/$f" ] || die "the install has no $f"
done
rm -rf "$work"
echo "build-libdispatch: static libdispatch and BlocksRuntime at $prefix" >&2
