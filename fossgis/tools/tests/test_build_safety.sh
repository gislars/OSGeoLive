#!/bin/sh
#############################################################################
#
# Purpose: Verify the build-host safety measures from
#          docs/fossgis/build-safety.md.
#
# Usage:   test_build_safety.sh [--static|--runtime|--all]
#
#          --static   (default) no root: source text of build_chroot.sh and
#                     a dry check of check_build_log.sh against fixtures
#          --runtime  needs sudo: bind-mount a fake /dev, hold it busy,
#                     confirm --one-file-system and remove_chroot behaviour
#          --all      static then runtime
#
#############################################################################

set -u

MODE="static"
case "${1:-}" in
   ""|--static) MODE="static" ;;
   --runtime) MODE="runtime" ;;
   --all) MODE="all" ;;
   -h|--help)
      sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
   *) echo "Usage: test_build_safety.sh [--static|--runtime|--all]" >&2 ; exit 2 ;;
esac

TOOLS_DIR=$(cd "$(dirname "$0")/.." && pwd)
TOP=$(cd "$TOOLS_DIR/../.." && pwd)
BUILD_CHROOT="$TOP/bin/build_chroot.sh"
CHECK_LOG="$TOOLS_DIR/check_build_log.sh"
FAILS=0

pass() { echo "ok: $*" ; }
fail() { echo "FAIL: $*" >&2 ; FAILS=$((FAILS + 1)) ; }

run_static() {
   echo "=== static ==="
   [ -f "$BUILD_CHROOT" ] || { fail "missing $BUILD_CHROOT" ; return ; }
   [ -x "$CHECK_LOG" ] || fail "check_build_log.sh not executable"

   if grep -E -q 'mount[[:space:]]+--bind[[:space:]]+/dev/' "$BUILD_CHROOT" ; then
      fail "build_chroot.sh still bind-mounts the host /dev"
   else
      pass "no mount --bind /dev/"
   fi
   if grep -q 'systemd-nspawn' "$BUILD_CHROOT" ; then
      pass "uses systemd-nspawn"
   else
      fail "build_chroot.sh does not call systemd-nspawn"
   fi
   if grep -E -q '/tmp/inchroot\.sh' "$BUILD_CHROOT" ; then
      fail "build_chroot still starts inchroot from /tmp (hidden by nspawn tmpfs)"
   elif grep -q '/usr/local/share/gisvm/bin/inchroot.sh' "$BUILD_CHROOT" ; then
      pass "inchroot runs from /usr/local/share/gisvm"
   else
      fail "inchroot path not found in build_chroot.sh"
   fi
   if grep -E -q 'mksquashfs .* -one-file-system' "$BUILD_CHROOT" ; then
      pass "mksquashfs -one-file-system"
   else
      fail "mksquashfs without -one-file-system"
   fi
   if grep -q 'rm -rf --one-file-system' "$BUILD_CHROOT" ; then
      pass "rm -rf --one-file-system"
   else
      fail "remove_chroot without --one-file-system"
   fi
   if grep -q 'check_build_log\.sh' "$BUILD_CHROOT" ; then
      pass "build_chroot calls check_build_log.sh"
   else
      fail "build_chroot does not call check_build_log.sh"
   fi
   if grep -E -q 'umount.*busy|is busy.*aborting' "$BUILD_CHROOT" ; then
      pass "busy umount aborts"
   else
      fail "no abort path for a busy umount"
   fi

   FIX=`mktemp -d /tmp/fossgis-safety-static.XXXXXX`
   BAD="$FIX/bad-busy.log"
   GOOD="$FIX/good-clean.log"
   printf '%s\n' 'umount: /srv/fossgis/build/edit/dev: target is busy.' > "$BAD"
   printf '%s\n' 'Finished building ok' > "$GOOD"
   if "$CHECK_LOG" "$BAD" > /dev/null 2>&1 ; then
      fail "check_build_log accepted a busy umount log"
   else
      pass "check_build_log rejects target is busy"
   fi
   if "$CHECK_LOG" "$GOOD" > /dev/null 2>&1 ; then
      pass "check_build_log accepts a clean log"
   else
      fail "check_build_log rejected a clean log"
   fi
   rm -rf "$FIX"
}

