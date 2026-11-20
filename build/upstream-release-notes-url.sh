#!/bin/sh
# platform: host-agnostic
set -eu
printf 'https://github.com/tpoechtrager/cctools-port/commits/%s-ld64-957.1\n' "${1:?usage: upstream-release-notes-url.sh <upstream-version>}"
