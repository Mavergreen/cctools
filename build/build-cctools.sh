#!/bin/sh
# platform: host-agnostic -- the Mac variants build on a Mac or Linux, the Linux one on x86_64 Linux
#   usage: build/build-cctools.sh --variant mac-x86_64|mac-arm64|linux-x86_64 --stage DIR
#          Builds Apple's cctools and ld64, as cctools-port at the pinned commit with patches/ applied,
#          with the pinned clang22 in a hermetic environment, and stages them under DIR$PREFIX,
#          replacing any tree there: bin/ (ld, as, lipo, otool, nm, ...), share/man, and share/doc/cctools
#          with the licences the binaries are under. PREFIX is /usr/local/mavergreen/cctools for a Mac
#          variant and /opt/mavergreen/cctools for Linux. mac-arm64 needs a modern Mac or Linux, since
#          clang22 on 10.9 has no AArch64 backend; linux-x86_64 needs LIBDISPATCH_PREFIX, from
#          build/build-libdispatch.sh. Work happens in a fresh $MAVERICKS_BUILD_ROOT/cctools/
#          build-VARIANT.XXXXXX, removed on success. Build output goes to logs there, and their tails to
#          stderr on failure.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
MAVERICKS_ROOT="$root"; export MAVERICKS_ROOT
. "$here/msc.sh"

usage() { echo "usage: build/build-cctools.sh --variant mac-x86_64|mac-arm64|linux-x86_64 --stage DIR" >&2; exit 2; }
die() { echo "build-cctools: $*" >&2; exit 1; }
variant=""; stage=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --variant) [ "$#" -ge 2 ] || usage
      case "$2" in mac-x86_64|mac-arm64|linux-x86_64) variant=$2 ;; *) usage ;; esac; shift 2 ;;
    --stage) [ "$#" -ge 2 ] || usage; stage=$2; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$variant" ] && [ -n "$stage" ] || usage
