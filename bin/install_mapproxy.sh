#!/bin/sh
# Copyright (c) 2009-2024 The Open Source Geospatial Foundation and others.
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
# About:
# =====
# This script will install MapProxy server
# Created by Oliver Tonnhofer <olt@omniscale.de>
#
# Running:
# =======
# sudo service apache2 start
# Then open a web browser and go to http://localhost/ol3/

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

BIN="/usr/local/bin"
MAPPROXY_DIR="/usr/local/share/mapproxy"

. "$BUILD_DIR/tools/osgeolive_venv.sh"

# Deb for HTML docs under /usr/share/doc/mapproxy. Runtime must use the
# osgeolive-venv: Mapnik Python bindings live there (install_mapnik.sh), and
# system python3-mapproxy cannot import them (CRITICAL exit on start).
apt-get install --yes mapproxy

if ! osgeolive_venv_pip mapproxy ; then
   echo "ERROR: pip install mapproxy into osgeolive-venv failed" >&2
   exit 1
fi
MAPPROXY_UTIL=`osgeolive_venv_bin mapproxy-util`
if [ ! -x "$MAPPROXY_UTIL" ] ; then
   echo "ERROR: $MAPPROXY_UTIL missing after pip install" >&2
   exit 1
fi
if ! "$OSGEOLIVE_VENV/bin/python" -c "import mapnik" ; then
   echo "ERROR: mapnik missing in osgeolive-venv; install_mapnik.sh must run first" >&2
   exit 1
fi

# Mapnik Map has no __dict__; MapProxy's map_obj_pid attribute write fails
# (GetMap 500 on mapnik_tile). Also drop deprecated +init= SRS syntax.
"$OSGEOLIVE_VENV/bin/python" << 'PY'
from pathlib import Path
import mapproxy.source.mapnik as mod

path = Path(mod.__file__)
text = path.read_text()
orig = text

if "_map_obj_pids" not in text:
    text = text.replace(
        "MAX_UNUSED_MAPS = 10\n",
        "MAX_UNUSED_MAPS = 10\n"
        "# FOSSGIS: Mapnik Map has no __dict__; keep pid off-object\n"
        "_map_obj_pids = {}\n",
        1,
    )

old_create = """    def _create_map_obj(self, mapfile, process_id):
        m = mapnik.Map(0, 0)
        mapnik.load_map(m, str(mapfile))
        m.map_obj_pid = process_id
        return m"""
new_create = """    def _create_map_obj(self, mapfile, process_id):
        m = mapnik.Map(0, 0)
        mapnik.load_map(m, str(mapfile))
        try:
            m.map_obj_pid = process_id
        except AttributeError:
            _map_obj_pids[id(m)] = process_id
        return m"""
if old_create in text:
    text = text.replace(old_create, new_create, 1)

old_check = """            if m.map_obj_pid == process_id:
                return m"""
new_check = """            pid = getattr(m, "map_obj_pid", _map_obj_pids.get(id(m)))
            if pid == process_id:
                return m"""
if old_check in text:
    text = text.replace(old_check, new_check, 1)

old_srs = "m.srs = '+init=%s' % str(query.srs.srs_code.lower())"
new_srs = "m.srs = str(query.srs.srs_code.lower())"
if old_srs in text:
    text = text.replace(old_srs, new_srs, 1)

if text == orig:
    raise SystemExit(
        "ERROR: MapProxy mapnik.py patch did not apply; upstream layout changed"
    )
path.write_text(text)
print(f"FOSSGIS: patched {path}")
PY

echo 'Downloading mapproxy logo ...'
wget -c --progress=dot:mega \
   -O /usr/local/share/icons/mapproxy.png \
   "https://github.com/mapproxy/mapproxy/raw/master/doc/_static/logo.png"

