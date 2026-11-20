#!/bin/sh
# platform: host-agnostic -- needs GNU tar, whose --sort, --mtime and --owner make the archive reproducible
#   usage: build/package-linux.sh --stage STAGE --version V --out DIR
#          Archives STAGE/opt/mavergreen/cctools (build/build-cctools.sh --variant linux-x86_64) as
#          DIR/cctools-V-linux-x86_64.tar.gz, whose one top-level directory is cctools/, so
#          `tar -C /opt/mavergreen -xzf` installs it. Files are in name order, owned by 0:0, dated
#          SOURCE_DATE_EPOCH (default: this repo's last commit).
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
usage() { echo "usage: build/package-linux.sh --stage STAGE --version V --out DIR" >&2; exit 2; }
stage=""; V=""; out=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --stage) [ "$#" -ge 2 ] || usage; stage=$2; shift 2 ;;
    --version) [ "$#" -ge 2 ] || usage; V=$2; shift 2 ;;
    --out) [ "$#" -ge 2 ] || usage; out=$2; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$stage" ] && [ -n "$V" ] && [ -n "$out" ] || usage
[ -x "$stage/opt/mavergreen/cctools/bin/ld" ] || { echo "package-linux: $stage has no /opt/mavergreen/cctools/bin/ld" >&2; exit 1; }
sde="${SOURCE_DATE_EPOCH:-$(git -C "$here/.." log -1 --format=%ct)}"
mkdir -p "$out"
a="$out/cctools-$V-linux-x86_64.tar.gz"
tar --sort=name --mtime="@$sde" --owner=0 --group=0 --numeric-owner -C "$stage/opt/mavergreen" -cf - cctools \
  | gzip -n -9 > "$a.tmp"
mv "$a.tmp" "$a"
echo "package-linux: $a" >&2
