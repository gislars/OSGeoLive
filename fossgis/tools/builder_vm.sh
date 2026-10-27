#!/bin/sh
#############################################################################
#
# Purpose: Build OSGeoLive inside a throwaway QEMU/KVM virtual machine, so
#          that a faulty build can only damage the VM, never the build host.
#          Runs as the normal user, never with sudo.
#
# Usage:   builder_vm.sh create     download the Ubuntu cloud image, create
#                                   the VM disk and the cloud-init seed
#          builder_vm.sh start      boot the VM in the background
#          builder_vm.sh build [--ref <ref>] [args for build_chroot.sh,
#                                   default: amd64 nightly]
#                                   build the committed HEAD of this checkout,
#                                   or <ref> (branch or tag)
#          builder_vm.sh follow     follow the log of a running build again
#          builder_vm.sh fetch      copy ISO, log and new cache files back
#          builder_vm.sh ssh        shell in the VM
#          builder_vm.sh stop       shut the VM down
#          builder_vm.sh destroy    stop the VM and delete build/vm/
#
# Isolation: the VM shares no directory with the host. The sources go in as
#   a git bundle of HEAD, local/ (without docs/ and tools/) via rsync. Only
#   the ISO, the build log and new files of local/cache come back. The VM
#   reaches the internet through QEMU user networking; new connections to
#   the host (10.0.2.2) are dropped inside the VM. ssh listens on
#   127.0.0.1 only.
#
# Settings (environment): FOSSGIS_VM_CPUS (8), FOSSGIS_VM_RAM (16G),
#   FOSSGIS_VM_DISK (80G), FOSSGIS_VM_SSH_PORT (2227),
#   FOSSGIS_VM_MARGIN_GB (20, free space that must remain on the host).
#
#############################################################################

VM_CPUS="${FOSSGIS_VM_CPUS:-8}"
VM_RAM="${FOSSGIS_VM_RAM:-16G}"
VM_DISK="${FOSSGIS_VM_DISK:-80G}"
VM_SSH_PORT="${FOSSGIS_VM_SSH_PORT:-2227}"
VM_MARGIN_GB="${FOSSGIS_VM_MARGIN_GB:-20}"

IMAGE_URL="https://cloud-images.ubuntu.com/releases/26.04/release"
IMAGE_FILE="ubuntu-26.04-server-cloudimg-amd64.img"

TOOLS_DIR=`cd "$(dirname "$0")" && pwd`
GIT_DIR=`git -C "$TOOLS_DIR" rev-parse --show-toplevel`
MAIN_DIR=`dirname "$(git -C "$GIT_DIR" rev-parse --path-format=absolute --git-common-dir)"`
BUILD_DIR="$MAIN_DIR/build"
LOCAL_DIR="$MAIN_DIR/local"
VM_DIR="$BUILD_DIR/vm"
GUARD="$TOOLS_DIR/host_guard.sh"

# Paths inside the VM
VM_BASE=/srv/fossgis
VM_BUILD="$VM_BASE/build"

die() {
   echo "builder_vm: ERROR: $*" >&2
   exit 1
}

if [ "`id -u`" -eq 0 ] ; then
   die "do not run this with sudo, the VM runs as the normal user."
fi

vm_ssh() {
   ssh -i "$VM_DIR/id_ed25519" -p "$VM_SSH_PORT" \
      -o UserKnownHostsFile="$VM_DIR/known_hosts" \
      -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
      -o ConnectTimeout=5 -o ServerAliveInterval=30 \
      builder@127.0.0.1 "$@"
}

vm_rsync() {
   rsync -e "ssh -i $VM_DIR/id_ed25519 -p $VM_SSH_PORT -o UserKnownHostsFile=$VM_DIR/known_hosts -o StrictHostKeyChecking=accept-new -o BatchMode=yes" "$@"
}

vm_running() {
   [ -f "$VM_DIR/qemu.pid" ] && kill -0 "`cat "$VM_DIR/qemu.pid"`" 2>/dev/null
}

free_gb() {
   df -P -B1G "$1" | awk 'NR == 2 {print $4}'
}

size_gb() {
   echo "$1" | sed -n 's/^\([0-9]*\)G$/\1/p'
}

# The VM disk may still grow up to VM_DISK; that plus the margin must fit
check_space() {
   DISK_GB=`size_gb "$VM_DISK"`
   [ -n "$DISK_GB" ] || die "FOSSGIS_VM_DISK must be given in G, e.g. 80G."
   USED_GB=0
   if [ -f "$VM_DIR/builder.qcow2" ] ; then
      USED_GB=$(( `du -B1G "$VM_DIR/builder.qcow2" | cut -f1` ))
   fi
   NEED_GB=$(( DISK_GB - USED_GB + VM_MARGIN_GB ))
   FREE_GB=`free_gb "$BUILD_DIR"`
   if [ "$FREE_GB" -lt "$NEED_GB" ] ; then
      die "only $FREE_GB GB free, the VM needs up to $NEED_GB GB (disk $VM_DISK, margin $VM_MARGIN_GB GB)."
   fi
}

