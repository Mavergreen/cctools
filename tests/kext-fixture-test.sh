#!/bin/sh
# platform: host-agnostic
#   usage: sh tests/kext-fixture-test.sh
#          tests/fixtures/kext/hello.s and hello.o are hello.c as the pinned clang22 compiles it (-S, -c);
#          fails when either no longer is, so the fixtures never drift from their source.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
. "$ROOT/build/msc.sh"
fail() { echo "FAIL: $*"; exit 1; }
clang22="$(sh "$ROOT/build/fetch-clang22.sh")" || fail "no clang22"
sdk="$(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh")"
w="$(mktemp -d "${TMPDIR:-/tmp}/cct-fixture.XXXXXX")"; trap 'rm -rf "$w"' EXIT
F="$HERE/fixtures/kext"
kf="--no-default-config -target x86_64-apple-macos10.9 -isysroot $sdk -mkernel -fno-builtin -nostdinc -isystem $sdk/System/Library/Frameworks/Kernel.framework/Headers -O2 -fno-ident"
"$clang22/bin/clang" $kf -S "$F/hello.c" -o "$w/hello.s"
"$clang22/bin/clang" $kf -c "$F/hello.c" -o "$w/hello.o"
grep -v '^# ' "$F/hello.s" > "$w/committed.s"
diff -u "$w/committed.s" "$w/hello.s" || fail "hello.s is not what clang22 makes of hello.c; regenerate it (its header says how)"
cmp "$F/hello.o" "$w/hello.o" || fail "hello.o is not what clang22 makes of hello.c; regenerate it with -c and the same flags"
echo "PASS: hello.s and hello.o are hello.c"