run_runtime() {
   echo "=== runtime (sudo) ==="
   if [ "$(id -u)" -eq 0 ] ; then
      SUDO=""
   elif ! command -v sudo > /dev/null ; then
      fail "runtime tests need root or sudo"
      return
   elif sudo -n true 2>/dev/null ; then
      SUDO="sudo"
   elif [ -t 0 ] && [ -t 2 ] ; then
      # ask for the password in an interactive terminal
      if ! sudo -v ; then
         fail "sudo authentication failed"
         return
      fi
      SUDO="sudo"
   else
      echo "SKIP: runtime tests need root or an interactive sudo."
      echo "      In a terminal: fossgis/tools/tests/test_build_safety.sh --runtime"
      return
   fi
   if ! command -v mksquashfs > /dev/null ; then
      fail "mksquashfs missing"
      return
   fi

   TMP=`mktemp -d /tmp/fossgis-safety.XXXXXX` || { fail "mktemp" ; return ; }
   cleanup() {
      if mountpoint -q "$TMP/edit/dev" 2>/dev/null ; then
         $SUDO umount -l "$TMP/edit/dev" 2>/dev/null || true
      fi
      rm -rf "$TMP"
   }
   trap cleanup EXIT INT TERM

   mkdir -p "$TMP/edit/usr" "$TMP/edit/dev" "$TMP/fake_dev" "$TMP/out"
   echo "only-in-edit" > "$TMP/edit/usr/marker"
   echo "HOST_SECRET_NODE" > "$TMP/fake_dev/should-not-appear"
   $SUDO mount --bind "$TMP/fake_dev" "$TMP/edit/dev"
   if ! mountpoint -q "$TMP/edit/dev" ; then
      fail "could not bind-mount the fake /dev"
      return
   fi

   # Hold the bind busy so a naive umount fails (same class of fault as postgres)
   $SUDO sh -c "tail -f \"$TMP/edit/dev/should-not-appear\" > /dev/null & echo \$! > \"$TMP/holder.pid\""
   sleep 0.3
   if $SUDO umount "$TMP/edit/dev" 2>"$TMP/umount.err" ; then
      fail "expected umount of busy edit/dev to fail"
   else
      if grep -qi 'busy' "$TMP/umount.err" ; then
         pass "busy edit/dev refuses umount"
      else
         fail "umount failed without 'busy': $(cat "$TMP/umount.err")"
      fi
   fi

   # mksquashfs must not pack the fake /dev contents
   if $SUDO mksquashfs "$TMP/edit" "$TMP/out/fs.squashfs" -one-file-system -no-progress > /dev/null ; then
      if $SUDO unsquashfs -l "$TMP/out/fs.squashfs" 2>/dev/null | grep -q 'HOST_SECRET_NODE' ; then
         fail "mksquashfs -one-file-system still packed the bind-mounted fake /dev"
      else
         pass "mksquashfs -one-file-system skips the bind-mounted fake /dev"
      fi
   else
      fail "mksquashfs -one-file-system failed"
   fi

   # remove with --one-file-system must not wipe fake_dev
   $SUDO umount -l "$TMP/edit/dev" 2>/dev/null || true
   if [ -n "`cat "$TMP/holder.pid" 2>/dev/null`" ] ; then
      kill `cat "$TMP/holder.pid"` 2>/dev/null || true
      wait `cat "$TMP/holder.pid"` 2>/dev/null || true
   fi
   # remount briefly, then lazy-detach and delete like remove_chroot
   $SUDO mount --bind "$TMP/fake_dev" "$TMP/edit/dev"
   $SUDO umount -l "$TMP/edit/dev"
   # wait until the lazy umount settles
   I=0
   while mountpoint -q "$TMP/edit/dev" 2>/dev/null && [ "$I" -lt 50 ] ; do
      sleep 0.1
      I=$((I + 1))
   done
   if mountpoint -q "$TMP/edit/dev" 2>/dev/null ; then
      fail "lazy umount of edit/dev did not finish"
   else
      $SUDO rm -rf --one-file-system "$TMP/edit"
      if [ -f "$TMP/fake_dev/should-not-appear" ] ; then
         pass "rm --one-file-system left the fake /dev contents alone"
      else
         fail "rm --one-file-system deleted the bind source (fake /dev)"
      fi
   fi

   trap - EXIT INT TERM
   cleanup
}

case "$MODE" in
   static) run_static ;;
   runtime) run_runtime ;;
   all) run_static ; run_runtime ;;
esac

echo "test_build_safety: $FAILS failure(s)"
[ "$FAILS" -eq 0 ]
