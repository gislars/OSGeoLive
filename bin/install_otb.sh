#!/bin/sh
#############################################################################
#
# Purpose: Install Orfeo Toolbox from the official Linux binary tarball
#          (Ubuntu packages libotb / monteverdi are gone in 26.04).
#          Run the upstream post_install as root once, then expose a thin
#          profile that does not re-trigger first-time setup on login shells
#          (su - user in install_node.sh would otherwise fail with
#          Permission denied under /usr/local/lib/OTB-*).
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

set -e

if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

OTB_VERSION="9.1.1"
OTB_SHORT_VERSION="9.1"
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
# Leave TMP_DIR before deleting it (avoids getcwd() failed in the build log).
cd "$BUILD_DIR"
rm -rf "$TMP_DIR"

if [ ! -f "$OTB_ROOT/otbenv.profile" ] ; then
   echo "ERROR: OTB tarball missing otbenv.profile under $OTB_ROOT" >&2
   ls -la "$OTB_ROOT" >&2 || true
   exit 1
fi
if [ ! -x "$OTB_ROOT/tools/post_install.sh" ] ; then
   echo "ERROR: OTB tarball missing tools/post_install.sh under $OTB_ROOT" >&2
   exit 1
fi

# ---------------------------------------------------------------------------
# Root post-install: cmake path rewrite + rpath sanitize (upstream post_install
# lines before the Python block). Must not run later as the live user.
# ---------------------------------------------------------------------------
export OTB_INSTALL_DIR="$OTB_ROOT"
CMAKE_DIRS="$OTB_ROOT/lib/cmake"
echo "FOSSGIS: OTB root binary post_install under $OTB_ROOT"
sed -i "s/FATAL_ERROR/WARNING/g" "$CMAKE_DIRS/OTB-$OTB_SHORT_VERSION/OTBTargets.cmake"
sed -i "s/FATAL_ERROR/WARNING/g" "$CMAKE_DIRS/OTB-$OTB_SHORT_VERSION/OTBModuleAPI.cmake"
sed -i "s/\/builds\/otb\/xdk/\${OTB_INSTALL_PREFIX}/g" "$CMAKE_DIRS"/OTB-"$OTB_SHORT_VERSION"/*.cmake
sed -i "s/\/builds\/otb\/xdk/\${OTB_INSTALL_PREFIX}/g" "$CMAKE_DIRS"/OTB-"$OTB_SHORT_VERSION"/Modules/*.cmake
sed -i "s/\/builds\/otb\/xdk/\${OTB_INSTALL_PREFIX}/g" "$CMAKE_DIRS"/ITK-4.13/*.cmake
sed -i "s/\/builds\/otb\/xdk/\${OTB_INSTALL_PREFIX}/g" "$CMAKE_DIRS"/ITK-4.13/Modules/*.cmake
sed -i "s/\/builds\/otb\/xdk/\$OTB_INSTALL_DIR/g" "$OTB_ROOT"/bin/gdal-config
sed -i "s/\/builds\/otb\/xdk/\$OTB_INSTALL_DIR/g" "$OTB_ROOT"/bin/curl-config
sh "$OTB_ROOT/tools/sanitize_rpath.sh"

# Python wrapping: try; Ubuntu 26.04 is Python 3.14 and upstream has no
# OTB-9.1-GDAL-bindings-py314.tar.gz (HTTP 404). Keep CLI/Mapla usable.
OTB_PYTHON_OK=1
concatpyversion="$(python3 -V 2>&1 | sed 's/.* \([0-9]\).\([0-9]*\).*/\1\2/')"
if [ -x "$OTB_ROOT/recompile_bindings.sh" ] && [ "$concatpyversion" != "38" ] ; then
   echo "FOSSGIS: trying OTB Python wrapping for Python $concatpyversion"
   if ! sh "$OTB_ROOT/recompile_bindings.sh" ; then
      echo "FOSSGIS: OTB Python wrapping failed for Python $concatpyversion; CLI/Mapla remain" >&2
      OTB_PYTHON_OK=0
   fi
fi

osgeo_pkg_path=$(find "$OTB_ROOT/lib" -mindepth 3 -maxdepth 3 -type d -name "osgeo" 2>/dev/null | head -n 1 || true)
gdal_python_found=""
if [ -n "$osgeo_pkg_path" ] ; then
   gdal_python_found="$(find "$osgeo_pkg_path" -name "*$concatpyversion-x86_64-linux*" 2>/dev/null | head -n 1 || true)"
fi
if [ -z "$gdal_python_found" ] ; then
   GDAL_URL="https://www.orfeo-toolbox.org/packages/archives/OTB/OTB-${OTB_SHORT_VERSION}-GDAL-bindings-py${concatpyversion}.tar.gz"
   echo "FOSSGIS: checking $GDAL_URL"
   HTTP_STATUS=$(curl -s -o "$OTB_ROOT/tools/gdal-py${concatpyversion}.tar.gz" -w "%{response_code}" "$GDAL_URL" || echo "000")
   if [ "$HTTP_STATUS" = "200" ] && [ -n "$osgeo_pkg_path" ] ; then
      tar -xf "$OTB_ROOT/tools/gdal-py${concatpyversion}.tar.gz" -C "$osgeo_pkg_path"
      rm -f "$OTB_ROOT/tools/gdal-py${concatpyversion}.tar.gz"
      echo "FOSSGIS: GDAL bindings for Python $concatpyversion installed"
   else
      rm -f "$OTB_ROOT/tools/gdal-py${concatpyversion}.tar.gz"
      echo "FOSSGIS: skipping OTB GDAL Python bindings for py${concatpyversion} (upstream HTTP $HTTP_STATUS at $GDAL_URL); CLI/Mapla remain" >&2
      OTB_PYTHON_OK=0
   fi
