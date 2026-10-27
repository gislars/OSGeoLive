#!/bin/sh
#############################################################################
#
# Purpose: List pinned *_VERSION= assignments in bin/*.sh (and tools under
#          bin/). Used when planning yearly upgrades.
#
# Usage:   list_pinned_versions.sh [path-to-bin]
#
#############################################################################

BIN_DIR="${1:-`cd "$(dirname "$0")/.." && pwd`}"

if [ ! -d "$BIN_DIR" ] ; then
   echo "not a directory: $BIN_DIR" >&2
   exit 2
fi

# Match NAME_VERSION="..." or NAME_VERSION=... (shell assignments).
grep -R -H -n -E \
   '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*VERSION[A-Za-z0-9_]*=' \
   "$BIN_DIR" --include='*.sh' | \
   grep -v '/retired/' | \
   sort
