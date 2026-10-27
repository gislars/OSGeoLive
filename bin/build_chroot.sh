#!/bin/sh
#############################################################################
# 
# Purpose: Creating OSGeoLive as an Ubuntu customization
#          https://help.ubuntu.com/community/LiveCDCustomization
# Authors: Alex Mandel <tech_dev@wildintellect.com>
#          Angelos Tzotsos <tzotsos@gmail.com>
#
#############################################################################
# Copyright (c) 2013-2026 Open Source Geospatial Foundation (OSGeo) and others.
#
# Licensed under the GNU LGPL.
# 
# This library is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 2.1 of the License,
# or any later version.  This library is distributed in the hope that
# it will be useful, but WITHOUT ANY WARRANTY, without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details, either
# in the "LICENSE.LGPL.txt" file distributed with this software or at
# web page "http://www.fsf.org/licenses/lgpl.html".
#############################################################################
#
# System Requirements
#
#     1. At least 3-5 GB of free space
#     2. At least 512 MB RAM and 1 GB swap (recommended)
#     3. squashfs-tools
#     4. genisoimage, which provides mkisofs
#     5. syslinux-utils, which provides isohybrid
#     6. An Ubuntu kernel with squashfs support (present in Ubuntu 6.06 and later)
#     7. QEMU/KVM, VirtualBox or VMware for testing (optional) 
#
#############################################################################

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    echo "Wrong number of arguments"
    echo "Usage: build_chroot.sh ARCH(i386 or amd64) MODE(release or nightly) [git_branch (default=master)] [github_username (default=gislars) or git clone url]"
    exit 1
fi

if [ "$1" != "i386" ] && [ "$1" != "amd64" ] ; then
    echo "Did not specify build architecture, try using i386 or amd64 as an argument"
    echo "Usage: build_chroot.sh ARCH(i386 or amd64) MODE(release or nightly) [git_branch (default=master)] [github_username (default=gislars) or git clone url]"
    exit 1
fi
ARCH="$1"

if [ "$2" != "release" ] && [ "$2" != "nightly" ] ; then
    echo "Did not specify build mode, try using release or nightly as an argument"
    echo "Usage: build_chroot.sh ARCH(i386 or amd64) MODE(release or nightly) [git_branch (default=master)] [github_username (default=gislars) or git clone url]"
    exit 1
fi
BUILD_MODE="$2"

if [ "$#" -eq 4 ]; then
    GIT_BRANCH="$3"
    GIT_USER="$4"
elif [ "$#" -eq 3 ]; then
    GIT_BRANCH="$3"
    GIT_USER="gislars"
else
    GIT_BRANCH="master"
    GIT_USER="gislars"
fi

DIR=`cd "$(dirname "$0")" && pwd`
GIT_DIR=`dirname "$DIR"`
if [ -z "$BUILD_DIR" ] ; then
    BUILD_DIR="$GIT_DIR/build"
fi
VERSION=`cat "$GIT_DIR"/VERSION.txt`
PACKAGE_NAME="osgeolive"
cd "$GIT_DIR"
REVISION=`git show-ref --head --hash head --hash=7`
REVISION_FULL=`git show-ref --head --hash head`

# Only release tags like 17.0.0, fork tags such as fossgis2027-base contain dashes
GIT_BUILD=`git describe --long --tags --match '[0-9]*' 2>/dev/null | awk -F'-' '{print $2}'`
if [ -z "$GIT_BUILD" ] ; then
    GIT_BUILD=`git rev-list --count HEAD`
fi

#Selecting iso name and build name
if [ "$BUILD_MODE" = "release" ]; then
    ISO_NAME="$PACKAGE_NAME-$VERSION-$ARCH"
    VERSION_MODE="$VERSION"
else
    ISO_NAME="$PACKAGE_NAME-nightly-build$GIT_BUILD-$ARCH-$REVISION-$GIT_BRANCH"
    VERSION_MODE="build$GIT_BUILD-$REVISION"
fi

