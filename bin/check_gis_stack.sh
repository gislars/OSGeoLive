#!/bin/sh
#############################################################################
#
# Purpose: Abort the build if GDAL, GRASS and QGIS do not form one stack
#          (one libgdal, matching grass ABI, GRASS plugin loads).
#
#############################################################################

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

set -e

echo "Checking GIS stack versions..."

# Prefer package metadata: gdalinfo --version can print nothing useful in
# nspawn (PROJ data warnings, unexpected banner) while libgdal38 is fine.
GDAL_VER=
if command -v gdal-config > /dev/null ; then
   GDAL_VER=`gdal-config --version 2>/dev/null || true`
fi
if [ -z "$GDAL_VER" ] && command -v gdalinfo > /dev/null ; then
   GDAL_VER=`gdalinfo --version 2>/dev/null | \
      sed -n 's/^GDAL \([0-9][0-9.]*\).*/\1/p' | head -n 1`
fi
if [ -z "$GDAL_VER" ] ; then
   GDAL_VER=`python3 -c 'from osgeo import gdal; print(gdal.__version__)' 2>/dev/null || true`
fi
if [ -z "$GDAL_VER" ] ; then
   GDAL_VER=`dpkg-query -W -f='${Version}' libgdal38 2>/dev/null | \
      sed -n 's/^\([0-9][0-9.]*\).*/\1/p'`
fi
echo "GDAL: $GDAL_VER"
case "$GDAL_VER" in
   3.12.*) ;;
   *)
      echo "ERROR: expected GDAL 3.12.x, got ${GDAL_VER:-<empty>}" >&2
      command -v gdalinfo > /dev/null && gdalinfo --version >&2 || true
      dpkg-query -W libgdal38 >&2 || true
      exit 1
      ;;
esac

if ! command -v grass > /dev/null ; then
   echo "ERROR: grass missing" >&2
   exit 1
fi
# grass --version may print locale warnings before the version line.
GRASS_VER=
if grass --config version > /dev/null 2>&1 ; then
   GRASS_VER=`grass --config version 2>/dev/null || true`
fi
if [ -z "$GRASS_VER" ] ; then
   GRASS_VER=`grass --version 2>&1 | grep -E 'GRASS [0-9]|^[0-9]+\.[0-9]' | head -n 1`
fi
if [ -z "$GRASS_VER" ] ; then
   GRASS_VER=`dpkg-query -W -f='${Version}' grass-core 2>/dev/null | \
      sed -n 's/^\([0-9][0-9.]*\).*/\1/p'`
fi
echo "GRASS: $GRASS_VER"
echo "$GRASS_VER" | grep -q '8\.4' || {
   echo "ERROR: expected GRASS 8.4.x in: ${GRASS_VER:-<empty>}" >&2
   grass --version >&2 || true
   dpkg-query -W grass-core >&2 || true
   exit 1
}

if ! dpkg -s qgis > /dev/null 2>&1 ; then
   echo "ERROR: qgis package not installed" >&2
   exit 1
fi
QGIS_VER=`dpkg -s qgis | sed -n 's/^Version: //p'`
echo "QGIS: $QGIS_VER"
echo "$QGIS_VER" | grep -q '^1:4\.2\.' || {
   echo "ERROR: expected QGIS 4.2.x from qgis.org, got $QGIS_VER" >&2
   exit 1
}

# Exactly one libgdal* in the direct Depends of the main QGIS packages
GDAL_PKGS=`{
   dpkg-query -W -f='${Depends}\n' qgis python3-qgis qgis-providers 2>/dev/null
   apt-cache depends qgis python3-qgis qgis-providers 2>/dev/null
} | tr ',' '\n' | sed -n 's/.*\(libgdal[0-9][0-9]*\).*/\1/p' | sort -u`
GDAL_COUNT=`printf '%s\n' "$GDAL_PKGS" | grep -c . || true`
echo "QGIS pulls libgdal packages: $GDAL_PKGS"
if [ "$GDAL_COUNT" -ne 1 ] ; then
   echo "ERROR: QGIS must depend on exactly one libgdal*, got $GDAL_COUNT" >&2
   exit 1
fi
echo "$GDAL_PKGS" | grep -qx 'libgdal38' || {
   echo "ERROR: expected libgdal38, got $GDAL_PKGS" >&2
   exit 1
}

if ! dpkg -s qgis-plugin-grass > /dev/null 2>&1 ; then
   echo "ERROR: qgis-plugin-grass not installed" >&2
   exit 1
fi

# GRASS provider / plugin must link the same libgdal as the rest of the stack
PLUGIN_SO=`dpkg -L qgis-provider-grass qgis-plugin-grass 2>/dev/null | \
   grep -E '\.so(\.|$)' | head -n 1`
if [ -z "$PLUGIN_SO" ] ; then
   echo "ERROR: no shared library found for the QGIS GRASS plugin" >&2
   exit 1
fi
echo "Checking $PLUGIN_SO"
if ! ldd "$PLUGIN_SO" | grep -q 'libgdal\.so\.38' ; then
   echo "ERROR: GRASS plugin does not link libgdal.so.38:" >&2
   ldd "$PLUGIN_SO" | grep -i gdal >&2 || true
   exit 1
fi
if ldd "$PLUGIN_SO" | grep -E 'libgdal\.so\.[0-9]+' | grep -vq 'libgdal\.so\.38' ; then
   echo "ERROR: GRASS plugin links an unexpected libgdal:" >&2
   ldd "$PLUGIN_SO" | grep -i gdal >&2
   exit 1
fi

echo "GIS stack OK (GDAL $GDAL_VER, $GRASS_VER, QGIS $QGIS_VER)."

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