fi

# Marker so otbenv.profile / login shells never re-run first-time setup as user.
echo "OK" > "$OTB_ROOT/tools/install_done.txt"
if [ "$OTB_PYTHON_OK" = "0" ] ; then
   echo "FOSSGIS: OTB binary post_install done; Python bindings incomplete (documented)" >&2
fi

# Smoke: dynamic linker must resolve after rpath sanitize.
OTB_SMOKE=""
for CAND in otbcli_BandMath otbcli_ReadImageInfo ; do
   if [ -x "$OTB_ROOT/bin/$CAND" ] ; then
      OTB_SMOKE="$CAND"
      break
   fi
done
if [ -z "$OTB_SMOKE" ] ; then
   echo "ERROR: no otbcli_* binary under $OTB_ROOT/bin" >&2
   ls -la "$OTB_ROOT/bin" >&2 || true
   exit 1
fi
if ldd "$OTB_ROOT/bin/$OTB_SMOKE" 2>/dev/null | grep -q "not found" ; then
   echo "ERROR: $OTB_SMOKE has unresolved libraries after sanitize_rpath" >&2
   ldd "$OTB_ROOT/bin/$OTB_SMOKE" >&2 || true
   exit 1
fi
echo "FOSSGIS: OTB smoke OK ($OTB_SMOKE)"

# OTB env must NOT be in /etc/profile.d: PYTHONPATH/LD_LIBRARY_PATH/GDAL_*
# from the binary tarball shadow Ubuntu/QGIS python3-gdal (No module named
# _gdal / osgeo._gdal) and can break system gdalinfo. Env only in wrappers.
cat << EOF > /etc/profile.d/otb.sh
# Orfeo Toolbox ${OTB_VERSION}: path marker only. Full env is in
# /usr/local/bin/{monteverdi,mapla,otbcli*} wrappers (see install_otb.sh).
OTB_INSTALL_DIR="$OTB_ROOT"
export OTB_INSTALL_DIR
EOF
chmod 644 /etc/profile.d/otb.sh

cat << EOF > /usr/local/bin/otb-env.sh
# Sourced by OTB wrappers; not for login shells.
# shellcheck shell=sh
OTB_INSTALL_DIR="\${OTB_INSTALL_DIR:-$OTB_ROOT}"
if [ ! -f "\$OTB_INSTALL_DIR/tools/install_done.txt" ] ; then
   echo "OTB not post-installed under \$OTB_INSTALL_DIR" >&2
   return 1 2>/dev/null || exit 1
fi
PATH="\$OTB_INSTALL_DIR/bin:\$PATH"
OTB_APPLICATION_PATH="\$OTB_INSTALL_DIR/lib/otb/applications\${OTB_APPLICATION_PATH:+:\$OTB_APPLICATION_PATH}"
PYTHONPATH="\$OTB_INSTALL_DIR/lib/otb/python:\$OTB_INSTALL_DIR/lib/python3/dist-packages\${PYTHONPATH:+:\$PYTHONPATH}"
GDAL_DATA="\$OTB_INSTALL_DIR/share/gdal"
PROJ_LIB="\$OTB_INSTALL_DIR/share/proj"
LD_LIBRARY_PATH="\$OTB_INSTALL_DIR/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export OTB_INSTALL_DIR PATH OTB_APPLICATION_PATH PYTHONPATH GDAL_DATA PROJ_LIB
export LD_LIBRARY_PATH LC_NUMERIC=C GDAL_DRIVER_PATH=disable
EOF
chmod 644 /usr/local/bin/otb-env.sh

mkdir -p /usr/local/bin
for APP in monteverdi mapla ; do
   if [ -x "$OTB_ROOT/bin/$APP" ] ; then
      cat << EOF > "/usr/local/bin/$APP"
#!/bin/sh
# shellcheck source=/dev/null
. /usr/local/bin/otb-env.sh
exec "$OTB_ROOT/bin/$APP" "\$@"
EOF
      chmod 755 "/usr/local/bin/$APP"
   fi
done

# otbcli and otbcli_* need the same env when invoked from PATH.
if [ -x "$OTB_ROOT/bin/otbcli" ] ; then
   cat << EOF > /usr/local/bin/otbcli
#!/bin/sh
# shellcheck source=/dev/null
. /usr/local/bin/otb-env.sh
exec "$OTB_ROOT/bin/otbcli" "\$@"
EOF
   chmod 755 /usr/local/bin/otbcli
fi
for CLI in "$OTB_ROOT"/bin/otbcli_* ; do
   [ -x "$CLI" ] || continue
   NAME=`basename "$CLI"`
   cat << EOF > "/usr/local/bin/$NAME"
#!/bin/sh
# shellcheck source=/dev/null
. /usr/local/bin/otb-env.sh
exec "$CLI" "\$@"
EOF
   chmod 755 "/usr/local/bin/$NAME"
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

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
