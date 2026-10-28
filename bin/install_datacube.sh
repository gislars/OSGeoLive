#!/bin/sh
# Copyright (c) 2023-2026 The Open Source Geospatial Foundation and others.
# Licensed under the GNU LGPL version >= 2.1.
#
# About:
# =====
# Initialize Open Data Cube. Ubuntu 26.04 has no python3-datacube / odc-*
# debs (build126); install via the shared FOSSGIS venv.
#

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

set -e

if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

TMP="/tmp/build_datacube"
DDIR="/usr/local/share/data/odc"

. "$BUILD_DIR/tools/osgeolive_venv.sh"

echo "Installing datacube/odc into $OSGEOLIVE_VENV (no Resolute debs)"
# psycopg2-binary first: datacube[postgres] pulls source psycopg2 and needs gcc
# (build142: No such file or directory: x86_64-linux-gnu-gcc).
if ! osgeolive_venv_pip psycopg2-binary ; then
   echo "ERROR: pip install psycopg2-binary failed" >&2
   exit 1
fi
if ! osgeolive_venv_pip datacube odc-geo odc-stac ; then
   echo "ERROR: pip install datacube/odc-* failed" >&2
   exit 1
fi
DATACUBE_BIN=`osgeolive_venv_bin datacube`
if [ ! -x "$DATACUBE_BIN" ] ; then
   echo "ERROR: datacube binary missing after pip install" >&2
   exit 1
fi
ln -sfn "$DATACUBE_BIN" /usr/local/bin/datacube

mkdir -p ${DDIR} --verbose
mkdir -p "$TMP"
cd "$TMP"

sudo -u $USER_NAME createdb datacube
sudo -u $USER_NAME psql datacube -c 'create extension postgis'
sudo -u $USER_NAME psql datacube -c 'create extension hstore'

DCONF=/home/${USER_NAME}/.config/datacube

mkdir -p ${DCONF}
chown -R ${USER_NAME} ${DCONF}

echo "#--" >> ${USER_HOME}/.bashrc
echo "export DCONF=${USER_HOME}/.config/datacube" >> ${USER_HOME}/.bashrc
echo "export DATACUBE_CONFIG_PATH=${DCONF}/datacube.conf" >> ${USER_HOME}/.bashrc

cat << EOF > ${DCONF}/datacube.conf
[datacube]
db_database: datacube

# A blank PG host will use a local socket.
#  Specify a hostname (such as localhost) to use TCP.
db_hostname:

# Credentials are optional: you might have other Postgres authentication configured.
# The default username otherwise is the current user id.
db_username: user
db_password: user
EOF

cat << EOF > ${DCONF}/landsat-clip.yaml
name: clip_landsat
description: example ortho imagery
metadata_type: eo3

license: CC-BY-4.0

metadata:
  product:
    name: clip_landsat

storage:
  crs: EPSG:32619
  resolution:
    longitude: 28.497418829384827
    latitude: -28.503958771796388

measurements:
  - name: imagery
    dtype: uint8
    nodata: 0
    units: "1"

EOF

sudo -u $USER_NAME "$DATACUBE_BIN" -v -C ${DCONF}/datacube.conf \
    system init

cp -f ${BUILD_DIR}/../app-data/odc/*.yaml ${DCONF}/

wget -c  -O ${DDIR}/esa_10m_2021_prizren.tif \
     https://download.osgeo.org/livedvd/data/odc/esa_10m_2021_prizren.tif

wget -c  -O ${DDIR}/srtm_prizren.tif \
     http://download.osgeo.org/livedvd/data/odc/srtm_prizren.tif

wget -c  -O ${DCONF}/tsrtm2_dem.odc-product.yaml \
     http://download.osgeo.org/livedvd/data/odc/tsrtm2_dem.odc-product.yaml

wget -c  -O ${DCONF}/tsrtm2-sample0.yaml \
     http://download.osgeo.org/livedvd/data/odc/tsrtm2-sample0.yaml

sudo -u $USER_NAME "$DATACUBE_BIN" -C ${DCONF}/datacube.conf \
    product add ${DCONF}/landsat-clip.yaml

sudo -u $USER_NAME "$DATACUBE_BIN" -C ${DCONF}/datacube.conf \
    product add ${DCONF}/esa_worldcover_2021.odc-product.yaml

sudo -u $USER_NAME "$DATACUBE_BIN" -C ${DCONF}/datacube.conf \
    product add ${DCONF}/tsrtm2_dem.odc-product.yaml

sudo -u $USER_NAME "$DATACUBE_BIN" -C ${DCONF}/datacube.conf \
    dataset add ${DCONF}/esa-sample0.yaml

sudo -u $USER_NAME "$DATACUBE_BIN" -C ${DCONF}/datacube.conf \
    dataset add ${DCONF}/tsrtm2-sample0.yaml

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
