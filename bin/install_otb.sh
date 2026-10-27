#!/bin/sh
#############################################################################
#
# Purpose: Install Orfeo Toolbox from the official Linux binary tarball
#          (Ubuntu packages libotb / monteverdi are gone in 26.04).
#
#############################################################################
# Copyright (c) 2009-2026 The Open Source Geospatial Foundation and others.
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
#
#############################################################################

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

OTB_VERSION="9.1.1"
OTB_TARBALL="OTB-${OTB_VERSION}-Linux.tar.gz"
OTB_URL="https://www.orfeo-toolbox.org/packages/${OTB_TARBALL}"
OTB_ROOT="/usr/local/lib/OTB-${OTB_VERSION}"
OTB_DATA=/usr/local/share/otb
TMP_DIR=/tmp/build_otb

mkdir -p "$TMP_DIR" "$OTB_DATA"
cd "$TMP_DIR"

if [ ! -f "$TMP_DIR/$OTB_TARBALL" ] ; then
   wget -c --progress=dot:mega -O "$TMP_DIR/$OTB_TARBALL" "$OTB_URL"
fi

# Official Linux tarball has no top-level directory (bin/, lib/, otbenv.profile).
rm -rf "$OTB_ROOT"
mkdir -p "$OTB_ROOT"
tar -xzf "$TMP_DIR/$OTB_TARBALL" -C "$OTB_ROOT"
if [ ! -f "$OTB_ROOT/otbenv.profile" ] ; then
   echo "ERROR: OTB tarball missing otbenv.profile under $OTB_ROOT" >&2
   ls -la "$OTB_ROOT" >&2 || true
   exit 1
fi

# Environment for shells and launchers
cat << EOF > /etc/profile.d/otb.sh
# Orfeo Toolbox ${OTB_VERSION} (official Linux binary)
if [ -f "$OTB_ROOT/otbenv.profile" ] ; then
   . "$OTB_ROOT/otbenv.profile"
fi
EOF
chmod 644 /etc/profile.d/otb.sh

# Convenience wrappers on PATH
mkdir -p /usr/local/bin
for APP in monteverdi mapla ; do
   if [ -x "$OTB_ROOT/bin/$APP" ] ; then
      cat << EOF > "/usr/local/bin/$APP"
#!/bin/sh
. /etc/profile.d/otb.sh
exec "$OTB_ROOT/bin/$APP" "\$@"
EOF
      chmod 755 "/usr/local/bin/$APP"
   fi
done

# Desktop launchers
if [ -x /usr/local/bin/monteverdi ] ; then
   cat << EOF > /usr/share/applications/monteverdi.desktop
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=Monteverdi
Comment=Orfeo Toolbox viewer
Categories=Application;Geography;Geoscience;Education;
Exec=monteverdi
Icon=multimedia-photo-viewer
Terminal=false
EOF
   cp /usr/share/applications/monteverdi.desktop "$USER_HOME/Desktop/"
   chown "$USER_NAME:$USER_NAME" "$USER_HOME/Desktop/monteverdi.desktop"
fi

if [ -x /usr/local/bin/mapla ] ; then
   cat << EOF > /usr/share/applications/otb-mapla.desktop
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=OTB Launcher
Comment=OTB Mapla
Categories=Application;Geography;Geoscience;Education;
Exec=mapla
Icon=multimedia-photo-viewer
Terminal=false
EOF
   cp /usr/share/applications/otb-mapla.desktop "$USER_HOME/Desktop/"
   chown "$USER_NAME:$USER_NAME" "$USER_HOME/Desktop/otb-mapla.desktop"
fi

rm -rf "$TMP_DIR"

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
