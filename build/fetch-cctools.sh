#!/bin/sh
# platform: host-agnostic
#   usage: build/fetch-cctools.sh DEST
#          Replaces DEST with cctools-port at the commit components/cctools-port/version pins (its second field), as GitHub's
#          tarball of it verified against components/cctools-port/sha256, with patches/*.patch applied
#          in name order. Prints DEST. Exit 1 on a failed fetch, checksum or patch, 2 on a usage error.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/msc.sh"
[ "$#" -eq 1 ] || { echo "usage: build/fetch-cctools.sh DEST" >&2; exit 2; }
dest=$1
pins="$here/../components/cctools-port"
ref="$(awk '{ print $1 }' "$pins/version")"
commit="$(awk '{ print $2 }' "$pins/version")"
up="$(tr -d '[:space:]' < "$here/../UPSTREAM_VERSION")"
case "$ref" in
  "$up"-ld64-*) ;;
  *) echo "fetch-cctools: components/cctools-port/version follows $ref, not a branch of cctools $up (UPSTREAM_VERSION)" >&2; exit 1 ;;
esac
sha="$(tr -d '[:space:]' < "$pins/sha256")"
sh "$SHIPYARD_SCRIPTS/fetch_pinned_source.sh" https://github.com/tpoechtrager/cctools-port "$commit" "$sha" "$dest" >&2
sh "$SHIPYARD_SCRIPTS/apply_patches.sh" "$dest" "$here/../patches" >&2
printf '%s\n' "$dest"
