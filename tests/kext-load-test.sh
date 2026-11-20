#!/bin/sh
# platform: macOS-only -- loads a kext into the running kernel; only on Mac OS X 10.9, and only as root
#   usage: sudo CCT_STAGE=DIR sh tests/kext-load-test.sh
#          Links tests/fixtures/kext/hello.o with the tree's ld -kext, bundles it, and has 10.9's
#          kxld link it (kextutil -n -t), then loads it, finds it in kextstat and unloads it. Exit 77
#          unless CCT_STAGE is set, the host is 10.9 and this runs as root: CI runs it in the
#          throwaway 10.9 VM, and a person runs it on a box of their own only when they choose to.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -n "${CCT_STAGE:-}" ] || { echo "CCT_STAGE unset, skipping"; exit 77; }
[ "$(uname -s)/$(uname -r | cut -d. -f1)" = Darwin/13 ] || { echo "not Mac OS X 10.9, skipping"; exit 77; }
[ "$(id -u)" -eq 0 ] || { echo "not root, skipping"; exit 77; }
fail() { echo "FAIL: $*"; exit 1; }
T="$CCT_STAGE/usr/local/mavergreen/cctools"
id=dev.mavergreen.cctools.hello
w="$(mktemp -d /tmp/cct-kext.XXXXXX)"
trap 'kextunload -b "$id" > /dev/null 2>&1 || true; rm -rf "$w"' EXIT
k="$w/hello.kext/Contents"
mkdir -p "$k/MacOS"
"$T/bin/ld" -arch x86_64 -kext -static -no_uuid -macosx_version_min 10.9 "$HERE/fixtures/kext/hello.o" -o "$k/MacOS/hello"
cp "$HERE/fixtures/kext/Info.plist" "$k/Info.plist"
chown -R root:wheel "$w/hello.kext"
chmod -R go-w "$w/hello.kext"
kextutil -n -t "$w/hello.kext" > "$w/t" 2>&1 || true
grep -q 'appears to be loadable' "$w/t" || { cat "$w/t"; fail "kxld would not link the kext"; }
kextutil "$w/hello.kext" > "$w/l" 2>&1 || true
kextstat -l -b "$id" | grep -q "$id" || { cat "$w/l"; fail "the kext did not load"; }
kextunload -b "$id" || fail "the kext did not unload"
if kextstat -l -b "$id" | grep -q "$id"; then fail "the kext is still loaded"; fi
echo "PASS: ld -kext's kext linked, loaded and unloaded on $(sw_vers -productVersion)"