case "$stage" in /*) ;; *) stage="$(pwd)/$stage" ;; esac

tmp="${TMPDIR:-/tmp}"
broot="${MAVERICKS_BUILD_ROOT:-${tmp%/}/mm-build}/cctools"
mkdir -p "$broot"
work="$(mktemp -d "$broot/build-$variant.XXXXXX")"
clang22="$(sh "$here/fetch-clang22.sh")" || die "no clang22"
os="$(uname -s)"
case "$(uname -m)" in arm64|aarch64) cpu=aarch64 ;; *) cpu="$(uname -m)" ;; esac
case "$os" in
  Darwin) build="$cpu-apple-darwin$(uname -r | cut -d. -f1)" ;;
  Linux) build="$cpu-unknown-linux-gnu" ;;
  *) die "builds on a Mac or Linux, not $os" ;;
esac
paths="$clang22/bin"
if [ "$os" = Darwin ]; then
  # platform: a Mac has no make without the Command Line Tools, so the family's comes as a pinned ingredient
  mv_="$(tr -d '[:space:]' < "$root/components/make/version")"
  make_tree="$(sh "$SHIPYARD_SCRIPTS/fetch_product_pkg.sh" make "$mv_" "$broot/toolchain/make-$mv_")" || die "no make product"
  paths="$paths:$make_tree/bin"
fi

# spec: INGREDIENTS.md "How cctools is built" -- one compiler line per variant, all from clang22
standin=""; cfg_cppflags=""; cfg_libs=""; cxx_extra=""
case "$variant" in
  mac-x86_64)
    prefix=/usr/local/mavergreen/cctools; host=x86_64-apple-darwin13
    # spec: INGREDIENTS.md "How cctools is built" -- the cfgs stay on, for Recaulk and clang22's own libc++
    flags="--target=x86_64-apple-macos10.9 -mmacosx-version-min=10.9 -isysroot $(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh")"
    # spec: build/dispatch-standin.h -- until the pinned clang22's Recaulk names them
    standin="-include $root/build/dispatch-standin.h"
    ;;
  mac-arm64)
    [ "$os/$(uname -r | cut -d. -f1)" != Darwin/13 ] || die "clang22 on Mac OS X 10.9 has no AArch64 backend; build mac-arm64 on a modern Mac or Linux"
    prefix=/usr/local/mavergreen/cctools; host=aarch64-apple-darwin20
    sdk="$(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh" --arch arm64)"
    # spec: INGREDIENTS.md "How cctools is built" -- the cfgs target x86_64 10.9 and clang22's runtimes
    #       are x86_64 only, so arm64 builds without them, against the 11.3 SDK's own libc++
    flags="--no-default-config --target=arm64-apple-macos11.0 -isysroot $sdk -fuse-ld=lld --ld-path=$clang22/bin/ld64.lld"
    cxx_extra="-nostdinc++ -isystem $sdk/usr/include/c++/v1"
    ;;
  linux-x86_64)
    [ "$os/$(uname -m)" = Linux/x86_64 ] || die "$variant builds on x86_64 Linux"
    : "${LIBDISPATCH_PREFIX:?build/build-libdispatch.sh first, and name its prefix in LIBDISPATCH_PREFIX}"
    prefix=/opt/mavergreen/cctools; host=x86_64-unknown-linux-gnu
    # platform: clang22's cfgs target 10.9; a Linux build names its own target and leaves them off
    flags="--no-default-config --target=$host -fuse-ld=lld"
    # platform: not --with-libdispatch, which adds an rpath naming this build's prefix; the libraries
    #           are static, so the tools need none
    cfg_cppflags="-isystem $LIBDISPATCH_PREFIX/include"; cfg_libs="-L$LIBDISPATCH_PREFIX/lib -lBlocksRuntime -lpthread"
    ;;
esac

maps=""
for d in "$broot" "$work"; do
  for p in "$d" "$(cd -P "$d" && pwd)"; do maps="$maps -ffile-prefix-map=$p=."; done
done
src="$(sh "$here/fetch-cctools.sh" "$work/src")"
mkdir "$work/obj" "$work/home"
hermetic() {
  env -i HOME="$work/home" TMPDIR="$tmp" PATH="$paths:/usr/bin:/bin:/usr/sbin:/sbin" LC_ALL=C \
    SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-0}" "$@"
}
cc="$clang22/bin/clang $flags"
cxx="$clang22/bin/clang++ $flags${cxx_extra:+ $cxx_extra}"
case "$variant" in mac-*) ldflags="-Wl,-oso_prefix,." ;; *) ldflags="" ;; esac
# spec: INGREDIENTS.md "How cctools is built" -- no libtapi (the 10.9 SDK has no .tbd stubs), no
#       LTO (no libLTO to load), and so no llvm-config
( cd "$work/obj" && hermetic /bin/sh ../src/cctools/configure --build="$build" --host="$host" --prefix="$prefix" \
    --disable-tapi-support --disable-lto-support \
    CC="$cc" CXX="$cxx" CPPFLAGS="$cfg_cppflags" CFLAGS="-O2$maps" CXXFLAGS="-O2$maps" LDFLAGS="$ldflags" LIBS="$cfg_libs" ) \
  > "$work/configure.log" 2>&1 || { tail -40 "$work/configure.log" >&2; die "configure failed ($work/configure.log)"; }
jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)"
( cd "$work/obj" && if [ -n "$standin" ]; then hermetic make -j"$jobs" CPPFLAGS="$standin"; else hermetic make -j"$jobs"; fi ) > "$work/build.log" 2>&1 \
  || { grep -a 'error:' "$work/build.log" | head -20 >&2; tail -20 "$work/build.log" >&2; die "make failed ($work/build.log)"; }
rm -rf "$work/inst"
( cd "$work/obj" && hermetic make install DESTDIR="$work/inst" ) > "$work/install.log" 2>&1 \
  || { tail -20 "$work/install.log" >&2; die "make install failed ($work/install.log)"; }

tree="$stage$prefix"
rm -rf "$tree"
mkdir -p "${tree%/*}"
mv "$work/inst$prefix" "$tree"
for f in "$tree"/bin/*; do
  [ -L "$f" ] || "$clang22/bin/llvm-strip" "$f"
done
doc="$tree/share/doc/cctools"
mkdir -p "$doc"
cp "$src/cctools/APPLE_LICENSE" "$doc/APPLE_LICENSE"
sh "$here/third-party-notices.sh" "$src/cctools" > "$doc/THIRD_PARTY_NOTICES"
cp "$root/patches"/*.patch "$doc/"
chmod 644 "$doc"/*

case "$variant" in mac-x86_64) garch=x86_64 ;; mac-arm64) garch=arm64 ;; *) garch="" ;; esac
if [ -n "$garch" ]; then
  MAVERICKS_ALLOW_ARCHS="$garch" MAVERICKS_DEVIATIONS_ROOT="$root" \
    LIPO="$clang22/bin/llvm-lipo" OTOOL="$clang22/bin/llvm-otool" NM="$clang22/bin/llvm-nm" \
    STRINGS="$clang22/bin/llvm-strings" sh "$SHIPYARD_SCRIPTS/assert_binary_compatible.sh" "$tree"/bin/* >&2 \
    || die "the compat guard refused a binary in $tree/bin"
fi
rm -rf "$work"
echo "build-cctools: cctools $(tr -d '[:space:]' < "$root/UPSTREAM_VERSION") ($variant) staged at $tree" >&2
