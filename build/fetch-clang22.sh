#!/bin/sh
# platform: host-agnostic
#   usage: build/fetch-clang22.sh
#          Prints the prefix of the clang22 components/clang22/version pins, for this host, through
#          shipyard's fetch_clang22.sh: the Linux archive on Linux, the cross pkg on a modern Mac, the
#          native pkg on 10.9. On Linux the archive's cfgs are then pointed at the pinned 10.9 SDK,
#          unless they already are.
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
. "$root/build/msc.sh"
d="$(sh "$SHIPYARD_SCRIPTS/fetch_clang22.sh" "$root/components/clang22")"
for b in clang clang++ ld64.lld llvm-lipo llvm-otool llvm-nm llvm-strings llvm-strip llvm-objdump; do
  [ -x "$d/bin/$b" ] || { echo "fetch-clang22: $d lacks bin/$b" >&2; exit 1; }
done
if [ "$(uname -s)" = Linux ]; then
  sdk="$(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh")"; l="$d/SDKs/MacOSX10.9.sdk"
  if [ -L "$l" ] && [ "$(cd "$l" && pwd -P)" = "$(cd "$sdk" && pwd -P)" ]; then :; else "$d/bin/setup-sdk" "$sdk" >&2; fi
fi
echo "$d"
