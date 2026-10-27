#!/bin/sh
# Copyright (c) 2013-2026 The Open Source Geospatial Foundation and others.
# Licensed under the GNU LGPL version >= 2.1.
#
# About:
# =====
# This script will install pgadmin4 in ubuntu

./diskspace_probe.sh "`basename $0`" begin
####

if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/${USER_NAME}"
BUILD_DIR=`pwd`

##Add pgadmin4 key
curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | \
   gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg

##Add pgadmin4 repository
cp "$BUILD_DIR"/../sources.list.d/pgadmin4.list /etc/apt/sources.list.d/
apt-get -q update

# pgadmin4-desktop postinst loads AppArmor and runs df; both can fail in chroot.
apt-get install --yes pgadmin4-desktop || true
if dpkg -s pgadmin4-desktop 2>/dev/null | grep -q "Status: install ok installed" ; then
   :
elif [ -f /var/lib/dpkg/info/pgadmin4-desktop.postinst ]; then
   mv /var/lib/dpkg/info/pgadmin4-desktop.postinst \
      /var/lib/dpkg/info/pgadmin4-desktop.postinst.bak
   printf '%s\n' '#!/bin/sh' 'exit 0' > /var/lib/dpkg/info/pgadmin4-desktop.postinst
   chmod 755 /var/lib/dpkg/info/pgadmin4-desktop.postinst
   dpkg --configure pgadmin4-desktop
fi

rm -f /etc/apt/sources.list.d/pgadmin4.list
apt-get -q update

# Wrapper: NW.js/Chromium sandbox fails on Live/USB
if [ -x /usr/pgadmin4/bin/pgadmin4 ]; then
   cat << 'WRAPPER' > /usr/bin/pgadmin4
#!/bin/sh
exec /usr/pgadmin4/bin/pgadmin4 --no-sandbox "$@"
WRAPPER
   chmod 755 /usr/bin/pgadmin4
fi

if [ -f /usr/share/applications/pgadmin4.desktop ]; then
   sed -i -e 's|^Exec=.*|Exec=/usr/bin/pgadmin4 %F|' \
      /usr/share/applications/pgadmin4.desktop
   sed -i -e 's/;Database//g' -e 's/^Categories=Database;//' \
      /usr/share/applications/pgadmin4.desktop
fi

# Live/demo: skip master password prompt
for WEBDIR in /usr/pgadmin4/web /usr/share/pgadmin4/web ; do
   if [ -d "$WEBDIR" ] && [ -f "$WEBDIR/config.py" ]; then
      printf '%s\n' \
         '# Live/demo: skip master password prompt' \
         'MASTER_PASSWORD_REQUIRED = False' > "$WEBDIR/config_local.py"
      chmod 644 "$WEBDIR/config_local.py"
      break
   fi
done

mkdir -p "$USER_HOME/.pgadmin"
chown "${USER_NAME}:${USER_NAME}" "$USER_HOME/.pgadmin"

cp "$BUILD_DIR"/../app-conf/postgresql/pgadmin4.db "$USER_HOME/.pgadmin/pgadmin4.db"
chown "${USER_NAME}:${USER_NAME}" "$USER_HOME/.pgadmin/pgadmin4.db"

cp /usr/share/applications/pgadmin4.desktop "$USER_HOME"/Desktop/
chown "${USER_NAME}:${USER_NAME}" "$USER_HOME"/Desktop/pgadmin4.desktop

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