cmd_create() {
   [ -f "$VM_DIR/builder.qcow2" ] && die "$VM_DIR/builder.qcow2 exists, use destroy first."
   command -v qemu-system-x86_64 > /dev/null || die "qemu-system-x86_64 is missing."
   command -v qemu-img > /dev/null || die "qemu-img is missing."
   command -v xorriso > /dev/null || die "xorriso is missing (seed image)."
   if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ] ; then
      die "no access to /dev/kvm as `id -un`."
   fi
   mkdir -p "$VM_DIR"
   check_space

   echo "Downloading $IMAGE_FILE ..."
   wget -q --show-progress -c -O "$VM_DIR/$IMAGE_FILE" "$IMAGE_URL/$IMAGE_FILE" || \
      die "download of $IMAGE_URL/$IMAGE_FILE failed."
   wget -q -O "$VM_DIR/SHA256SUMS" "$IMAGE_URL/SHA256SUMS" || die "download of SHA256SUMS failed."
   (cd "$VM_DIR" && grep " \*\?$IMAGE_FILE\$" SHA256SUMS | sha256sum -c -) || \
      die "checksum of $IMAGE_FILE does not match."

   qemu-img create -q -f qcow2 -F qcow2 -b "$IMAGE_FILE" "$VM_DIR/builder.qcow2" "$VM_DISK" || \
      die "could not create the VM disk."

   ssh-keygen -q -t ed25519 -N '' -C fossgis-builder -f "$VM_DIR/id_ed25519" || \
      die "could not create the ssh key."

   mkdir -p "$VM_DIR/seed"
   cat > "$VM_DIR/seed/meta-data" << EOF
instance-id: fossgis-builder
local-hostname: fossgis-builder
EOF
   cat > "$VM_DIR/seed/user-data" << EOF
#cloud-config
users:
  - name: builder
    groups: [sudo]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - `cat "$VM_DIR/id_ed25519.pub"`
ssh_pwauth: false
package_update: true
packages: [git, rsync, nftables]
write_files:
  - path: /etc/nftables.conf
    permissions: "0644"
    content: |
      #!/usr/sbin/nft -f
      flush ruleset
      # QEMU user networking maps the host to 10.0.2.2; the build must
      # not reach services of the host. Replies to the ssh port forward
      # are established connections and stay allowed.
      table inet fossgis_hostblock {
        chain output {
          type filter hook output priority 0; policy accept;
          ct state established,related accept
          ip daddr 10.0.2.2 drop
        }
      }
runcmd:
  - [systemctl, enable, --now, nftables]
  - [mkdir, -p, $VM_BASE/local, $VM_BUILD]
  - [chown, -R, builder:builder, $VM_BASE]
EOF
   xorriso -as mkisofs -quiet -output "$VM_DIR/seed.iso" -volid cidata -joliet -rock \
      "$VM_DIR/seed/user-data" "$VM_DIR/seed/meta-data" || die "could not create the seed image."
   echo "VM created in $VM_DIR (disk up to $VM_DISK). Next: builder_vm.sh start"
}

cmd_start() {
   [ -f "$VM_DIR/builder.qcow2" ] || die "no VM, run create first."
   vm_running && { echo "VM is already running." ; return 0 ; }
   check_space
   rm -f "$VM_DIR/qemu.pid"
   qemu-system-x86_64 -name fossgis-builder \
      -machine q35,accel=kvm -cpu host -smp "$VM_CPUS" -m "$VM_RAM" \
      -sandbox on,obsolete=deny,resourcecontrol=deny \
      -drive file="$VM_DIR/builder.qcow2",if=virtio,format=qcow2 \
      -drive file="$VM_DIR/seed.iso",if=virtio,format=raw,readonly=on \
      -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:"$VM_SSH_PORT"-:22 \
      -display none -serial file:"$VM_DIR/console.log" \
      -daemonize -pidfile "$VM_DIR/qemu.pid" || die "QEMU did not start."
   printf "Waiting for the VM"
   I=0
   while [ "$I" -lt 120 ] ; do
      if vm_ssh true 2>/dev/null ; then
         echo
         vm_ssh cloud-init status --wait > /dev/null 2>&1
         vm_ssh sudo nft list table inet fossgis_hostblock > /dev/null 2>&1 || \
            die "the host block in the VM is not active, see $VM_DIR/console.log."
         echo "VM is up (ssh: builder_vm.sh ssh)."
         return 0
      fi
      printf "."
      sleep 5
      I=$((I + 1))
   done
   echo
   die "the VM did not answer within 10 minutes, see $VM_DIR/console.log."
}

