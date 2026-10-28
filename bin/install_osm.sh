#!/bin/sh
#############################################################################
#
# Purpose: This script will install some OpenStreetMap utilities
#
#############################################################################
# Copyright (c) 2009-2024 The Open Source Geospatial Foundation and others.
# Licensed under the GNU LGPL.
#
# This script is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 2.1 of the License,
# or any later version.  This library is distributed in the hope that
# it will be useful, but WITHOUT ANY WARRANTY, without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details, either
# in the "LICENSE.LGPL.txt" file distributed with this software or at
# web page "http://www.fsf.org/licenses/lgpl.html".

# Running:
# =======
# sudo ./install_osm.sh

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

TMP_DIR=/tmp/build_osm


if [ ! -d "$TMP_DIR" ] ; then
   mkdir "$TMP_DIR"
fi
cd "$TMP_DIR"

##----------------------------
mkdir /usr/local/share/osm

##----------------------------------------------------------
apt-get install --assume-yes osm2pgsql osmium-tool python3-osmapi
apt-get install --assume-yes gpsd gpsd-clients

# nik4 left Debian; install into the shared OSGeoLive venv.
. "$BUILD_DIR/tools/osgeolive_venv.sh"
NIK4_VERSION="1.8.0"
if ! osgeolive_venv_pip "nik4==$NIK4_VERSION" ; then
   echo "ERROR: pip install nik4==$NIK4_VERSION failed" >&2
   exit 1
fi
ln -sfn "`osgeolive_venv_bin nik4`" /usr/local/bin/nik4

## JOSM -- OpenStreetMap feature editor
# Prefer the project apt (tested builds). Ubuntu universe lags (e.g. svn19481
# while tested is newer). See https://josm.openstreetmap.de/wiki/Download#Ubuntu
mkdir -p /etc/apt/keyrings
wget -c --progress=dot:mega \
   -O /etc/apt/keyrings/josm-apt.gpg \
   https://josm.openstreetmap.de/josm-apt.key
JOSM_APT_SUITE=`lsb_release -sc 2>/dev/null || echo alldist`
printf 'deb [signed-by=/etc/apt/keyrings/josm-apt.gpg] https://josm.openstreetmap.de/apt %s universe\n' \
   "$JOSM_APT_SUITE" > /etc/apt/sources.list.d/josm.list
cat > /etc/apt/preferences.d/josm << EOF
Package: josm*
Pin: origin josm.openstreetmap.de
Pin-Priority: 700
EOF
apt-get update
apt-get install --assume-yes josm
# Optional Ubuntu translations package if still available alongside project josm
apt-get install --assume-yes josm-l10n || true

# Belt-and-suspenders: JPMS exports belong in JAVA_OPTS. The stock /usr/bin/josm
# adds them only after parsing "java -version"; any global *_JAVA_OPTIONS note
# on the first line skips that branch ("Missing JVM Arguments" dialog).
JOSM_EXPORTS="--add-exports=java.base/sun.security.action=ALL-UNNAMED --add-exports=java.desktop/com.sun.imageio.plugins.jpeg=ALL-UNNAMED --add-exports=java.desktop/com.sun.imageio.spi=ALL-UNNAMED"
if [ -f /etc/default/josm ] ; then
   if ! grep -q 'add-exports=java.base/sun.security.action' /etc/default/josm ; then
      printf '\n# OSGeoLive: ensure JPMS exports even if java -version parsing fails\nJAVA_OPTS="%s ${JAVA_OPTS}"\n' \
         "$JOSM_EXPORTS" >> /etc/default/josm
   fi
else
   printf '# OSGeoLive /etc/default/josm\nJAVA_OPTS="%s"\n' \
      "$JOSM_EXPORTS" > /etc/default/josm
fi

# pre-seed the josmrc file to make the default window size fit on a smaller display
mkdir -p "$USER_HOME"/.josm

cat << EOF > "$USER_HOME"/.josm/preferences
gui.geometry=800x600+40+40
gui.maximized=false
EOF

cd "$TMP_DIR"

##------------- JOSM Plugins Area ------------------------------------
mkdir -p "$USER_HOME"/.josm/plugins
chown $USER_NAME:$USER_NAME "$USER_HOME"/.josm -R

#### JOSM desktop icons
if [ -f /usr/share/applications/org.openstreetmap.josm.desktop ] ; then
   cp /usr/share/applications/org.openstreetmap.josm.desktop \
     "$USER_HOME"/Desktop/josm.desktop
elif [ -f /usr/share/applications/josm.desktop ] ; then
   cp /usr/share/applications/josm.desktop \
     "$USER_HOME"/Desktop/josm.desktop
fi
chmod a+x "$USER_HOME"/Desktop/josm.desktop

# add an icon for viewing The Map online
mkdir -p /usr/local/share/applications


# FOSSGIS edition settings (MAP_*); fall back to Auckland for plain upstream
if [ -n "${MAP_LAT:-}" ] && [ -n "${MAP_LON:-}" ] ; then
   MAP_CENTER="lat=${MAP_LAT}&lon=${MAP_LON}"
   MARKER="mlat=${MAP_LAT}&mlon=${MAP_LON}"
   ZOOM="${MAP_ZOOM:-16}"
else
   MAP_CENTER="lat=-36.853567&lon=174.766353"
   MARKER="mlat=-36.853567&mlon=174.766353"
   ZOOM="16"
fi