# Every build writes its complete output to build/logs/<start>-<iso name>.log,
# build/logs/index.tsv lists all builds with commit and result.
if [ -z "$FOSSGIS_BUILD_LOG" ] ; then
    LOG_DIR="$BUILD_DIR/logs"
    mkdir -p "$LOG_DIR"
    FOSSGIS_BUILD_LOG="$LOG_DIR/`date +%Y%m%d-%H%M%S`-$ISO_NAME.log"
    export FOSSGIS_BUILD_LOG
    LOG_DESCRIBE=`git describe --long --tags --match '[0-9]*' 2>/dev/null`
    if LOG_STATUS=`git status --porcelain --untracked-files=no 2>/dev/null` ; then
        LOG_DIRTY=`printf '%s' "$LOG_STATUS" | grep -c .`
    else
        LOG_DIRTY="unknown"
    fi
    LOG_START=`date -Iseconds`
    {
        echo "# commit=$REVISION_FULL"
        echo "# describe=$LOG_DESCRIBE"
        echo "# dirty_files=$LOG_DIRTY"
        echo "# command=$0 $*"
        echo "# build_dir=$BUILD_DIR"
        echo "# start=$LOG_START"
    } > "$FOSSGIS_BUILD_LOG"
    echo "Build log: $FOSSGIS_BUILD_LOG"

    # Ctrl-C stops the build, but the log still gets its end lines and index entry
    trap 'echo "Build interrupted" >&2' INT TERM
    ( "$DIR/build_chroot.sh" "$@" ; echo "$?" > "$FOSSGIS_BUILD_LOG.rc" ) 2>&1 | \
        tee -a "$FOSSGIS_BUILD_LOG"
    trap - INT TERM
    BUILD_RC=`cat "$FOSSGIS_BUILD_LOG.rc" 2>/dev/null || echo interrupted`
    rm -f "$FOSSGIS_BUILD_LOG.rc"

    # exit=0 with a damaged image or a host-risk message still counts as failed
    if [ "$BUILD_RC" = "0" ] && \
          ! "$GIT_DIR"/fossgis/tools/check_build_log.sh "$FOSSGIS_BUILD_LOG" ; then
        echo "ERROR: critical messages in the build log, marking exit=1." >&2
        BUILD_RC=1
    fi

    ISO_FILE="$BUILD_DIR/$ISO_NAME.iso"
    if [ "$BUILD_RC" = "0" ] && [ -s "$ISO_FILE" ] ; then
        ISO_INFO="`basename "$ISO_FILE"` sha256=`sha256sum "$ISO_FILE" | cut -d' ' -f1`"
    else
        ISO_INFO="none"
    fi
    {
        echo "# end=`date -Iseconds`"
        echo "# exit=$BUILD_RC"
        echo "# iso=$ISO_INFO"
    } >> "$FOSSGIS_BUILD_LOG"

    if [ ! -f "$LOG_DIR/index.tsv" ] ; then
        printf 'start\texit\tcommit\tdescribe\tdirty_files\tiso\tlog\n' > "$LOG_DIR/index.tsv"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$LOG_START" "$BUILD_RC" "$REVISION_FULL" \
        "$LOG_DESCRIBE" "$LOG_DIRTY" "$ISO_INFO" "`basename "$FOSSGIS_BUILD_LOG"`" \
        >> "$LOG_DIR/index.tsv"
    ln -sfn "`basename "$FOSSGIS_BUILD_LOG"`" "$LOG_DIR/latest.log"
    if [ -n "$SUDO_USER" ] ; then
        chown -R "$SUDO_USER": "$LOG_DIR"
    fi

    echo "Build log: $FOSSGIS_BUILD_LOG (exit $BUILD_RC, iso: $ISO_INFO)"
    [ "$BUILD_RC" = "0" ] || exit 1
    exit 0
fi

echo
echo "==============================================================="
echo "Build parameters"
echo "==============================================================="

echo "ARCH: $ARCH"
echo "MODE: $BUILD_MODE"
if echo "$GIT_USER" | grep -q "://"; then
    echo "Git repository: $GIT_USER"
else
    echo "Git repository: https://github.com/$GIT_USER/OSGeoLive.git"
fi
echo "Git branch: $GIT_BRANCH"
echo "Source checkout: $GIT_DIR"
echo "Build directory: $BUILD_DIR"

#Volume name, max 11 chars:
IMAGE_NAME=OSGEOLIVE`echo "$VERSION" | cut -d '.' -f 1`
#IMAGE_NAME=OSGEOLIVE`echo "$VERSION" | sed -e 's/\.//' -e 's/rc.*//'`


echo
echo "==============================================================="
echo "Start Building $ISO_NAME"
echo "==============================================================="

# Mount points below a directory, deepest first
mounts_below() {
    awk -v d="$1" '$2 == d || index($2, d "/") == 1 {print $2}' /proc/self/mounts | sort -r
}

# rm -rf for the chroot: detach anything still mounted below it first
# (legacy edit/dev binds of the host /dev, cache mounts, nspawn leftovers)
# and never cross filesystem boundaries
remove_chroot() {
    for MOUNTPOINT in `mounts_below "$1"` ; do
        sudo umount -l "$MOUNTPOINT"
    done
    if [ -n "`mounts_below "$1"`" ] ; then
        echo "ERROR: still mounted below $1, not deleting it:" >&2
        mounts_below "$1" >&2
        exit 1
    fi
    sudo rm -rf --one-file-system "$1"
}

#Some initial cleaning, including leftovers of an aborted previous build
# The cache mounts come first, rm -rf edit would otherwise empty the cache
for MOUNTPOINT in edit/var/cache/apt/archives edit/var/cache/fossgis-downloads \
      edit/dev edit/dev/pts edit/proc edit/sys mnt ; do
    if mountpoint -q "$BUILD_DIR/$MOUNTPOINT" 2>/dev/null ; then
        sudo umount -l "$BUILD_DIR/$MOUNTPOINT"
    fi
done
for MOUNTPOINT in edit/var/cache/apt/archives edit/var/cache/fossgis-downloads ; do
    if mountpoint -q "$BUILD_DIR/$MOUNTPOINT" 2>/dev/null ; then
        echo "ERROR: $BUILD_DIR/$MOUNTPOINT is still mounted, not deleting edit/." >&2
        exit 1
    fi