cmd_build() {
   vm_running || die "the VM is not running, use start first."
   REF=HEAD
   if [ "${1:-}" = "--ref" ] ; then
      [ -n "${2:-}" ] || die "--ref needs a branch or tag."
      REF=`git -C "$GIT_DIR" rev-parse --symbolic-full-name "$2"`
      [ -n "$REF" ] || die "$2 is no branch or tag."
      shift 2
   fi
   [ "$#" -eq 0 ] && set -- amd64 nightly
   COMMIT=`git -C "$GIT_DIR" rev-parse --verify "$REF^{commit}"` || die "unknown ref $REF."
   if [ "$REF" = "HEAD" ] && [ -n "`git -C "$GIT_DIR" status --porcelain --untracked-files=no`" ] ; then
      echo "builder_vm: note: uncommitted changes are NOT part of the build, building $COMMIT."
   fi
   vm_ssh systemctl is-active --quiet fossgis-build && die "a build is already running (follow)."

   "$GUARD" snapshot "$VM_DIR/host-guard.snapshot" || die "host_guard snapshot failed."

   echo "Sending sources ($COMMIT) and local/ ..."
   git -C "$GIT_DIR" bundle create -q "$VM_DIR/src.bundle" "$REF" --tags || die "git bundle failed."
   vm_rsync -a "$VM_DIR/src.bundle" builder@127.0.0.1:"$VM_BASE/src.bundle" || die "copy of the bundle failed."
   if [ -f "$LOCAL_DIR/local.env" ] && grep -q '^[[:space:]]*FOSSGIS_CACHE_DIR=' "$LOCAL_DIR/local.env" ; then
      echo "builder_vm: note: FOSSGIS_CACHE_DIR from local.env is a host path, the VM uses $VM_BASE/local/cache."
   fi
   # the build in the VM runs as root and leaves root owned cache files
   vm_ssh "sudo mkdir -p $VM_BASE/local && sudo chown -R builder: $VM_BASE/local" || \
      die "could not take over $VM_BASE/local in the VM."
   vm_rsync -a --delete --exclude=/docs/ --exclude=/tools/ --exclude=/cache/apt/partial/ \
      "$LOCAL_DIR"/ builder@127.0.0.1:"$VM_BASE/local/" || die "copy of local/ failed."
   # an already downloaded Lubuntu image saves the download in the VM,
   # only the release the built commit asks for
   ISO_RELEASE=`git -C "$GIT_DIR" show "$COMMIT":bin/build_chroot.sh | \
      sed -n 's/^ISO_RELEASE="\([^"]*\)".*/\1/p' | head -n 1`
   UBU_ISO="$BUILD_DIR/lubuntu-$ISO_RELEASE-desktop-$1.iso"
   if [ -n "$ISO_RELEASE" ] && [ -f "$UBU_ISO" ] ; then
      vm_rsync -a --ignore-existing "$UBU_ISO" builder@127.0.0.1:"$VM_BUILD/" || \
         die "copy of `basename "$UBU_ISO"` failed."
   fi

   vm_ssh "set -e
      sudo rm -rf --one-file-system $VM_BASE/src
      sudo git init -q $VM_BASE/src
      sudo git -C $VM_BASE/src fetch -q $VM_BASE/src.bundle '+refs/tags/*:refs/tags/*' '$REF'
      sudo git -C $VM_BASE/src checkout -q --detach $COMMIT
      test \"\`sudo git -C $VM_BASE/src rev-parse HEAD\`\" = $COMMIT
      sudo sed -i '/^[[:space:]]*FOSSGIS_CACHE_DIR=/d' $VM_BASE/local/local.env 2>/dev/null || true
      sudo rm -f $VM_BUILD/logs/latest.log
      sudo systemd-run --unit=fossgis-build --collect --quiet \
         --working-directory=$VM_BASE/src \
         --setenv=BUILD_DIR=$VM_BUILD --setenv=FOSSGIS_LOCAL_DIR=$VM_BASE/local \
         $VM_BASE/src/bin/build_chroot.sh $*" || die "starting the build in the VM failed."
   echo "Build started in the VM."
   cmd_follow
}

