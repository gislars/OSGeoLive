#!/bin/sh
#############################################################################
#
# Purpose: Creating OSGeoLive as an Ubuntu customization. In chroot part
#     https://help.ubuntu.com/community/LiveCDCustomization
# Author:  Stefan Hansen <shansen@lisasoft.com>
#	         Alex Mandel <tech_dev@wildintellect.com>
#	         Angelos Tzotsos <tzotsos@gmail.com>
#
#############################################################################
# Copyright (c) 2010-2026 Open Source Geospatial Foundation (OSGeo) and others.
# Copyright (c) 2009 LISAsoft
#
# Licensed under the GNU LGPL version >= 2.1.
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

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    echo "Wrong number of arguments"
    echo "Usage: inchroot.sh ARCH(i386 or amd64) MODE(release or nightly) [git_branch (default=master)] [github_username (default=gislars) or git clone url]"
    exit 1
fi

if [ "$1" != "i386" ] && [ "$1" != "amd64" ] ; then
    echo "Did not specify build architecture, try using i386 or amd64 as an argument"
    echo "Usage: inchroot.sh ARCH(i386 or amd64) MODE(release or nightly) [git_branch (default=master)] [github_username (default=gislars) or git clone url]"
    exit 1
fi
ARCH="$1"

if [ "$2" != "release" ] && [ "$2" != "nightly" ] ; then
    echo "Did not specify build mode, try using release or nightly as an argument"
    echo "Usage: inchroot.sh ARCH(i386 or amd64) MODE(release or nightly) [git_branch (default=master)] [github_username (default=gislars) or git clone url]"
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

run_installer()
{
  SCRIPT=$1
  echo "===================================================================="
  echo "Starting: $SCRIPT"
  echo "===================================================================="
  sh "$SCRIPT"
}

# systemd-nspawn already mounts /proc, /sys and a private /dev; a plain
# chroot (legacy) still needs them. FOSSGIS_NSPAWN=1 is set by build_chroot.sh.
if [ "${FOSSGIS_NSPAWN:-}" != "1" ] ; then
   mount -t proc none /proc
   mount -t sysfs none /sys
   mount -t devpts none /dev/pts
fi

# To avoid locale issues and in order to import GPG keys
export HOME=/roots
export LC_ALL=C

# In 9.10, before installing or upgrading packages you need to run
# TODO: Check/ask if this needs to be done in 12.04
dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

# To view installed packages by size
# dpkg-query -W --showformat='${Installed-Size}\t${Package}\n' | sort -nr | less
# When you want to remove packages remember to use purge
# aptitude purge package-name

# Execute the osgeolive build
# Adding "user" to help the build process
adduser user --disabled-password --gecos user

# Change ID under 999 so that iso boot does not fail
# usermod -u 500 user
# TODO: Set the password for "user"
mkdir -p /home/user/Desktop
chown user:user /home/user/Desktop

# Fixing some IPv6 problems for the build server
mv /etc/gai.conf /etc/gai.conf.orig
cat << EOF > /etc/gai.conf
precedence ::ffff:0:0/96  100
EOF

USER_NAME="user"
export USER_NAME
# SUDO_USER leaks in from the host's "sudo chroot" and must not be used here
unset SUDO_USER

cd /usr/local/share/gisvm/bin
chmod a+x bootstrap.sh
./bootstrap.sh "$GIT_BRANCH" "$GIT_USER"

# FOSSGIS edition settings and local.env, exported for all install scripts.
# Not under /tmp: systemd-nspawn mounts a tmpfs there from the live fstab.
FOSSGIS_DIR=/usr/local/share/gisvm/fossgis-local
. /usr/local/share/gisvm/fossgis/load_edition.sh
echo "Edition: $EDITION_NAME ($MAP_CITY)"

#######################################################
# Replacement for main.sh
#######################################################

