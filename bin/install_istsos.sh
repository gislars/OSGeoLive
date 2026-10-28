#!/bin/sh
# Copyright (c) 2016-2026 The Open Source Geospatial Foundation and others.
# Licensed under the GNU LGPL version >= 2.1.
#
# About:
# =====
# Install istSOS. Ubuntu 26.04 has no python3-istsos deb (build126);
# use the shared FOSSGIS venv via pip.
#

./diskspace_probe.sh "`basename $0`" begin
####

set -e

if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"
BUILD_DIR=`pwd`

. "$BUILD_DIR/tools/osgeolive_venv.sh"

echo "Installing istSOS into $OSGEOLIVE_VENV (no python3-istsos on Resolute)"
if ! osgeolive_venv_pip istsos ; then
   echo "ERROR: pip install istsos failed" >&2
   exit 1
fi

ISTSOS_BIN=`osgeolive_venv_bin istsos`
if [ ! -x "$ISTSOS_BIN" ] ; then
   # Package may only provide modules; keep a discoverable wrapper.
   ISTSOS_BIN=`osgeolive_venv_bin python`
fi
mkdir -p /usr/local/bin
cat << EOF > /usr/local/bin/istsos
#!/bin/sh
exec "$OSGEOLIVE_VENV/bin/python" -m istsos "\$@"
EOF
chmod 755 /usr/local/bin/istsos

echo "Installing istSOS icon"
ICON_SRC=""
for CAND in \
   "$OSGEOLIVE_VENV"/lib/python*/site-packages/istsos*/interface/admin/images/istsos-logo.png \
   /usr/share/istsos/interface/admin/images/istsos-logo.png ; do
   # shellcheck disable=SC2086
   for F in $CAND ; do
      if [ -f "$F" ] ; then
         ICON_SRC="$F"
         break
      fi
   done
   [ -n "$ICON_SRC" ] && break
done
if [ -n "$ICON_SRC" ] ; then
   cp -f "$ICON_SRC" /usr/share/icons/istsos-logo.png
else
   echo "FOSSGIS: istsos logo not in package; using generic icon"
   ln -sfn /usr/share/icons/hicolor/48x48/apps/utilities-terminal.png \
      /usr/share/icons/istsos-logo.png 2>/dev/null || true
fi

## desktop launcher
cat << EOF > /usr/share/applications/istsos.desktop
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=istSOS
Comment=istSOS server
Categories=Application;Geography;Geoscience;Education;
Exec=xdg-open http://localhost/istsos/admin
Icon=/usr/share/icons/istsos-logo.png
Terminal=false
EOF

cp -a /usr/share/applications/istsos.desktop "$USER_HOME/Desktop/"
chown -R "$USER_NAME":"$USER_NAME" "$USER_HOME/Desktop/istsos.desktop"

####
./diskspace_probe.sh "`basename $0`" end
