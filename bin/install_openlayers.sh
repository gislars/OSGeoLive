#!/bin/sh
#############################################################################
#
# Purpose: This script installs OpenLayers (current major) and OpenLayers
#          2.13.1 for legacy demos on OSGeoLive.
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
#############################################################################

# Running:
# =======
# sudo service apache2 start
# Then open a web browser and go to http://localhost/openlayers/

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"
TMP_DIR="/tmp/build_openlayers"

OL2_VERSION="2.13.1"
OL2_DIR=/var/www/html/ol2

# From OpenLayers 10 the release archives are *-site.zip and *-package.zip.
OPENLAYERS_VERSION="10.11.0"
OPENLAYERS_DIR=/var/www/html/openlayers

#
# Install OpenLayers 2
#
echo "\nCreating temporary directory $TMP_DIR..."
mkdir -p "$TMP_DIR"
echo "\nCreating OpenLayers2 directory $OL2_DIR..."
mkdir -p "$OL2_DIR"
echo "\nCreating OpenLayers directory $OPENLAYERS_DIR..."
mkdir -p "$OPENLAYERS_DIR"

echo "\nDownloading OpenLayers2..."
cd "$TMP_DIR"
if [ -f "OpenLayers-$OL2_VERSION.tar.gz" ]
then
   echo "OpenLayers-$OL2_VERSION.tar.gz has already been downloaded."
else
   wget -c --progress=dot:mega \
      "http://github.com/openlayers/ol2/releases/download/release-$OL2_VERSION/OpenLayers-$OL2_VERSION.tar.gz"
fi

echo "\nInstalling OpenLayers2..."
tar zxf "OpenLayers-$OL2_VERSION.tar.gz"
cd "OpenLayers-$OL2_VERSION"
mv OpenLayers.js "$OL2_DIR"/
mv img "$OL2_DIR"/
mv theme "$OL2_DIR"/
chmod -R uga+r "$OL2_DIR"

echo "\nCleaning up..."
cd "$TMP_DIR"
rm -rf "OpenLayers-$OL2_VERSION"
rm "OpenLayers-$OL2_VERSION.tar.gz"

#
# Install OpenLayers (site docs/examples + package dist)
#
echo "\nInstalling OpenLayers $OPENLAYERS_VERSION..."

cd "$TMP_DIR"

OPENLAYERS_ARCHIVE_SITE="v${OPENLAYERS_VERSION}-site.zip"
if [ -f "$OPENLAYERS_ARCHIVE_SITE" ]
then
   echo "OpenLayers $OPENLAYERS_VERSION site archive already downloaded."
else
   wget -c --progress=dot:mega \
      "https://github.com/openlayers/openlayers/releases/download/v${OPENLAYERS_VERSION}/${OPENLAYERS_ARCHIVE_SITE}"
fi

OPENLAYERS_ARCHIVE_PACKAGE="v${OPENLAYERS_VERSION}-package.zip"
if [ -f "$OPENLAYERS_ARCHIVE_PACKAGE" ]
then
   echo "OpenLayers $OPENLAYERS_VERSION package archive already downloaded."
else
   wget -c --progress=dot:mega \
      "https://github.com/openlayers/openlayers/releases/download/v${OPENLAYERS_VERSION}/${OPENLAYERS_ARCHIVE_PACKAGE}"
fi

echo "\nUnzipping archives..."
rm -rf "$TMP_DIR/ol_site" "$TMP_DIR/ol_package"
mkdir -p "$TMP_DIR/ol_site" "$TMP_DIR/ol_package"
unzip -qo "$OPENLAYERS_ARCHIVE_SITE" -d "$TMP_DIR/ol_site"
unzip -qo "$OPENLAYERS_ARCHIVE_PACKAGE" -d "$TMP_DIR/ol_package"

echo "\nCopying files to $OPENLAYERS_DIR"
rm -rf "$OPENLAYERS_DIR"
mkdir -p "$OPENLAYERS_DIR"
rsync -a "$TMP_DIR/ol_site/" "$OPENLAYERS_DIR/"
mkdir -p "$OPENLAYERS_DIR/dist"
# Full browser build from the package archive
if [ -d "$TMP_DIR/ol_package/dist" ] ; then
   rsync -a "$TMP_DIR/ol_package/dist/" "$OPENLAYERS_DIR/dist/"
fi
if [ -f "$TMP_DIR/ol_package/ol.css" ] ; then
   cp -f "$TMP_DIR/ol_package/ol.css" "$OPENLAYERS_DIR/dist/"
fi
echo "Copying done"

#
# Generate index page (docs live under en/latest/ since OL 10 site zips)
#
cd "$OPENLAYERS_DIR"

APIDOC="en/latest/apidoc"
EXAMPLES="en/latest/examples"
[ -d "$APIDOC" ] || APIDOC="apidoc"
[ -d "$EXAMPLES" ] || EXAMPLES="examples"

echo "\nGenerating index file..."
cat << EOF > "index.html"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>OpenLayers $OPENLAYERS_VERSION</title>
</head>
<body>
<h1>OpenLayers $OPENLAYERS_VERSION</h1>
<p>Welcome to OpenLayers index page:</p>
<ul>
<li><a href="$APIDOC/">API Docs</a>: explore the project documentation</li>
<li><a href="$EXAMPLES/">Examples</a>: see the project in action</li>
<li><a href="https://openlayers.org/">OpenLayers.org website</a></li>
</ul>
</body>
</html>
EOF
echo "Index file generation done"

#
# Launch script and icon
#
echo "\nGenerating launcher..."
if [ -f "$OPENLAYERS_DIR/theme/img/logo-light.svg" ] ; then
   cp "$OPENLAYERS_DIR/theme/img/logo-light.svg" /usr/share/pixmaps/openlayers.svg
   OL_ICON=openlayers
elif [ -f "$OPENLAYERS_DIR/$APIDOC/logo-70x70.png" ] ; then
   cp "$OPENLAYERS_DIR/$APIDOC/logo-70x70.png" /usr/share/pixmaps/openlayers.png
   OL_ICON=openlayers
else
   OL_ICON=applications-internet
fi

if [ ! -e /usr/share/applications/openlayers.desktop ] ; then
   cat << EOF > /usr/share/applications/openlayers.desktop
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=OpenLayers
Comment=Sample constructions
Categories=Application;Internet;
Exec=firefox http://localhost/openlayers/ http://localhost/osgeolive/en/quickstart/openlayers_quickstart.html
Icon=$OL_ICON
Terminal=false
StartupNotify=false
EOF
fi
cp /usr/share/applications/openlayers.desktop "$USER_HOME/Desktop/"
chown "$USER_NAME:$USER_NAME" "$USER_HOME/Desktop/openlayers.desktop"

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