done
# Read-only mounts of the squashfs layers of a layered image (see below)
for MOUNTPOINT in "$BUILD_DIR"/layers/merged "$BUILD_DIR"/layers/*.squashfs ; do
    if mountpoint -q "$MOUNTPOINT" 2>/dev/null ; then
        sudo umount -l "$MOUNTPOINT"
    fi
done
rm -rf "$BUILD_DIR"/layers
remove_chroot "$BUILD_DIR"/edit
rm -f "$BUILD_DIR"/cdrom.sources.parked
rm -rf "$BUILD_DIR"/lzfiles
rm -rf "$BUILD_DIR"/extract-cd
rm -rf "$BUILD_DIR"/mnt
rm -f "$BUILD_DIR"/*.partition
rm -rf "$BUILD_DIR"/wget-log
rm -rf "$BUILD_DIR"/squashfs-root
rm -f "$BUILD_DIR"/myinitrd

echo
echo "Installing build tools"
echo "======================"

sudo apt-get install --yes squashfs-tools genisoimage syslinux-utils lzip binwalk lz4 zstd xorriso rsync

#TODO add wget to grab a fresh image, optional

echo
echo "Downloading Lubuntu original image..."
echo "====================================="

#Stuff to be done the 1st time, should already be in place for additional builds
#Download into an empty directory 
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
#mv ubuntu-9.04-desktop-i386.iso ~/livecdtmp
UBU_MIRROR="http://cdimage.ubuntu.com"
UBU_RELEASE="26.04"
# cdimage only keeps the latest point release of a series
ISO_RELEASE="26.04.1"
# ISO_RELEASE="22.04-beta"
UBU_ISO="lubuntu-${ISO_RELEASE}-desktop-$ARCH.iso"
UBU_ISO_URL="$UBU_MIRROR/lubuntu/releases/$UBU_RELEASE/release"
   # UBU_ISO_URL="$UBU_MIRROR/lubuntu/releases/$UBU_RELEASE/beta"
if ! wget -c --progress=dot:mega "$UBU_ISO_URL/$UBU_ISO" ; then
   echo "ERROR: download of $UBU_ISO_URL/$UBU_ISO failed." >&2
   exit 1
fi
if ! wget -q -O SHA256SUMS "$UBU_ISO_URL/SHA256SUMS" || \
   ! grep " \*$UBU_ISO\$" SHA256SUMS | sha256sum -c - ; then
   echo "ERROR: checksum of $UBU_ISO could not be verified, remove it to download again." >&2
   exit 1
fi
#Start with a fresh copy
#Mount the Desktop .iso
mkdir -p mnt
if ! sudo mount -o loop,ro "$UBU_ISO" mnt ; then
   echo "ERROR: could not mount $UBU_ISO." >&2
   exit 1
fi
echo "Lubuntu $ISO_RELEASE $ARCH image mounted."

#Extract iso EFI and MBR partitions
EFI=efi.partition
MBR=mbr.partition
dd if="$UBU_ISO" bs=1 count=446 of="$MBR"
EFISKIP=$(/sbin/fdisk -l "$UBU_ISO" | fgrep '.iso2 ' | awk '{print $2}')
EFISIZE=$(/sbin/fdisk -l "$UBU_ISO" | fgrep '.iso2 ' | awk '{print $4}')
if [ -z "$EFISKIP" ] || [ -z "$EFISIZE" ] ; then
   echo "ERROR: no EFI partition found in $UBU_ISO." >&2
   sudo umount mnt
   exit 1
fi
dd if="$UBU_ISO" bs=512 skip="$EFISKIP" count="$EFISIZE" of="$EFI"

#Extract .iso contents into dir 'extract-cd' 
mkdir "extract-cd"
rsync --exclude='/casper/*.squashfs' -a mnt/ "extract-cd"

echo
echo "Extracting squashfs from Lubuntu image"
echo "======================================"
if [ -f mnt/casper/filesystem.squashfs ] ; then
   LAYERED_IMAGE="no"
   #Extract the SquashFS filesystem
   if ! sudo unsquashfs mnt/casper/filesystem.squashfs ; then
      echo "ERROR: could not extract mnt/casper/filesystem.squashfs." >&2
      sudo umount mnt
      exit 1
   fi
   #Does the above need to be done every time or can it be done once, and then
   # just make a fresh copy of the chroot for each builds
   sudo mv squashfs-root edit
else
   # Since 25.10 the system comes as stacked layers (minimal,
   # minimal.standard, minimal.standard.live). They are merged into one
   # filesystem.squashfs again: casper mounts it without layerfs-path and
   # Calamares installs it as a whole (see "Installer settings" below).
   LAYERED_IMAGE="yes"
   TOP_LAYER=""
   for LAYER_FILE in mnt/casper/*.squashfs ; do
      LAYER=`basename "$LAYER_FILE" .squashfs`
      if [ -z "$TOP_LAYER" ] || [ ${#LAYER} -gt ${#TOP_LAYER} ] ; then
         TOP_LAYER="$LAYER"
      fi
   done
   if [ -z "$TOP_LAYER" ] || [ ! -f "mnt/casper/$TOP_LAYER.squashfs" ] ; then
      echo "ERROR: no squashfs found in $UBU_ISO." >&2
      exit 1
   fi
   # Same chain as casper: each layer sits on the one without its last suffix
   mkdir -p layers/merged
   LOWERDIRS=""
   LAYER="$TOP_LAYER"
   while : ; do
      if [ ! -f "mnt/casper/$LAYER.squashfs" ] ; then
         echo "ERROR: layer $LAYER.squashfs of $TOP_LAYER is missing." >&2
         exit 1
      fi
      mkdir -p "layers/$LAYER.squashfs"
      if ! sudo mount -o loop,ro "mnt/casper/$LAYER.squashfs" "layers/$LAYER.squashfs" ; then
         echo "ERROR: could not mount mnt/casper/$LAYER.squashfs." >&2
         exit 1
      fi
      LOWERDIRS="${LOWERDIRS:+$LOWERDIRS:}$BUILD_DIR/layers/$LAYER.squashfs"
      PARENT_LAYER="${LAYER%.*}"
      [ "$PARENT_LAYER" = "$LAYER" ] && break
      LAYER="$PARENT_LAYER"
   done
   BASE_LAYER="$LAYER"
   echo "Merging layers (top first): $LOWERDIRS"
   if [ "$TOP_LAYER" = "$BASE_LAYER" ] ; then
      MERGED="layers/$TOP_LAYER.squashfs"
   else
      MERGED="layers/merged"
      if ! sudo mount -t overlay overlay -o ro,lowerdir="$LOWERDIRS" "$MERGED" ; then
         echo "ERROR: could not merge the layers of $TOP_LAYER." >&2
         exit 1
      fi
   fi
   sudo mkdir edit
   if ! sudo rsync -aHAX --numeric-ids "$MERGED"/ edit/ ; then
      echo "ERROR: could not copy the merged layers into edit/." >&2
      exit 1
   fi
   mountpoint -q layers/merged && sudo umount layers/merged
   for LAYER_DIR in layers/*.squashfs ; do
      sudo umount "$LAYER_DIR"
   done
   rm -rf layers
   # The layer files and their metadata are replaced by filesystem.*
   rm -f extract-cd/casper/"$BASE_LAYER".*
   touch extract-cd/casper/filesystem.manifest extract-cd/casper/filesystem.size
fi

echo
echo "Setting up network for chroot"
echo "======================================"
#If you need the network connection within chroot 
sudo cp /etc/resolv.conf edit/etc/
sudo cp /etc/hosts edit/etc/

# Do not bind-mount the host's /dev into edit/. A busy umount plus rm -rf
# once wiped the build host's device nodes. systemd-nspawn gives the build
# its own /dev; when the container exits, leftover processes are killed.
if ! command -v systemd-nspawn > /dev/null ; then
   echo "ERROR: systemd-nspawn is missing (package systemd-container)." >&2
   exit 1
fi

# The apt source of the live system for the disc (used by Calamares) has no
# /cdrom in the chroot and makes every apt-get update fail, park it meanwhile
CDROM_SOURCES=edit/etc/apt/sources.list.d/cdrom.sources
if [ -f "$CDROM_SOURCES" ] ; then
   sudo mv "$CDROM_SOURCES" "$BUILD_DIR"/cdrom.sources.parked
fi

echo
echo "Starting build in systemd-nspawn"
echo "======================================"

# Use the local working tree inside the container instead of cloning from
# GitHub; bootstrap.sh then skips the clone. Only tracked files and
# untracked files not covered by .gitignore are copied, so local data,
# secrets and the build directory never end up in the image.
#
# Do not put entry scripts under edit/tmp/: the live image's fstab mounts a
# tmpfs on /tmp inside systemd-nspawn and would hide them. Everything for
# the build lives under /usr/local/share/gisvm/.
GISVM_COPY="$BUILD_DIR"/edit/usr/local/share/gisvm
sudo mkdir -p "$GISVM_COPY"
git -C "$GIT_DIR" ls-files -z --cached --others --exclude-standard | \
   tar -C "$GIT_DIR" --null --ignore-failed-read -T - -cf - | \
   sudo tar -C "$GISVM_COPY" -xf -
if [ ! -f "$GISVM_COPY"/VERSION.txt ] ; then
   echo "ERROR: copying the source checkout into the chroot failed." >&2
   exit 1
fi
for FORBIDDEN in osgeolive_old local osgeolive-doc local.env build ; do
   if [ -e "$GISVM_COPY/$FORBIDDEN" ] ; then
      echo "ERROR: '$FORBIDDEN' must not be copied into the chroot, add it to .gitignore." >&2
      exit 1
   fi
done
LEAKED=`sudo find "$GISVM_COPY" \( -name '*.nmconnection' -o -name '*.pbf' \
   -o -name '*.iso' \) -print`
if [ -n "$LEAKED" ] ; then
   echo "ERROR: files not allowed in the chroot copy:" >&2
   echo "$LEAKED" >&2
   exit 1
fi

# FOSSGIS edition settings and the local-only inputs (local.env, optional
# inchroot.list, artwork, prepared data). setdown.sh deletes them again.
# local/ belongs to the main checkout, also when building from a worktree.
if [ -z "$FOSSGIS_LOCAL_DIR" ] ; then
   FOSSGIS_LOCAL_DIR="$(dirname "$(git -C "$GIT_DIR" rev-parse --path-format=absolute --git-common-dir)")/local"
fi
FOSSGIS_TMP="$GISVM_COPY/fossgis-local"
sudo mkdir -p "$FOSSGIS_TMP"
sudo cp "$GIT_DIR"/fossgis/edition.conf "$FOSSGIS_TMP"/
for ITEM in local.env inchroot.list artwork data ; do
   if [ -e "$FOSSGIS_LOCAL_DIR/$ITEM" ] ; then
      echo "FOSSGIS: using $FOSSGIS_LOCAL_DIR/$ITEM"
      sudo cp -a "$FOSSGIS_LOCAL_DIR/$ITEM" "$FOSSGIS_TMP"/
   fi
done
if [ -f "$FOSSGIS_TMP"/local.env ] ; then
   sudo chown root:root "$FOSSGIS_TMP"/local.env
   sudo chmod 600 "$FOSSGIS_TMP"/local.env
fi

# Local download cache, kept between builds: apt packages and the wget
# downloads of the install scripts (fossgis/tools/wget_cache.sh). Disable
# with FOSSGIS_CACHE="0" in local/local.env.
local_env_value() {
   [ -f "$FOSSGIS_LOCAL_DIR/local.env" ] && \
      sed -n -E "s/^[[:space:]]*$1=[\"']?([^\"']*)[\"']?[[:space:]]*$/\1/p" \
      "$FOSSGIS_LOCAL_DIR/local.env" | tail -n 1
}
FOSSGIS_CACHE=`local_env_value FOSSGIS_CACHE`
FOSSGIS_CACHE_DIR=`local_env_value FOSSGIS_CACHE_DIR`
if [ -z "$FOSSGIS_CACHE_DIR" ] ; then
   FOSSGIS_CACHE_DIR="$FOSSGIS_LOCAL_DIR/cache"
fi
WGET_WRAPPER_MARK="FOSSGIS wget cache wrapper"
NSPAWN_BINDS=""
if [ "$FOSSGIS_CACHE" != "0" ] ; then
   echo "FOSSGIS: download cache in $FOSSGIS_CACHE_DIR"
   for CACHE_SUBDIR in "$FOSSGIS_LOCAL_DIR" "$FOSSGIS_CACHE_DIR" \
         "$FOSSGIS_CACHE_DIR"/apt "$FOSSGIS_CACHE_DIR"/downloads ; do
      if [ ! -d "$CACHE_SUBDIR" ] ; then
         mkdir -p "$CACHE_SUBDIR"
         [ -n "$SUDO_USER" ] && chown "$SUDO_USER": "$CACHE_SUBDIR"
      fi
   done
   mkdir -p "$FOSSGIS_CACHE_DIR"/apt/partial
   FOSSGIS_CACHE_DIR=`cd "$FOSSGIS_CACHE_DIR" && pwd`
   sudo mkdir -p edit/var/cache/apt/archives edit/var/cache/fossgis-downloads
   # nspawn binds these for the container lifetime; no host-side bind mounts
   NSPAWN_BINDS="--bind=$FOSSGIS_CACHE_DIR/apt:/var/cache/apt/archives --bind=$FOSSGIS_CACHE_DIR/downloads:/var/cache/fossgis-downloads"
   sudo install -m 755 "$GIT_DIR"/fossgis/tools/wget_cache.sh edit/usr/local/bin/wget
fi

# Private /dev, own mounts; share the host network for apt. When the command
# exits, systemd-nspawn stops every process left in the container.
# shellcheck disable=SC2086
if ! sudo systemd-nspawn \
      --directory="$BUILD_DIR/edit" \
      --machine="fossgis-build-$$" \
      --register=no \
      --network-namespace-path=/proc/1/ns/net \
      --setenv=FOSSGIS_NSPAWN=1 \
      $NSPAWN_BINDS \
      /bin/sh /usr/local/share/gisvm/bin/inchroot.sh \
         "$ARCH" "$BUILD_MODE" "$GIT_BRANCH" "$GIT_USER"
then
   echo "ERROR: systemd-nspawn / inchroot.sh failed." >&2
   exit 1
fi

#exit
#OUT OF THE CONTAINER
echo
echo "Finished chroot part"
echo "======================================"
cd "$BUILD_DIR"
if [ -f "$BUILD_DIR"/cdrom.sources.parked ] ; then
   sudo mv "$BUILD_DIR"/cdrom.sources.parked "$CDROM_SOURCES"
fi

# Leftover binds (should not exist after nspawn); never pack or delete them
for MOUNTPOINT in edit/var/cache/apt/archives edit/var/cache/fossgis-downloads \
      edit/dev edit/dev/pts edit/proc edit/sys ; do
   if mountpoint -q "$MOUNTPOINT" ; then
      if ! sudo umount "$MOUNTPOINT" ; then
         echo "ERROR: $MOUNTPOINT is busy, detaching it lazily and aborting." >&2
         sudo umount -l "$MOUNTPOINT"
         exit 1
      fi
   fi
   if mountpoint -q "$MOUNTPOINT" ; then
      echo "ERROR: $MOUNTPOINT is still mounted, it would end up in the image." >&2
      exit 1
   fi
done
sudo rmdir edit/var/cache/fossgis-downloads 2>/dev/null
if grep -q "$WGET_WRAPPER_MARK" edit/usr/local/bin/wget 2>/dev/null ; then
   sudo rm -f edit/usr/local/bin/wget
fi
if [ -d "$FOSSGIS_CACHE_DIR" ] && [ -n "$SUDO_USER" ] ; then
   sudo chown -R "$SUDO_USER": "$FOSSGIS_CACHE_DIR"
fi
if [ -n "`mounts_below "$BUILD_DIR"/edit`" ] ; then
   echo "ERROR: still mounted below edit/, it would end up in the image:" >&2
   mounts_below "$BUILD_DIR"/edit >&2
   exit 1
fi
CHROOT_PROCESSES=`for PROC_DIR in /proc/[0-9]* ; do
   if [ "$(sudo readlink "$PROC_DIR"/root 2>/dev/null)" = "$BUILD_DIR/edit" ] ; then
      ps -o pid=,args= -p "${PROC_DIR#/proc/}"
   fi
done`
if [ -n "$CHROOT_PROCESSES" ] ; then
   echo "ERROR: processes still run in the chroot and would change the image" \
        "while it is packed. A partial build list that starts services must" \
        "end with setdown.sh:" >&2
   echo "$CHROOT_PROCESSES" >&2
   exit 1
fi

#Compress osgeolive build logs
#tar czf osgeo-live-${VERSION}-log.tar.gz -C edit/var/log osgeolive

echo
echo "Remastering the dvd..."
echo "======================================"
#Remaster the dvd

#Method 1 requires that dist-upgrade is run on both the host and chroot
#need to make sure modules.dep exists for the current kernel before next step
#sudo depmod
#sudo chroot edit depmod
#sudo chroot edit mkinitramfs -c lzma -o /initrd.lz

#Method 2 hardcode default kernel from Lubuntu
#need to repack the initrd.lz to pick up the change to casper.conf and kernel update
#Use mkinitramfs to extract the initrd from current chroot (with potential new kernel)
# sudo chroot edit mkinitramfs -c lz4 -o /initrd 6.8.0-41-generic
#or just copy the existing initrd if no change happened to the kernel version
# cp extract-cd/casper/initrd edit/initrd
#offset at second LZ4 tag because the new packaging of initrd has 3 parts now
# offset=$(binwalk ./edit/initrd -y lz4 | grep 'LZ4' | awk 'NR==2{ print $1; }')
# dd if=./edit/initrd bs=$offset skip=1 > initrd.lz4
# dd if=./edit/initrd bs=1 count=$offset > initrd.micro
# rm edit/initrd

# 24.04 unmkinitramfs wrote early/early2/main. 26.04 unmkinitramfs (3cpio)
# merges every archive into the target directory, so the early microcode
# would be recompressed with the rest. Split them with 3cpio -s instead.
mkdir lzfiles
cd lzfiles
if command -v 3cpio > /dev/null ; then
   if ! 3cpio -x -s archive -C . ../extract-cd/casper/initrd ; then
      echo "ERROR: could not unpack extract-cd/casper/initrd" >&2
      exit 1
   fi
   LAST=`ls -d archive[0-9]* 2>/dev/null | sort -V | tail -n 1`
   [ -n "$LAST" ] && mv "$LAST" main
   N=0
   for PART in `ls -d archive[0-9]* 2>/dev/null | sort -V` ; do
      N=`expr $N + 1`
      if [ "$N" -eq 1 ] ; then
         mv "$PART" early
      else
         mv "$PART" "early$N"
      fi
   done
else
   unmkinitramfs ../extract-cd/casper/initrd .
fi
if [ ! -f main/conf/initramfs.conf ] ; then
   echo "ERROR: could not unpack extract-cd/casper/initrd (no main/conf)" >&2
   exit 1
fi
# lz4 -dc ../initrd.lz4 | cpio -imvd --no-absolute-filenames

#Perhaps not needed since this also happens in chroot part.
cp "$GIT_DIR"/desktop-conf/casper/casper.conf main/etc/casper.conf
# The merged image has one filesystem.squashfs, casper must not look for
# the layer chain (LAYERFS_PATH=minimal.standard.live.squashfs)
rm -f main/conf/conf.d/default-layer.conf
#cp "$GIT_DIR"/desktop-conf/casper/27osgeo_groups scripts/casper-bottom/27osgeo_groups
#cat << EOF >> scripts/casper-bottom/ORDER
#/scripts/casper-bottom/27osgeo_groups
#[ -e /conf/param.conf ] && ./conf/param.conf
#EOF

mv main/scripts/casper-bottom/25adduser main/scripts/casper-bottom/25adduser.ORIG
cat main/scripts/casper-bottom/25adduser.ORIG \
    "$GIT_DIR"/desktop-conf/casper/27osgeo_groups \
  > main/scripts/casper-bottom/25adduser
rm main/scripts/casper-bottom/25adduser.ORIG
chmod a+x main/scripts/casper-bottom/25adduser


#Replace the user password
sed -i -e 's/U6aMy0wojraho/eLyJdzDtonrIc/g' main/scripts/casper-bottom/25adduser

#Change the graphics on the lubuntu-logo plymouth loader both on lzfiles
# and on edit folders
cp "$GIT_DIR"/desktop-conf/plymouth/lubuntu-logo/* \
    main/usr/share/plymouth/themes/lubuntu-logo/

cp "$GIT_DIR"/desktop-conf/plymouth/lubuntu-logo/* \
    ../edit/usr/share/plymouth/themes/lubuntu-logo/

# Copy the watermark file into spinner folders
cp "$GIT_DIR"/desktop-conf/plymouth/lubuntu-logo/watermark.png \
    main/usr/share/plymouth/themes/lubuntu-logo/spinner/

cp "$GIT_DIR"/desktop-conf/plymouth/lubuntu-logo/watermark.png \
    ../edit/usr/share/plymouth/themes/lubuntu-logo/spinner/

# Change the default spinner back to Ubuntu like
rm main/usr/share/plymouth/themes/lubuntu-logo/spinner/animation-*.png
cp main/usr/share/plymouth/themes/spinner/animation-*.png main/usr/share/plymouth/themes/lubuntu-logo/spinner/

rm ../edit/usr/share/plymouth/themes/lubuntu-logo/spinner/animation-*.png
cp ../edit/usr/share/plymouth/themes/spinner/animation-*.png ../edit/usr/share/plymouth/themes/lubuntu-logo/spinner/

rm main/usr/share/plymouth/themes/lubuntu-logo/spinner/throbber-*.png
cp main/usr/share/plymouth/themes/spinner/throbber-*.png main/usr/share/plymouth/themes/lubuntu-logo/spinner/

rm ../edit/usr/share/plymouth/themes/lubuntu-logo/spinner/throbber-*.png
cp ../edit/usr/share/plymouth/themes/spinner/throbber-*.png ../edit/usr/share/plymouth/themes/lubuntu-logo/spinner/

#Change the text on the lubuntu-text plymouth loader both on lzfiles
# and on edit folders
# "Lubuntu 24.04 LTS" up to 24.04, "Lubuntu 26.04" since 26.04
sed -i -e "s/^title=.ubuntu ${UBU_RELEASE}\( LTS\)\?$/title=OSGeoLive ${VERSION_MODE}/" \
    main/usr/share/plymouth/themes/lubuntu-text/lubuntu-text.plymouth

sed -i -e "s/^title=.ubuntu ${UBU_RELEASE}\( LTS\)\?$/title=OSGeoLive ${VERSION_MODE}/" \
    ../edit/usr/share/plymouth/themes/lubuntu-text/lubuntu-text.plymouth

#Optional change it in the .disk/info too
sed -i -e "s/.ubuntu ${ISO_RELEASE} LTS \"[^\"]*\"/OSGeoLive ${VERSION_MODE}/" \
    ../extract-cd/.disk/info

# rm ../initrd.lz4
# find . | cpio --quiet --dereference -o -H newc | \
#    lz4 -9 -l > ../initrd.lz4

# The initrd is a row of uncompressed early archives (microcode, firmware;
# early2 held the kernel dir up to 24.04) followed by the compressed main
# archive, compressed as set in its own initramfs.conf
: > myinitrd
for PART in early early2 early3 early4 early5 early6 ; do
   if [ -d "$PART" ] ; then
      (cd "$PART" && find . -print0 | cpio --null --create --format=newc) >> myinitrd
   fi
done
case `sed -n 's/^COMPRESS=//p' main/conf/initramfs.conf` in
   zstd) INITRD_COMPRESSOR="zstd -q -10 -T0" ;;
   *) INITRD_COMPRESSOR="lz4 -9 -l" ;;
esac
echo "initrd main archive: $INITRD_COMPRESSOR"
(cd main && find . | cpio --create --format=newc | $INITRD_COMPRESSOR) >> myinitrd

# cat initrd.micro initrd.lz4 > initrd
# rm initrd.micro initrd.lz4
# mv initrd extract-cd/casper/initrd
mv myinitrd ../extract-cd/casper/initrd
cd ..

echo
echo "Editing boot options and graphics..."
echo "======================================"

# sed -i -e "s/Lubuntu/OSGeoLive/g" \
#        -e "s/initrd quiet splash/initrd fsck.mode=skip quiet splash/g" \
#     extract-cd/isolinux/txt.cfg

# cp "$GIT_DIR/desktop-conf/isolinux/splash.png" extract-cd/isolinux/splash.png
# cp "$GIT_DIR/desktop-conf/isolinux/splash.pcx" extract-cd/isolinux/splash.pcx

if [ "$LAYERED_IMAGE" = "yes" ] ; then
   echo
   echo "Installer settings for the merged image..."
   echo "======================================"
   # Calamares unpacks filesystem.squashfs instead of the stacked layers,
   # runs initramfs-tools (from the live layer) instead of dracut and
   # removes the live-only packages afterwards
   CALAMARES_DIR=edit/etc/calamares
   if [ ! -f "$CALAMARES_DIR"/settings.conf ] ; then
      echo "ERROR: $CALAMARES_DIR/settings.conf not found." >&2
      exit 1
   fi
   sudo cp "$GIT_DIR"/desktop-conf/calamares/unpackfs.conf \
      "$GIT_DIR"/desktop-conf/calamares/packages.conf \
      "$GIT_DIR"/desktop-conf/calamares/initramfs.conf "$CALAMARES_DIR"/modules/
   sudo rm -f "$CALAMARES_DIR"/modules/stacked_squashfs.flag
   sudo sed -i -e 's/^\([[:space:]]*\)- dracutlukscfg$/\1- initramfscfg/' \
      -e 's/^\([[:space:]]*\)- dracut$/\1- initramfs/' "$CALAMARES_DIR"/settings.conf
   if grep -q -E '^[[:space:]]*- dracut' "$CALAMARES_DIR"/settings.conf || \
      ! grep -q -E '^[[:space:]]*- initramfs$' "$CALAMARES_DIR"/settings.conf ; then
      echo "ERROR: could not switch Calamares from dracut to initramfs." >&2
      exit 1
   fi
fi

echo
echo "Regenerating manifest..."
echo "======================================"

#Regenerate manifest 
chmod +w extract-cd/casper/filesystem.manifest
sudo chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > \
   extract-cd/casper/filesystem.manifest
sudo cp extract-cd/casper/filesystem.manifest \
   extract-cd/casper/filesystem.manifest-desktop
# sudo sed -i '/ubiquity/d' \
#    extract-cd/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' \
   extract-cd/casper/filesystem.manifest-desktop

echo
echo "Compressing filesystem..."
echo "======================================"
#Compress filesystem
sudo rm -f extract-cd/casper/filesystem.squashfs
# -one-file-system: never follow a leftover bind mount (especially edit/dev)
if ! sudo mksquashfs edit extract-cd/casper/filesystem.squashfs -one-file-system ; then
   echo "ERROR: mksquashfs failed, edit/ is kept." >&2
   exit 1
fi
# sudo mksquashfs edit extract-cd/casper/filesystem.squashfs -no-progress
echo "squashfs size:"
ls -l extract-cd/casper/filesystem.squashfs

echo
echo "Calculating new filesystem size..."
echo "======================================"
#Update the filesystem.size file, which is needed by the installer:
# TODO: get it to run as sudo no sudo su
chmod +w extract-cd/casper/filesystem.size
printf $(sudo du -sx --block-size=1 edit | cut -f1) > \
   extract-cd/casper/filesystem.size
chmod -w extract-cd/casper/filesystem.size

#this is now compressed in squashfs so we delete to save VM disk space
cd "$BUILD_DIR"
remove_chroot "$BUILD_DIR"/edit

#Set an image name in extract-cd/README.diskdefines
# cp "$GIT_DIR/desktop-conf/casper/README.diskdefines" extract-cd/README.diskdefines

echo
echo "Calculating new md5 sums..."
echo "======================================"
#Remove old md5sum.txt and calculate new md5 sums
cd extract-cd
sudo rm md5sum.txt
find -type f -print0 | sudo xargs -0 md5sum | \
   grep -v boot.catalog | sudo tee md5sum.txt

echo
echo "Creating iso..."
echo "======================================"
#Create the ISO image
#isohybrid used only in 64bit architecture
if [ "$ARCH" = "amd64" ] ; then
   # sudo mkisofs -D -r -V "$IMAGE_NAME" -cache-inodes -J -l -quiet -b \
   #    boot/grub/i386-pc/eltorito.img -c boot.catalog -no-emul-boot \
   #    -boot-load-size 4 -boot-info-table \
   #    -eltorito-alt-boot -e EFI/boot/grubx64.efi -no-emul-boot \
   #    -o ../"$ISO_NAME.iso" .
   # sudo xorriso -as mkisofs -r -V "$IMAGE_NAME" -J -joliet-long -l \
   #    -iso-level 3 -partition_offset 16 --grub2-mbr ../"$MBR" --mbr-force-bootable \
   #    -append_partition 2 0xEF ../"$EFI" -appended_part_as_gpt \
   #    -c boot.catalog -b boot/grub/i386-pc/eltorito.img -no-emul-boot \
   #    -boot-load-size 4 -boot-info-table --grub2-boot-info -eltorito-alt-boot \
   #    -e '--interval:appended_partition_2:all::' -no-emul-boot \
   #    -o ../"$ISO_NAME.iso" .
    # -iso-level 3: filesystem.squashfs is larger than 4 GiB
    sudo xorriso -as mkisofs -r \
      -iso-level 3 \
      -V "$IMAGE_NAME" \
      --grub2-mbr ../"$MBR" \
      -partition_offset 16 \
      --mbr-force-bootable \
      -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b ../"$EFI" \
      -appended_part_as_gpt \
      -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
      -c boot.catalog \
      -b boot/grub/i386-pc/eltorito.img \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      --grub2-boot-info \
      -eltorito-alt-boot \
      -e '--interval:appended_partition_2:::' \
      -no-emul-boot \
      -o ../"$ISO_NAME.iso" .
   # sudo isohybrid -u ../"$ISO_NAME.iso"
else
   sudo mkisofs -D -r -V "$IMAGE_NAME" -cache-inodes -J -l -quiet -b \
      boot/grub/i386-pc/eltorito.img -c boot.catalog -no-emul-boot \
      -boot-load-size 4 -boot-info-table -o ../"$ISO_NAME.iso" .
   # sudo isohybrid ../"$ISO_NAME.iso"
fi
ISO_RC=$?
if [ "$ISO_RC" -ne 0 ] || [ ! -s ../"$ISO_NAME.iso" ] ; then
   echo "ERROR: creating $ISO_NAME.iso failed, extract-cd/ is kept for inspection." >&2
   sudo rm -f ../"$ISO_NAME.iso"
   cd "$BUILD_DIR"
   sudo umount mnt
   exit 1
fi

echo
echo "Cleaning up..."
echo "======================================"
#Clear things up and prepare for next build
cd "$BUILD_DIR"
sudo rm -rf extract-cd
sudo umount mnt
sudo rm -rf mnt
sudo rm -rf lzfiles
sudo rm *.partition

echo
echo "==============================================================="
echo "Finished building $ISO_NAME"
echo "==============================================================="
