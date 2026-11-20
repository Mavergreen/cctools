#!/bin/sh
# platform: host-agnostic
#   usage: build/third-party-notices.sh SRC
#          Prints, for the cctools-port tree SRC, every distinct licence notice that is not the APSL's:
#          the leading comment of each C, C++ or header file that grants terms of its own ("Redistribution
#          and use", the University of Illinois/NCSA licence), once per distinct text, after the files
#          that carry it. A BSD licence asks that a binary's documentation reproduce the notice.
set -eu
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "usage: build/third-party-notices.sh SRC" >&2; exit 2; }
cd "$1"
t="$(mktemp -d "${TMPDIR:-/tmp}/notices.XXXXXX")"; trap 'rm -rf "$t"' EXIT
find . -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) | LC_ALL=C sort | while read -r f; do
  awk 'NR == 1 && !/^[ \t]*\/[*\/]/ { exit } { print } /\*\// { exit } /^[ \t]*$/ && NR > 1 { exit }' "$f" > "$t/head"
  grep -q -e 'Redistribution and use' -e 'University of Illinois' "$t/head" || continue
  if grep -q 'APPLE_LICENSE_HEADER_START' "$t/head"; then continue; fi
  k="$(cksum < "$t/head" | awk '{ print $1 "-" $2 }')"
  [ -f "$t/$k.txt" ] || cp "$t/head" "$t/$k.txt"
  printf '%s\n' "${f#./}" >> "$t/$k.files"
done
echo "Notices of the third-party code in Mavergreen cctools, beside the Apple Public Source License 2.0"
echo "in APPLE_LICENSE. Each notice follows the files of cctools-port that carry it."
for files in "$t"/*.files; do
  [ -f "$files" ] || continue
  echo; echo "================================================================"
  cat "$files"; echo
  cat "${files%.files}.txt"
done