# Partial build: local/inchroot.list replaces the script list below. One
# script per line with its arguments, e.g. 'setup.sh "$BUILD_MODE"';
# empty lines and lines starting with # are ignored.
if [ -f "$FOSSGIS_DIR/inchroot.list" ] ; then
echo "Partial build from $FOSSGIS_DIR/inchroot.list"
# Do not use a pipe to while: failures must abort the build (set -e is
# ignored in a pipeline's non-last commands on dash).
PARTIAL_LIST=`mktemp`
grep -v -E '^[[:space:]]*(#|$)' "$FOSSGIS_DIR/inchroot.list" > "$PARTIAL_LIST"
while IFS= read -r LINE ; do
    echo "===================================================================="
    echo "Partial build: $LINE"
    echo "===================================================================="
    # shellcheck disable=SC2086
    eval "./$LINE" || {
        echo "ERROR: partial build step failed: $LINE" >&2
        rm -f "$PARTIAL_LIST"
        exit 1
    }
done < "$PARTIAL_LIST"
rm -f "$PARTIAL_LIST"
else

# Full build: abort on the first failed step (same as partial builds above).
# Without this, install scripts without set -e still print Finished and the
# ISO is marked exit=0 (build126: missing packages, OTB Permission denied).
fossgis_run() {
    "$@" || {
        echo "ERROR: install step failed: $*" >&2
        exit 1
    }
}

fossgis_run ./setup.sh "$BUILD_MODE"
fossgis_run ./install_locale.sh
fossgis_run ./install_wifi.sh

### Base installers
fossgis_run ./base_c.sh
fossgis_run ./base_python.sh
fossgis_run ./base_java.sh
# ./base_language.sh # install_vm_only

### Service installers
fossgis_run ./service_apache2.sh
fossgis_run ./base_php.sh
fossgis_run ./service_tomcat.sh
fossgis_run ./service_postgresql.sh
# ./service_mysql.sh

### Project installers
## C stack
fossgis_run ./install_postgis.sh
fossgis_run ./install_spatialite.sh
fossgis_run ./install_osm.sh
fossgis_run ./load_postgis.sh
fossgis_run ./install_pgadmin.sh
fossgis_run ./install_pgrouting.sh
fossgis_run ./install_ossim.sh
fossgis_run ./install_mapserver.sh
fossgis_run ./install_mapcache.sh
fossgis_run ./install_tinyows.sh
# ./install_gmt.sh # install_vm_only
fossgis_run ./install_mapnik.sh
fossgis_run ./install_otb.sh
fossgis_run ./install_saga.sh
fossgis_run ./install_grass.sh
fossgis_run ./install_qgis.sh
fossgis_run ./install_qgis_server.sh
fossgis_run ./check_gis_stack.sh
# ./install_qfield.sh # install_vm_only
# ./install_zoo-project.sh "$ARCH" # install_vm_only
fossgis_run ./install_marble.sh
fossgis_run ./install_opencpn.sh
fossgis_run ./install_xygrib.sh
fossgis_run ./install_PDAL.sh

## Python stack
fossgis_run ./install_mapproxy.sh
fossgis_run ./install_owslib.sh
fossgis_run ./install_pycsw.sh
fossgis_run ./install_pywps.sh
fossgis_run ./install_pygeoapi.sh
# ./install_eoxserver.sh # install_vm_only
# ./install_istsos.sh  # no Resolute deb; PyPI only yanked 3.0.0b1 (build138)
# ./install_actinia.sh # install_vm_only
fossgis_run ./install_datacube.sh

## R stack
fossgis_run ./install_R.sh

## Jupyter
fossgis_run ./install_jupyter.sh

## Java stack
fossgis_run ./install_geoserver.sh
# ./install_geonetwork.sh # install_vm_only
fossgis_run ./install_deegree.sh
fossgis_run ./install_openjump.sh
# ./install_gvsig.sh "$ARCH" # install_vm_only
fossgis_run ./install_gpsprune.sh

## Node.js, Docker, VS Code (FOSSGIS workshop tools)
fossgis_run ./install_node.sh
fossgis_run ./install_docker.sh
fossgis_run ./install_vscode.sh