cat << EOF > /usr/local/share/applications/osm_online.desktop
[Desktop Entry]
Name=View OSM online
Comment=Opens a web browser to The Map
Exec=xdg-open "http://www.openstreetmap.org/?$MAP_CENTER&zoom=$ZOOM&$MARKER"
Icon=josm-32
StartupNotify=false
Terminal=false
Type=Application
Categories=Education;Science;Geoscience;
EOF

chmod a+x /usr/local/share/applications/osm_online.desktop
cp /usr/local/share/applications/osm_online.desktop "$USER_HOME/Desktop/"

#########################################################################
#### install sample OSM data (FOSSGIS: PBF from prepare_data.sh)

mkdir -p /usr/local/share/osm /usr/local/share/data/osm

wget -c --tries=3 --progress=dot:mega \
   -O /usr/local/share/osm/sample.osm \
   "https://learnosm.org/files/sample.osm"

# Prepared city extract: local/data/osm/<MAP_CITY>.osm.pbf via fossgis-local
FOSSGIS_OSM_DIR="${FOSSGIS_DIR:-/usr/local/share/gisvm/fossgis-local}/data/osm"
CITY="${MAP_CITY:-}"
CITY_PBF=""
if [ -n "$CITY" ] && [ -f "$FOSSGIS_OSM_DIR/${CITY}.osm.pbf" ] ; then
   CITY_PBF="$FOSSGIS_OSM_DIR/${CITY}.osm.pbf"
fi

if [ -n "$CITY_PBF" ] ; then
   echo "FOSSGIS: installing OSM extract $CITY_PBF"
   cp -f "$CITY_PBF" /usr/local/share/osm/"$CITY.osm.pbf"
   ln -sfn /usr/local/share/osm/"$CITY.osm.pbf" \
      /usr/local/share/data/osm/"$CITY.osm.pbf"
   ln -sfn /usr/local/share/data/osm/"$CITY.osm.pbf" \
      /usr/local/share/data/osm/feature_city.osm.pbf
else
   # Upstream fallback (Auckland bz2) when no FOSSGIS extract is present
   CITY="AUCKLAND_NZ"
   BBOX="174.75, -36.87, 174.78, -36.84"
   wget -N --progress=dot:mega \
      "https://download.osgeo.org/livedvd/data/osm/$CITY/$CITY.osm.bz2"
   if [ ! -e "$CITY.osm.bz2" ] ; then
      XAPI_URL="http://www.overpass-api.de/api/xapi?"
      XAPI_EXTRA="[@meta]"
      wget --progress=dot:mega -O "$CITY.osm" \
         "${XAPI_URL}*[bbox=$BBOX]$XAPI_EXTRA" || {
         echo "ERROR getting osm data"
         exit 1
      }
      bzip2 "$CITY.osm"
   fi
   cp -f "$CITY.osm.bz2" /usr/local/share/osm/
   ln -sfn /usr/local/share/osm/"$CITY.osm.bz2" /usr/local/share/data/osm/
   ln -sfn /usr/local/share/data/osm/"$CITY.osm.bz2" \
      /usr/local/share/data/osm/feature_city.osm.bz2
fi

####
# Smaller extract for pgRouting examples
#wget -N --progress=dot:mega \
#   "http://download.osgeo.org/livedvd/data/osm/$CITY/${CITY}_CBD.osm.bz2"
#cp -f "${CITY}_CBD.osm.bz2" /usr/local/share/osm/
#ln -s /usr/local/share/osm/${CITY}_CBD.osm.bz2 /usr/local/share/data/osm
#ln -s /usr/local/share/data/osm/"${CITY}_CBD.osm.bz2" \
#   /usr/local/share/data/osm/feature_city_CBD.osm.bz2


# To make the sqlite POI db, use osm2poidb from GpsDrive utils,
#bzcat $CITY.osm.bz2 | osm2poidb -o ${CITY}_poi.db STDIN
#bzip2 ${CITY}_poi.db


# LEGACY
# ### Make hi-res OSM coastline a shapefile polygon for Mapnik rendering
#
# # Xapi OSM extractor:  http://wiki.openstreetmap.org/wiki/Xapi
# wget -O barcelona_coastline.osm \
#    "http://osmxapi.hypercube.telascience.org/api/0.6/way[natural=coastline][bbox=1.5,41.0,2.5,41.75]"
#
# # GRASS GIS commands to turn the .osm coastline segment into a closed shapefile polygon
# v.in.gpsbabel -r in=barcelona_coastline.osm format=osm \
#   out=barcelona_coastline
#
# eval `v.info -g barcelona_coastline`
#  north=41.562324
#  south=41.163893
#  east=2.515893
#  west=1.462335
#
# echo "
# L 4
#  $west $south
#  $west 41.75
#  $east 41.75
#  $east $north
# " | v.in.ascii -n format=standard out=barcelona_ul_box --o
#
# v.patch in=barcelona_coastline,barcelona_ul_box out=barcelona_coastline_box1
# v.type in=barcelona_coastline_box1 out=barcelona_coastline_box2 type=line,boundary
# v.centroids in=barcelona_coastline_box2 out=barcelona_coastline_box
# g.remove v=barcelona_coastline_box1,barcelona_coastline_box2
#
# v.out.ogr -c in=barcelona_coastline_box dsn=barcelona_coastline_box type=area
#
# tar czf barcelona_coastline_box.tgz barcelona_coastline_box/
#
#FILE="barcelona_coastline_box.tgz"
#wget -N --progress=dot "http://download.osgeo.org/livedvd/data/osm/$FILE"
#tar xzf "$FILE"
#mv `basename $FILE .tgz` /usr/local/share/osm/
#ln -s /usr/local/share/osm/`basename $FILE .tgz` /usr/local/share/data/osm


####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
