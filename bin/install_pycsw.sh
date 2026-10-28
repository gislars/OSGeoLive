#!/bin/sh
#############################################################################
#
# Purpose: This script will install pycsw
#
#############################################################################
# Copyright (c) 2013-2026 The Open Source Geospatial Foundation and others.
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

# Runtime uses /opt/osgeolive-venv (pycsw + SQLAlchemy 1.4 + legacy-cgi) under
# mod_wsgi DaemonProcess. Deb packages still provide demo data and HTML docs.
# Do not patch files under /usr/lib/python3/dist-packages.

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####


# live disc's username is "user"
if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

APP_CONF="$BUILD_DIR/../app-conf/pycsw"
PYCSW_PIP_VERSION="2.6.2"

. "$BUILD_DIR/tools/osgeolive_venv.sh"

echo 'Installing pycsw (Deb data/docs + venv runtime) ...'

# Demo SQLite DB and docs; pycsw-wsgi pulls system python3-pycsw which we do
# not use for the WSGI process (SQLAlchemy 2.0 incompatible).
apt-get install --yes pycsw pycsw-doc javascript-common libapache2-mod-wsgi-py3

# Upstream still targets SQLAlchemy 1.4; legacy-cgi replaces stdlib cgi on
# Python >= 3.13 (PEP 594). Isolate both in the shared Live venv.
if ! osgeolive_venv_pip \
   "SQLAlchemy>=1.4,<2" \
   "legacy-cgi" \
   "pycsw==$PYCSW_PIP_VERSION" ; then
   echo "ERROR: pip install pycsw stack into osgeolive-venv failed" >&2
   exit 1
fi

if ! "$OSGEOLIVE_VENV/bin/python" -c "import pycsw, cgi, sqlalchemy; assert sqlalchemy.__version__.startswith('1.')" ; then
   echo "ERROR: pycsw venv runtime check failed" >&2
   exit 1
fi

echo 'Installing OSGeoLive pycsw WSGI config ...'
mkdir -p /usr/local/share/pycsw /etc/pycsw
cp -f "$APP_CONF/wsgi.py" /usr/local/share/pycsw/wsgi.py
cp -f "$APP_CONF/default.cfg" /etc/pycsw/default.cfg
cp -f "$APP_CONF/apache-pycsw.conf" /etc/apache2/conf-available/osgeolive-pycsw.conf
chmod 644 /usr/local/share/pycsw/wsgi.py /etc/pycsw/default.cfg \
   /etc/apache2/conf-available/osgeolive-pycsw.conf

# Prefer our venv-backed conf over the Deb WSGI snippet (if present).
a2disconf pycsw-wsgi >/dev/null 2>&1 || true
a2enmod wsgi >/dev/null 2>&1 || true
a2enconf osgeolive-pycsw >/dev/null 2>&1 || true

echo 'Downloading pycsw logo ...'
wget -c --progress=dot:mega \
   -O /usr/local/share/icons/pycsw.png \
   "https://github.com/geopython/pycsw/raw/master/docs/_static/favicon/android-chrome-192x192.png"

echo 'Installing desktop launcher ...'

cat << EOF > /usr/share/applications/pycsw.desktop
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=pycsw
Comment=pycsw catalog server
Exec=xdg-open "http://localhost/pycsw/?service=CSW&version=2.0.2&request=GetCapabilities"
Icon=pycsw
Terminal=false
StartupNotify=false
Categories=Application;Education;Geography;CSW
EOF

cp /usr/share/applications/pycsw.desktop "$USER_HOME/Desktop/"
chown "$USER_NAME:$USER_NAME" "$USER_HOME/Desktop/pycsw.desktop"

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