## Java + default tomcat
# ./install_52nSOS.sh # install_vm_only

## PHP stack
fossgis_run ./install_mapbender.sh
fossgis_run ./install_geomoose.sh

## more Python (GeoServer rdeps)
# ./install_geonode.sh # install_vm_only

## Rust
# ./install_trex.sh # install_vm_only

## Javascript et al
fossgis_run ./install_openlayers.sh
fossgis_run ./install_leaflet.sh
fossgis_run ./install_cesium.sh
fossgis_run ./install_geoext.sh
# ./install_rasdaman.sh # install_vm_only
fossgis_run ./install_geostyler.sh
# ./install_re3gistry.sh # install_vm_only
# ./install_etf.sh # install_vm_only

## Docs, Data and extras
fossgis_run ./load_gisdata.sh
fossgis_run ./install_docs.sh "$BUILD_MODE"
# ./install_edutools.sh

## Desktop and Housekeeping
fossgis_run ./install_desktop.sh
fossgis_run ./install_icons_and_menus.sh
fossgis_run ./setdown.sh

fi
rm -rf "$FOSSGIS_DIR"


#######################################################
# End of main.sh
#######################################################

# Remove doc folder to save space
# rm -rf /usr/local/share/gisvm/doc

# Save space on ISO by removing the .git dir
NEAR_RC=1
if [ "$NEAR_RC" -eq 1 ] ; then
    rm -rf /usr/local/share/gisvm/.git
fi

# user shouldn't own outside of /home, but a group can
chown -R root:staff /usr/local/share/gisvm
chmod -R g+w /usr/local/share/gisvm

# Update the file search index
updatedb

# Experimental dist variant, comment out and swap to backup below
# Do we need to change the user to ubuntu in all scripts for this method?
# -- No, set user in casper.conf
tar -zcf /tmp/user_home.tar.gz -C /home/user .
tar -zxf /tmp/user_home.tar.gz -C /etc/skel .
rm /tmp/user_home.tar.gz
cp -a /home/user/*  /etc/skel
chown -hR root:root /etc/skel

# TODO: Should we remove the "user" after the installation?
# By keeping this user, /home/user exists and installation fails if someone uses the same username.
# killall -u user
# userdel -r user
deluser --remove-home user

# Copy casper.conf with default username and hostname
# FIXME: User is still "xubuntu" in live session... perhaps because user is already created?
cp /usr/local/share/gisvm/desktop-conf/casper/casper.conf /etc/casper.conf

# After the build
# Check for users above 999
awk -F: '$3 > 999' /etc/passwd

#### Cleanup ####

# FOSSGIS: a partial build skips setdown.sh, detach the local caches here so
# that apt-get clean does not empty them (see bin/build_chroot.sh)
for CACHE_MOUNT in /var/cache/apt/archives /var/cache/fossgis-downloads ; do
   if mountpoint -q "$CACHE_MOUNT" ; then
      umount "$CACHE_MOUNT" || umount -l "$CACHE_MOUNT"
   fi
done
rmdir /var/cache/fossgis-downloads 2>/dev/null
if grep -q "FOSSGIS wget cache wrapper" /usr/local/bin/wget 2>/dev/null ; then
   rm -f /usr/local/bin/wget
fi

# Be sure to remove any temporary files which are no longer needed, as space on a CD is limited
if mountpoint -q /var/cache/apt/archives ; then
   echo "ERROR: apt cache still mounted, skipping apt-get clean" >&2
else
   apt-get clean
fi

# Delete temporary files
rm -rf /tmp/* ~/.bash_history

# Delete hosts file
rm /etc/hosts

# Nameserver settings
rm /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# If you installed software, be sure to run 
rm -f /var/lib/dbus/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl

# Now umount (unmount) special filesystems and exit chroot
if [ "${FOSSGIS_NSPAWN:-}" != "1" ] ; then
   umount /proc || umount -lf /proc
   umount /sys
   umount /dev/pts
fi
