#!/bin/sh
# platform: host-agnostic -- checks a staged or installed tree; runs its tools where they can run
#   usage: CCT_STAGE=DIR sh tests/smoke-test.sh
#          DIR holds the tree at its prefix (a stage, or / for an installed pkg or archive). Static half,
#          on any host: the tools and licences are there, no file names the build host, and in a Mac tree
#          every Mach-O loads only from /usr/lib and /System. Runtime half, where the tree's binaries
#          run here: `ld -v` names the source, and ld -kext turns tests/fixtures/kext/hello.o into a
#          kext with only the load commands 10.9's kxld accepts (tests/kext-load-test.sh loads it).
#          as, which hands the assembly to a clang, assembles hello.s too where one is at hand:
#          CCTOOLS_CLANG_AS_EXECUTABLE, or a clang on PATH that runs. Exit 77, after the static half, when they
#          cannot run here; 77 alone when CCT_STAGE is unset.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -n "${CCT_STAGE:-}" ] || { echo "CCT_STAGE unset -- nothing staged to check, skipping"; exit 77; }
fail() { echo "FAIL: $*"; exit 1; }
if [ -d "$CCT_STAGE/usr/local/mavergreen/cctools" ]; then T="$CCT_STAGE/usr/local/mavergreen/cctools"
elif [ -d "$CCT_STAGE/opt/mavergreen/cctools" ]; then T="$CCT_STAGE/opt/mavergreen/cctools"
else fail "$CCT_STAGE holds no cctools tree"; fi
w="$(mktemp -d "${TMPDIR:-/tmp}/cct-smoke.XXXXXX")"; trap 'rm -rf "$w"' EXIT

for t in ld as ar ranlib lipo otool nm strip strings size libtool install_name_tool codesign_allocate \
         segedit pagestuff vtool ObjectDump; do
  [ -x "$T/bin/$t" ] || fail "no executable $T/bin/$t"
done
for d in APPLE_LICENSE THIRD_PARTY_NOTICES; do
  [ -s "$T/share/doc/cctools/$d" ] || fail "no $T/share/doc/cctools/$d"
done
ls "$T"/share/doc/cctools/*.patch > /dev/null 2>&1 || fail "the patches the binaries are built with are not in share/doc/cctools"
[ -f "$T/share/man/man1/ld.1" ] || fail "no ld(1)"
if grep -r -l -a -e '/mm-build/' -e '/var/folders/' -e 'Library/Caches' -e '/opt/pkg' -e '/opt/homebrew' \
     -e '/opt/local/' "$T" > "$w/leaks" 2>/dev/null; then
  cat "$w/leaks"; fail "installed files name the build host"
fi
otool_="${OTOOL:-$T/bin/otool}"
if [ -d "$CCT_STAGE/usr/local/mavergreen/cctools" ]; then
  for f in "$T"/bin/*; do
    [ -L "$f" ] && continue
    "$otool_" -L "$f" | awk '/^\t/ { print $1 }' > "$w/deps"
    if grep -v -e '^/usr/lib/' -e '^/System/Library/' "$w/deps"; then fail "${f##*/} loads from outside the OS"; fi
  done
fi
echo "PASS static: $T"

"$T/bin/ld" -v > "$w/v" 2>&1 || { echo "the tree's ld does not run on this host -- runtime half skipped"; exit 77; }
grep -q 'PROJECT:ld64-957.1' "$w/v" || { cat "$w/v"; fail "ld -v names no ld64-957.1"; }
grep -q 'source available at https://github.com/Mavergreen/cctools' "$w/v" || { cat "$w/v"; fail "ld -v names no source"; }
did_as=""
# platform: 10.9 without the Command Line Tools has /usr/bin/clang, a stub that only offers to install them
if "${CCTOOLS_CLANG_AS_EXECUTABLE:-clang}" --version > /dev/null 2>&1; then
  "$T/bin/as" -arch x86_64 "$HERE/fixtures/kext/hello.s" -o "$w/as.o" || fail "as could not assemble the kext fixture"
  "$otool_" -hv "$w/as.o" | grep -q OBJECT || fail "as made no object"
  did_as="as, "
else
  echo "no clang for as to hand the assembly to -- as not checked"
fi
"$T/bin/ld" -arch x86_64 -kext -static -no_uuid -macosx_version_min 10.9 "$HERE/fixtures/kext/hello.o" -o "$w/hello" \
  || fail "ld -kext could not link the kext fixture"
"$otool_" -hv "$w/hello" > "$w/h" || fail "otool -hv"
grep -q 'KEXTBUNDLE' "$w/h" || { cat "$w/h"; fail "ld -kext did not make an MH_KEXT_BUNDLE"; }
# spec: tests/kext-load-test.sh -- xnu-2422's kxld accepts only these load commands in an x86_64 kext
"$otool_" -l "$w/hello" | awk '$1 == "cmd" { print $2 }' | sort | uniq -c | awk '{ print $2 "=" $1 }' \
  | tr '\n' ' ' > "$w/cmds"
[ "$(cat "$w/cmds")" = "LC_DYSYMTAB=1 LC_SEGMENT_64=3 LC_SOURCE_VERSION=1 LC_SYMTAB=1 " ] \
  || fail "the kext's load commands are $(cat "$w/cmds")"
"$T/bin/nm" -m "$w/hello" | grep -q 'external _kmod_info' || fail "the kext exports no _kmod_info"
echo "PASS runtime: ${did_as}ld -kext, otool, nm"
