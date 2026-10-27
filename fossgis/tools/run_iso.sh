#!/bin/sh
#############################################################################
#
# Purpose: Start a built OSGeoLive ISO in QEMU/KVM, booting with UEFI and
#          sharing the clipboard with the host through SPICE
#          (remote-viewer on the host, spice-vdagent in the guest).
#
# Usage:   run_iso.sh [--bios] [iso]
#
#          Without an ISO the newest build/osgeolive-*.iso is used.
#          --bios boots with the legacy BIOS instead of UEFI.
#
#############################################################################

set -eu

usage() {
    echo "Usage: run_iso.sh [--bios] [iso]"
}

TOP=$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")
BUILD_DIR="${BUILD_DIR:-$TOP/build}"
OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
OVMF_VARS=/usr/share/OVMF/OVMF_VARS_4M.fd

FIRMWARE="uefi"
ISO=""
for ARG in "$@" ; do
    case "$ARG" in
        --bios) FIRMWARE="bios" ;;
        -h|--help) usage ; exit 0 ;;
        -*) usage >&2 ; exit 2 ;;
        *) ISO="$ARG" ;;
    esac
done

if [ -z "$ISO" ] ; then
    for CANDIDATE in "$BUILD_DIR"/osgeolive-*.iso ; do
        [ -f "$CANDIDATE" ] || continue
        if [ -z "$ISO" ] || [ -n "$(find "$CANDIDATE" -newer "$ISO")" ] ; then
            ISO="$CANDIDATE"
        fi
    done
fi
if [ -z "$ISO" ] || [ ! -f "$ISO" ] ; then
    echo "No OSGeoLive ISO found in $BUILD_DIR" >&2
    exit 1
fi

set -- -enable-kvm -cpu host -smp 4 -m 8G \
    -cdrom "$ISO" -boot d \
    -vga virtio \
    -nic user,model=virtio-net-pci

# The GTK display of Ubuntu's QEMU is built without clipboard support,
# the SPICE viewer (remote-viewer from virt-viewer) shares it.
if command -v remote-viewer >/dev/null 2>&1 ; then
    set -- "$@" -display spice-app \
        -device virtio-serial-pci \
        -chardev spicevmc,id=vdagent,name=vdagent \
        -device virtserialport,chardev=vdagent,name=com.redhat.spice.0
else
    echo "remote-viewer not found, starting without shared clipboard." >&2
    echo "For the clipboard install it with: sudo apt install virt-viewer" >&2
    set -- "$@" -display gtk
fi

if [ "$FIRMWARE" = "uefi" ] ; then
    if [ ! -f "$OVMF_CODE" ] ; then
        echo "UEFI firmware $OVMF_CODE missing, install ovmf or use --bios" >&2
        exit 1
    fi
    # UEFI variables are written by the guest, so it needs a private copy
    VARS="$BUILD_DIR/ovmf_vars.fd"
    [ -f "$VARS" ] || cp "$OVMF_VARS" "$VARS"
    set -- "$@" -machine q35 \
        -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
        -drive if=pflash,format=raw,file="$VARS"
fi

echo "Starting $ISO ($FIRMWARE)"
exec qemu-system-x86_64 "$@"