echo "Creating Scripts/Links"
# Create startup script for MapProxy Server (venv binary; pause on failure so
# qterminal -e does not flash closed before the user can read the error)
mkdir -p "$BIN"
cat << EOF > "$BIN/mapproxy_start.sh"
#!/bin/sh
MAPPROXY_UTIL="$MAPPROXY_UTIL"
MAPPROXY_CONF="/usr/local/share/mapproxy/mapproxy.yaml"
if [ ! -x "\$MAPPROXY_UTIL" ]; then
  echo "ERROR: MapProxy binary missing: \$MAPPROXY_UTIL"
  echo "Press Enter to close."
  read -r _
  exit 1
fi
"\$MAPPROXY_UTIL" serve-develop -b 0.0.0.0:8011 "\$MAPPROXY_CONF"
status=\$?
if [ "\$status" -ne 0 ]; then
  echo
  echo "MapProxy exited with status \$status. Press Enter to close."
  read -r _
fi
exit "\$status"
EOF

chmod 755 $BIN/mapproxy_start.sh

ln -sf /usr/share/doc/mapproxy/html /var/www/html/mapproxy

## Create Desktop Shortcut for starting MapProxy Server in shell
cat << EOF > /usr/share/applications/mapproxy-start.desktop
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=Start MapProxy
Comment=MapProxy for OSGeoLive WMS services (http://localhost:8011/demo/)
Categories=Application;Geography;Geoscience;Education;
Exec=qterminal -e $BIN/mapproxy_start.sh
Icon=mapproxy
Terminal=false
StartupNotify=false
EOF

cp -a /usr/share/applications/mapproxy-start.desktop "$USER_HOME/Desktop/"
chown -R $USER_NAME:$USER_NAME "$USER_HOME/Desktop/mapproxy-start.desktop"

# Create Desktop Shortcut for Basic Intro page and Demo
cat << EOF > /usr/share/applications/mapproxy-intro.desktop
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=MapProxy Introduction
Comment=MapProxy Introduction
Categories=Application;Geography;Geoscience;Education;
Exec=firefox http://localhost/osgeolive/en/overview/mapproxy_overview.html
Icon=mapproxy
Terminal=false
StartupNotify=false
EOF

cp -a /usr/share/applications/mapproxy-intro.desktop "$USER_HOME/Desktop/"
chown -R $USER_NAME:$USER_NAME "$USER_HOME/Desktop/mapproxy-intro.desktop"

echo "Creating Configuration"
mkdir -p "$MAPPROXY_DIR"
cat << EOF > "$MAPPROXY_DIR/mapproxy.yaml"
services:
  demo:
  kml:
  tms:
  wmts:
  wms:
    srs: ['EPSG:4326', 'EPSG:900913', 'EPSG:3857', 'EPSG:4258', 'EPSG:26915']
    # image_formats: ['image/jpeg', 'image/png']
    md:
      # metadata used in capabilities documents
      title: MapProxy WMS Proxy
      abstract: This is the fantastic MapProxy.
      online_resource: http://mapproxy.org/
      contact:
        person: Your Name Here
        position: Technical Director
        organization:
        address: Fakestreet 123
        city: Somewhere
        postcode: 12345
        country: Germany
        phone: +49(0)000-000000-0
        fax: +49(0)000-000000-0
        email: info@omniscale.de
      access_constraints:
        This service is intended for private and evaluation use only.
        The data is licensed as Creative Commons Attribution-Share Alike 2.0
        (http://creativecommons.org/licenses/by-sa/2.0/)
      fees: 'None'

layers:
  - name: mapnik
    title: World population (Mapnik)
    sources: [mapnik]
  - name: mapnik_tile
    title: World population (Mapnik, tile cached)
    sources: [mapnik_cache]
  - name: mapserver
    title: Mapserver (Itasca)
    sources: [mapserver]
  - name: geoserver
    title: US Population (Geoserver WMS)
    sources: [geoserver]
  - name: mapnik_geoserver
    title: World population (Mapnik) + US Population (Geoserver WMS)
    sources: [mapnik, geoserver]

caches:
  mapnik_cache:
    grids: [GLOBAL_WEBMERCATOR]
    sources: [mapnik]

sources:
  geoserver:
    type: wms
    wms_opts:
      featureinfo: true
    req:
      url: http://localhost:8082/geoserver/wms?
      layers: 'topp:states'
      transparent: true
    coverage:
      bbox: -124.73142200000001,24.955967,-66.969849,49.371735
      bbox_srs: 'EPSG:4326'


  mapnik:
    type: mapnik
    mapfile: /usr/local/share/mapnik/world_population.xml
    transparent: true
    coverage:
      bbox: -180,-90,180,90
      bbox_srs: 'epsg:4326'    

  mapserver:
    type: wms
    supported_srs: ['epsg:26915']
    req:
      url: http://localhost/cgi-bin/mapserv?
      layers: airports,cities,lakespy2,dlgstln2,roads,twprgpy3
      map: /usr/local/www/docs_maps/mapserver_demos/itasca/itasca.map
    coverage:
      bbox: 363016.590190,5148502.940313,588593.999470,5374080.349593
      bbox_srs: 'epsg:26915'

 # overlay_full_example:
  #   type: wms
  #   concurrent_requests: 4
  #   wms_opts:
  #     version: 1.3.0
  #     featureinfo: true
  #   supported_srs: ['EPSG:4326', 'EPSG:31467']
  #   supported_formats: ['image/tiff', 'image/jpeg']
  #   http:
  #     ssl_no_cert_checks: true
  #   req:
  #     url: https://user:password@example.org:81/service?
  #     layers: roads,rails
  #     styles: base,base
  #     transparent: true
  #     # # always request in this format
  #     # format: image/png
  #     map: /home/map/mapserver.map


grids:
  global_geodetic_sqrt2:
    base: GLOBAL_GEODETIC
    res_factor: 'sqrt2'
  global_mercator_inverse:
    base: GLOBAL_MERCATOR
    origin: nw
  # grid_full_example:
  #   tile_size: [512, 512]
  #   srs: 'EPSG:900913'
  #   bbox: [5, 45, 15, 55]
  #   bbox_srs: 'EPSG:4326'
  #   min_res: 2000 #m/px
  #   max_res: 50 #m/px
  #   align_resolutions_with: GLOBAL_MERCATOR
  # another_grid_full_example:
  #   srs: 'EPSG:900913'
  #   bbox: [5, 45, 15, 55]
  #   bbox_srs: 'EPSG:4326'
  #   res_factor: 1.5
  #   num_levels: 25

globals:
  # # coordinate transformation options
  # srs:
  #   # WMS 1.3.0 requires all coordiates in the correct axis order,
  #   # i.e. lon/lat or lat/lon. Use the following settings to
  #   # explicitly set a CRS to either North/East or East/North
  #   # ordering.
  #   axis_order_ne: ['EPSG:9999', 'EPSG:9998']
  #   axis_order_en: ['EPSG:0000', 'EPSG:0001']
  #   # you can set the proj4 data dir here, if you need custom
  #   # epsg definitions. the path must contain a file named 'epsg'
  #   # the format of the file is:
  #   # <4326> +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs  <>
  #   proj_data_dir: '/path to dir that contains epsg file'

  # # cache options
  cache:
    # where to store the cached images
    base_dir: '/tmp/mapproxy/cache_data'
    # where to store lockfiles
    lock_dir: '/tmp/mapproxy/cache_data/locks'
  #   # request x*y tiles in one step
  #   meta_size: [4, 4]
  #   # add a buffer on all sides (in pixel) when requesting
  #   # new images
  #   meta_buffer: 80


  # image/transformation options
  image:
      resampling_method: bicubic
      # resampling_method: bilinear
      # resampling_method: nearest
  #     jpeg_quality: 90
  #     # stretch cached images by this factor before
  #     # using the next level
  #     stretch_factor: 1.15
  #     # shrink cached images up to this factor before
  #     # returning an empty image (for the first level)
  #     max_shrink_factor: 4.0

EOF

# allow the user to write to it, via group permissions
chgrp users "$MAPPROXY_DIR/mapproxy.yaml"
chmod g+w "$MAPPROXY_DIR/mapproxy.yaml"
adduser "$USER_NAME" users


####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
