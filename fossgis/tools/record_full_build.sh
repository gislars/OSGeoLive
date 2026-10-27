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
#          Without a build log build/logs/latest.log is used. The log
#          header written by bin/build_chroot.sh must name HEAD as commit,
#          with no uncommitted changes, for result=green.
#
#############################################################################

if [ "$#" -lt 1 ] || { [ "$1" != "green" ] && [ "$1" != "red" ] ; } ; then
    echo "Usage: record_full_build.sh green|red [build log] [note]" >&2
    exit 2
fi
RESULT="$1"
NOTE="${3:-}"

TOP=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)") || exit 2
if [ -n "$(git status --porcelain --untracked-files=no)" ] ; then
    echo "Working tree has uncommitted changes, the build would not match HEAD." >&2
    exit 1
fi

LOG="${2:-$TOP/build/logs/latest.log}"
if [ ! -f "$LOG" ] ; then
    echo "Build log not found: $LOG" >&2
    exit 1
fi
LOG=$(readlink -f "$LOG")

header() {
    sed -n "s/^# $1=//p" "$LOG" | tail -n 1
}

HEAD_SHA=$(git rev-parse HEAD)
if [ "$RESULT" = "green" ] ; then
    if [ "$(header commit)" != "$HEAD_SHA" ] ; then
        echo "Build log $LOG is for commit '$(header commit)', not HEAD $HEAD_SHA." >&2
        exit 1
    fi
    if [ "$(header dirty_files)" != "0" ] ; then
        echo "Build log $LOG was built with uncommitted changes ($(header dirty_files))." >&2
        exit 1
    fi
    if grep -q '^Partial build from ' "$LOG" ; then
        echo "Build log $LOG is a partial build (local/inchroot.list), not a full build." >&2
        exit 1
    fi
    if [ "$(header exit)" != "0" ] || [ "$(header iso)" = "none" ] ; then
        echo "Build log $LOG shows a failed build (exit $(header exit), iso $(header iso))." >&2
        exit 1
    fi
fi

mkdir -p "$TOP/build"
{
    echo "commit=$HEAD_SHA"
    echo "describe=$(git describe --long --tags --match '[0-9]*' 2>/dev/null)"
    echo "date=$(date -Iseconds)"
    echo "result=$RESULT"
    echo "log=$LOG"
    echo "log_sha256=$(sha256sum "$LOG" | cut -d' ' -f1)"
    echo "log_errors=$(grep -c -E '^E:|ERROR|cannot stat' "$LOG")"
    echo "iso=$(header iso)"
    [ -n "$NOTE" ] && echo "note=$NOTE"
} > "$TOP/build/last-full-build.txt"
cat "$TOP/build/last-full-build.txt"
