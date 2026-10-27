#!/bin/sh
#############################################################################
#
# Purpose: Mark a build log as failed when it contains messages that mean
#          the image or the build host may be damaged, even if exit=0.
#
# Usage:   check_build_log.sh <build log>
#
#          Exit 0 if the log is clean, 1 if a critical pattern matches,
#          2 on usage errors. Matching lines go to stderr.
#
#############################################################################

if [ "$#" -ne 1 ] ; then
    echo "Usage: check_build_log.sh <build log>" >&2
    exit 2
fi
LOG="$1"
if [ ! -f "$LOG" ] ; then
    echo "Build log not found: $LOG" >&2
    exit 2
fi

# Patterns from docs/fossgis/build-safety.md and the 27.10.2026 incidents.
# Keep this list short and specific; do not match ordinary apt "busy" noise.
# Keep this list specific. Transient apt DNS errors and pip noise appear in
# otherwise green logs; the inchroot abort on failed steps covers those.
PATTERN='target is busy|Device or resource busy|cannot remove .+edit/|changed size while reading filesystem|Failed to read file edit/|ERROR: partial build step failed|ERROR: QGIS package|ERROR: apt candidate for qgis|ERROR: installed qgis|ERROR: expected GDAL|ERROR: expected GRASS|ERROR: expected QGIS|ERROR: gdal-config|ERROR: processes still run|ERROR: still mounted'

HITS=`grep -E -n -e "$PATTERN" "$LOG" || true`
if [ -z "$HITS" ] ; then
    exit 0
fi

echo "check_build_log: critical messages in $LOG:" >&2
echo "$HITS" >&2
exit 1
