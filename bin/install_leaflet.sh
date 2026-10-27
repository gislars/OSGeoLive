#!/bin/sh
# Copyright (c) 2013-2026 The Open Source Geospatial Foundation and others.
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

# About:
# =====
# This script will install leaflet

./diskspace_probe.sh "`basename $0`" begin
####

if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

MARKERCLUSTER_VERSION="1.5.3"
MARKERCLUSTER_URL="https://github.com/Leaflet/Leaflet.markercluster/archive/refs/tags/v${MARKERCLUSTER_VERSION}.tar.gz"
JS_ROOT="/usr/share/javascript"
MC_DEST="$JS_ROOT/leaflet-markercluster"

apt-get update
apt-get --assume-yes install libjs-leaflet
apt-get --assume-yes install libjs-leaflet-geometryutil

# libjs-leaflet-markercluster is not in Ubuntu 26.04; install from upstream.
TMP_MC=`mktemp -d`
wget -c --progress=dot:mega -O "$TMP_MC/markercluster.tgz" "$MARKERCLUSTER_URL"
tar -xzf "$TMP_MC/markercluster.tgz" -C "$TMP_MC"
rm -rf "$MC_DEST"
mkdir -p "$MC_DEST"
cp -a "$TMP_MC/Leaflet.markercluster-${MARKERCLUSTER_VERSION}/dist/"* "$MC_DEST/"
rm -rf "$TMP_MC"

ln -s /usr/share/javascript/leaflet/ /var/www/html/leaflet
ln -sfn "$MC_DEST" /var/www/html/leaflet-markercluster

# map_location.js for leaflet-demo from FOSSGIS edition.conf (exported by load_edition.sh)
MAP_LAT="${MAP_LAT:--36.853567}"
MAP_LON="${MAP_LON:-174.766353}"
MAP_ZOOM="${MAP_ZOOM:-16}"
MAP_LEAFLET_POLYGON="${MAP_LEAFLET_POLYGON:-}"
POLY_JS=""
for p in $MAP_LEAFLET_POLYGON; do
   [ -n "$POLY_JS" ] && POLY_JS="$POLY_JS,"
   POLY_JS="${POLY_JS}[$p]"
done
{
   echo "// from fossgis edition settings"
   echo "var MAP_LAT = $MAP_LAT;"
   echo "var MAP_LON = $MAP_LON;"
   echo "var MAP_ZOOM = $MAP_ZOOM;"
   echo "var MAP_LEAFLET_POLYGON = [$POLY_JS];"
} > /var/www/html/map_location.js

#add demo file
cp -f ../app-conf/leaflet/leaflet-demo.html /var/www/html/


### install desktop icons ##
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LEAFLET_ICON_SRC="${SCRIPT_DIR}/../app-conf/leaflet/leafletjs_logo.png"
echo "Installing Leaflet icon"
if [ -f "$LEAFLET_ICON_SRC" ] ; then
   cp -f "$LEAFLET_ICON_SRC" /usr/share/icons/leafletjs_logo.png
else
   echo "Note: Leaflet icon missing at $LEAFLET_ICON_SRC"
fi

## start icon
cat << EOF > /usr/share/applications/leaflet.desktop
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=Leaflet
Comment=LeafletJS Examples
Categories=Application;Internet;
Exec=firefox http://localhost/osgeolive/en/quickstart/leaflet_quickstart.html http://localhost/leaflet-demo.html
Icon=/usr/share/icons/leafletjs_logo.png
Terminal=false
EOF

cp -a /usr/share/applications/leaflet.desktop "$USER_HOME/Desktop/"
chown -R "$USER_NAME":"$USER_NAME" "$USER_HOME/Desktop/leaflet.desktop"

####
./diskspace_probe.sh "`basename $0`" end
