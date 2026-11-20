#!/bin/sh
# platform: host-agnostic
#   usage: sh tests/dispatch-standin-test.sh
#          build/dispatch-standin.h is debt with an exit: it fills in DISPATCH_APPLY_AUTO and
#          dispatch_queue_global_t until Recaulk's <dispatch/dispatch.h> carries them. Fails as soon as
#          the pinned clang22 brings a Recaulk that does, so the stand-in is deleted then, not later.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
. "$ROOT/build/msc.sh"
[ -f "$ROOT/build/dispatch-standin.h" ] || { echo "no stand-in, nothing to retire"; exit 0; }
clang22="$(sh "$ROOT/build/fetch-clang22.sh")"
h="$clang22/include/recaulk/dispatch/dispatch.h"
[ -f "$h" ] || { echo "FAIL: no $h; where do clang22's Recaulk headers live now?"; exit 1; }
if grep -q 'DISPATCH_APPLY_AUTO' "$h" && grep -q 'dispatch_queue_global_t' "$h"; then
  echo "FAIL: clang22 $(cat "$ROOT/components/clang22/version")'s Recaulk names both; delete build/dispatch-standin.h and its -include in build/build-cctools.sh"
  exit 1
fi
echo "PASS: Recaulk does not yet carry them; the stand-in stays"