cmd_follow() {
   vm_running || die "the VM is not running."
   # wait for the log of this build, then follow it until the unit ends
   vm_ssh "for i in \$(seq 60) ; do [ -e $VM_BUILD/logs/latest.log ] && break ; sleep 2 ; done
      LOG=\$(readlink -f $VM_BUILD/logs/latest.log)
      PID=\$(systemctl show -p MainPID --value fossgis-build 2>/dev/null)
      if [ -n \"\$PID\" ] && [ \"\$PID\" != 0 ] ; then
         tail -n +1 -F --pid=\"\$PID\" \"\$LOG\" 2>/dev/null
      else
         cat \"\$LOG\"
      fi"
   if vm_ssh systemctl is-active --quiet fossgis-build ; then
      echo "builder_vm: the build is still running (connection lost?), use follow again."
      return 0
   fi
   cmd_fetch
}

cmd_fetch() {
   vm_running || die "the VM is not running."
   LOG=`vm_ssh "readlink -f $VM_BUILD/logs/latest.log"` || die "no build log in the VM."
   LOG_NAME=`basename "$LOG"`
   mkdir -p "$BUILD_DIR/logs"
   vm_rsync -a builder@127.0.0.1:"$LOG" "$BUILD_DIR/logs/$LOG_NAME" || die "copy of the log failed."
   vm_ssh "grep -F '$LOG_NAME' $VM_BUILD/logs/index.tsv" >> "$BUILD_DIR/logs/index.tsv"
   ln -sfn "$LOG_NAME" "$BUILD_DIR/logs/latest.log"

   ISO=`sed -n 's/^# iso=\([^ ]*\) .*/\1/p' "$BUILD_DIR/logs/$LOG_NAME" | tail -n 1`
   if [ -n "$ISO" ] && [ "$ISO" != "none" ] ; then
      ISO_GB=$(( `vm_ssh "stat -c %s $VM_BUILD/$ISO"` / 1073741824 + 1 ))
      if [ "`free_gb "$BUILD_DIR"`" -lt $(( ISO_GB + VM_MARGIN_GB )) ] ; then
         die "not enough free space for $ISO ($ISO_GB GB) plus margin, left it in the VM."
      fi
      vm_rsync -a builder@127.0.0.1:"$VM_BUILD/$ISO" "$BUILD_DIR/$ISO" || die "copy of $ISO failed."
      vm_ssh "sudo rm -f $VM_BUILD/$ISO"
      echo "ISO: $BUILD_DIR/$ISO"
   fi

   # new cache files only, nothing is deleted on the host
   mkdir -p "$LOCAL_DIR/cache"
   CACHE_GB=`vm_ssh "du -s -B1G $VM_BASE/local/cache 2>/dev/null | cut -f1"`
   if [ -n "$CACHE_GB" ] && [ "`free_gb "$LOCAL_DIR"`" -lt $(( CACHE_GB + VM_MARGIN_GB )) ] ; then
      echo "builder_vm: note: not enough free space, the cache stays in the VM."
   else
      vm_rsync -a --ignore-existing --exclude=/apt/partial/ --exclude=/apt/lock \
         builder@127.0.0.1:"$VM_BASE/local/cache/" "$LOCAL_DIR/cache/" || \
         echo "builder_vm: note: some cache files could not be copied back."
   fi

   echo "Log: $BUILD_DIR/logs/$LOG_NAME"
   BUILD_EXIT=`sed -n 's/^# exit=//p' "$BUILD_DIR/logs/$LOG_NAME" | tail -n 1`
   echo "exit=${BUILD_EXIT:-unknown}"
   "$GUARD" check "$VM_DIR/host-guard.snapshot" || exit 1
   [ "$BUILD_EXIT" = 0 ] || die "the build failed (exit=${BUILD_EXIT:-unknown}), see the log."
}

cmd_stop() {
   vm_running || { echo "VM is not running." ; return 0 ; }
   vm_ssh sudo poweroff > /dev/null 2>&1
   I=0
   while vm_running && [ "$I" -lt 60 ] ; do
      sleep 2
      I=$((I + 1))
   done
   if vm_running ; then
      echo "VM did not shut down, stopping QEMU."
      kill "`cat "$VM_DIR/qemu.pid"`"
   fi
   rm -f "$VM_DIR/qemu.pid"
   echo "VM stopped."
}

cmd_destroy() {
   cmd_stop
   [ -d "$VM_DIR" ] || return 0
   case "$VM_DIR" in
      "$BUILD_DIR"/vm) ;;
      *) die "refusing to delete $VM_DIR." ;;
   esac
   rm -rf --one-file-system "$VM_DIR"
   echo "VM deleted."
}

COMMAND="$1"
[ "$#" -gt 0 ] && shift
case "$COMMAND" in
   create) cmd_create ;;
   start) cmd_start ;;
   build) cmd_build "$@" ;;
   follow) cmd_follow ;;
   fetch) cmd_fetch ;;
   ssh) vm_ssh "$@" ;;
   stop) cmd_stop ;;
   destroy) cmd_destroy ;;
   *)
      sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 2
      ;;
esac
