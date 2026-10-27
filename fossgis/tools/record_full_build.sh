#!/bin/sh
#############################################################################
#
# Purpose: Record the result of a full local build and QEMU test in
#          build/last-full-build.txt. check_clean.sh --require-full-build
#          (and the pre-push hook for master) only accepts a push of the
#          recorded commit with result=green.
#
# Usage:   record_full_build.sh green|red [build log] [note]
#
#############################################################################

if [ "$#" -lt 1 ] || { [ "$1" != "green" ] && [ "$1" != "red" ] ; } ; then
    echo "Usage: record_full_build.sh green|red [build log] [note]" >&2
    exit 2
fi
RESULT="$1"
LOG="${2:-}"
NOTE="${3:-}"

TOP=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)") || exit 2
if [ -n "$(git status --porcelain --untracked-files=no)" ] ; then
    echo "Working tree has uncommitted changes, the build would not match HEAD." >&2
    exit 1
fi

mkdir -p "$TOP/build"
{
    echo "commit=$(git rev-parse HEAD)"
    echo "describe=$(git describe --long --tags 2>/dev/null)"
    echo "date=$(date -Iseconds)"
    echo "result=$RESULT"
    if [ -n "$LOG" ] && [ -f "$LOG" ] ; then
        echo "log=$LOG"
        echo "log_sha256=$(sha256sum "$LOG" | cut -d' ' -f1)"
        echo "log_errors=$(grep -c -E '^E:|ERROR|cannot stat' "$LOG")"
    fi
    [ -n "$NOTE" ] && echo "note=$NOTE"
} > "$TOP/build/last-full-build.txt"
cat "$TOP/build/last-full-build.txt"
