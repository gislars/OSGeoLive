#!/bin/sh
#############################################################################
#
# Purpose: Show that a build left the build host untouched. Runs as the
#          normal user and only reads: device nodes in /dev, the mount
#          table and the free space of the project file system.
#
# Usage:   host_guard.sh snapshot <file>   record the current state
#          host_guard.sh check <file>      compare with a snapshot, exit 1
#                                          on any deviation
#
# Device nodes that disappear, a /dev/null that is no character device,
# mounts that appear or disappear and free space below HOST_GUARD_MIN_FREE_GB
# (default 20) count as deviations.
#
# Hotplug nodes are ignored in the /dev comparison so a Bluetooth headset,
# USB stick or similar can come and go while a long build runs:
#   /dev/input/*, /dev/hidraw*, /dev/snd/*, /dev/bus/usb/*,
#   /dev/char/13:* (input), /dev/char/116:* (ALSA), /dev/char/189:* (USB).
# Mass loss of /dev still fails: /dev/null and the remaining nodes are checked.
#
#############################################################################

MIN_FREE_GB="${HOST_GUARD_MIN_FREE_GB:-20}"
TOOLS_DIR=`cd "$(dirname "$0")" && pwd`
PROJECT_DIR=`cd "$TOOLS_DIR/../.." && pwd`

usage() {
   echo "Usage: `basename "$0"` snapshot|check <file>" >&2
   exit 2
}

[ "$#" -eq 2 ] || usage
MODE="$1"
FILE="$2"

state() {
   echo "## dev"
   find /dev -xdev \( -type c -o -type b -o -type l \) -printf '%y %p\n' 2>/dev/null | sort
   echo "## mounts"
   findmnt -rn -o TARGET,FSTYPE | sort
}

# Drop lines for device classes that appear and disappear during normal use.
# Input format: "<type> <path>" from find -printf '%y %p\n'.
filter_hotplug_dev() {
   grep -Ev ' /dev/(input/|hidraw|snd/|bus/usb/|char/(13|116|189):)' || true
}

free_gb() {
   df -P -B1G "$PROJECT_DIR" | awk 'NR == 2 {print $4}'
}

case "$MODE" in
   snapshot)
      state > "$FILE"
      echo "host_guard: snapshot in $FILE (free: `free_gb` GB)"
      ;;
   check)
      [ -f "$FILE" ] || { echo "host_guard: no snapshot $FILE" >&2 ; exit 2 ; }
      NOW=`mktemp`
      state > "$NOW"
      FAIL=0
      if [ ! -c /dev/null ] || [ ! -c /dev/zero ] || [ ! -c /dev/urandom ] ; then
         echo "host_guard: ERROR: /dev/null, /dev/zero or /dev/urandom is no character device" >&2
         FAIL=1
      fi
      section() {
         sed -n "/^## $1\$/,/^## /p" "$2" | grep -v '^## ' | sort
      }
      section dev "$FILE" | filter_hotplug_dev > "$NOW.dev.old"
      section dev "$NOW" | filter_hotplug_dev > "$NOW.dev.new"
      section mounts "$FILE" > "$NOW.mnt.old"
      section mounts "$NOW" > "$NOW.mnt.new"
      MISSING_DEV=`comm -23 "$NOW.dev.old" "$NOW.dev.new"`
      if [ -n "$MISSING_DEV" ] ; then
         echo "host_guard: ERROR: entries missing in /dev:" >&2
         echo "$MISSING_DEV" | head -20 >&2
         FAIL=1
      fi
      GONE_MOUNTS=`comm -23 "$NOW.mnt.old" "$NOW.mnt.new"`
      if [ -n "$GONE_MOUNTS" ] ; then
         echo "host_guard: ERROR: mounts disappeared:" >&2
         echo "$GONE_MOUNTS" >&2
         FAIL=1
      fi
      ADDED_MOUNTS=`comm -13 "$NOW.mnt.old" "$NOW.mnt.new"`
      PROJECT_MOUNTS=`echo "$ADDED_MOUNTS" | awk -v d="$PROJECT_DIR" \
         '$1 == d || index($1, d "/") == 1'`
      if [ -n "$PROJECT_MOUNTS" ] ; then
         echo "host_guard: ERROR: new mounts in the project directory:" >&2
         echo "$PROJECT_MOUNTS" >&2
         FAIL=1
      elif [ -n "$ADDED_MOUNTS" ] ; then
         echo "host_guard: note: new mounts outside the project (Docker, USB, ...):"
         echo "$ADDED_MOUNTS"
      fi
      rm -f "$NOW.dev.old" "$NOW.dev.new" "$NOW.mnt.old" "$NOW.mnt.new"
      FREE=`free_gb`
      if [ "$FREE" -lt "$MIN_FREE_GB" ] ; then
         echo "host_guard: ERROR: only $FREE GB free on the project file system" >&2
         FAIL=1
      fi
      rm -f "$NOW"
      if [ "$FAIL" -ne 0 ] ; then
         echo "host_guard: the build host CHANGED, do not continue." >&2
         exit 1
      fi
      echo "host_guard: build host unchanged (free: $FREE GB)"
      ;;
   *)
      usage
      ;;
esac
