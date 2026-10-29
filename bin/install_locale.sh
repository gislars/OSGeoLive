#!/bin/sh
#############################################################################
#
# Purpose: German locale, keyboard, timezone and paper size for FOSSGIS
#
#############################################################################
# Copyright (c) 2026 FOSSGIS e.V. and others.
# Licensed under the GNU LGPL version >= 2.1.
#############################################################################

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

set -e

if [ -z "$USER_NAME" ] ; then
   USER_NAME="user"
fi
USER_HOME="/home/$USER_NAME"

# Defaults from edition.conf (exported by load_edition.sh)
LOCALE="${LOCALE:-de_DE.UTF-8}"
LANGUAGE="${LANGUAGE:-de:en}"
KEYMAP="${KEYMAP:-de}"
KEYMAP_VARIANT="${KEYMAP_VARIANT:-}"
TIMEZONE="${TIMEZONE:-Europe/Berlin}"
PAPERSIZE="${PAPERSIZE:-a4}"

# firefox-locale-de has no candidate once Mozilla's firefox deb replaces the
# Ubuntu transitional package (build126). Install the rest first, then try DE.
apt-get install --yes \
   language-pack-de language-pack-de-base language-pack-gnome-de \
   qt6-translations-l10n manpages-de \
   hunspell-de-de aspell-de hyphen-de mythes-de \
   console-setup \
   gnome-keyring libpam-gnome-keyring

FIREFOX_DE_OK=0
if apt-cache policy firefox-locale-de 2>/dev/null | grep -q 'Candidate: *[0-9]' ; then
   apt-get install --yes firefox-locale-de
   FIREFOX_DE_OK=1
else
   echo "FOSSGIS: firefox-locale-de has no apt candidate; trying Mozilla langpack XPI"
   FF_VER=`firefox --version 2>/dev/null | awk '{print $NF}' || true`
   FF_LIB=""
   for D in /usr/lib/firefox /usr/lib/firefox-esr ; do
      if [ -d "$D" ] ; then
         FF_LIB="$D"
         break
      fi
   done
   if [ -n "$FF_VER" ] && [ -n "$FF_LIB" ] ; then
      mkdir -p "$FF_LIB/distribution/extensions"
      XPI_URL="https://ftp.mozilla.org/pub/firefox/releases/${FF_VER}/linux-x86_64/xpi/de.xpi"
      XPI_DST="$FF_LIB/distribution/extensions/langpack-de@firefox.mozilla.org.xpi"
      if wget -q -O "$XPI_DST" "$XPI_URL" ; then
         echo "FOSSGIS: installed Firefox langpack from $XPI_URL"
         FIREFOX_DE_OK=1
      else
         rm -f "$XPI_DST"
         echo "FOSSGIS: Firefox langpack download failed ($XPI_URL); UI stays English" >&2
      fi
   else
      echo "FOSSGIS: cannot resolve Firefox version or lib dir; UI stays English" >&2
   fi
fi

# Locales
if [ -x /usr/sbin/locale-gen ] ; then
   locale-gen en_US.UTF-8
   locale-gen "$LOCALE"
fi

cat > /etc/default/locale << EOF
LANG=$LOCALE
LANGUAGE=$LANGUAGE
LC_ALL=$LOCALE
EOF

# Keyboard (console + X)
cat > /etc/default/keyboard << EOF
XKBMODEL=pc105
XKBLAYOUT=$KEYMAP
XKBVARIANT=$KEYMAP_VARIANT
BACKSPACE=guess
EOF
if command -v setupcon >/dev/null 2>&1 ; then
   setupcon --force || true
fi

# LXQt session keyboard for live user and skel
mkdir -p "$USER_HOME/.config/lxqt" /etc/skel/.config/lxqt
for TARGET in "$USER_HOME/.config/lxqt/session.conf" /etc/skel/.config/lxqt/session.conf ; do
   if [ -f "$TARGET" ] ; then
      if grep -q '^keyboard=' "$TARGET" ; then
         sed -i "s/^keyboard=.*/keyboard=$KEYMAP/" "$TARGET"
      else
         printf '\n[General]\nkeyboard=%s\n' "$KEYMAP" >> "$TARGET"
      fi
   else
      printf '[General]\nkeyboard=%s\n' "$KEYMAP" > "$TARGET"
   fi
done
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config"

# Timezone
ln -sfn "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone
# Hardware clock stays UTC (Dual-Boot workshop laptops)
if [ -f /etc/adjtime ] ; then
   sed -i 's/^LOCAL$/UTC/' /etc/adjtime || true
fi
systemctl enable systemd-timesyncd.service 2>/dev/null || true

# Paper size
echo "$PAPERSIZE" > /etc/papersize

# Keep English XDG folder names so Desktop icons from install scripts stay visible
mkdir -p /etc/xdg
cat > /etc/xdg/user-dirs.conf << EOF
enabled=False
EOF
cat > /etc/xdg/user-dirs.defaults << EOF
DESKTOP=Desktop
DOWNLOAD=Downloads
TEMPLATES=Templates
PUBLICSHARE=Public
DOCUMENTS=Documents
MUSIC=Music
PICTURES=Pictures
VIDEOS=Videos
EOF
mkdir -p "$USER_HOME/.config" /etc/skel/.config
cat > "$USER_HOME/.config/user-dirs.dirs" << EOF
XDG_DESKTOP_DIR="\$HOME/Desktop"
XDG_DOWNLOAD_DIR="\$HOME/Downloads"
XDG_TEMPLATES_DIR="\$HOME/Templates"
XDG_PUBLICSHARE_DIR="\$HOME/Public"
XDG_DOCUMENTS_DIR="\$HOME/Documents"
XDG_MUSIC_DIR="\$HOME/Music"
XDG_PICTURES_DIR="\$HOME/Pictures"
XDG_VIDEOS_DIR="\$HOME/Videos"
EOF
cp "$USER_HOME/.config/user-dirs.dirs" /etc/skel/.config/user-dirs.dirs
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/user-dirs.dirs"

# Firefox: German UI, FOSSGIS homepage, clean new-tab extension, default browser
FF_CONF="$BUILD_DIR/../app-conf/fossgis/firefox"
mkdir -p /etc/firefox/policies /usr/local/share/osgeo-desktop
if [ -f "$FF_CONF/policies.json" ] ; then
   cp "$FF_CONF/policies.json" /etc/firefox/policies/policies.json
else
   cat > /etc/firefox/policies/policies.json << EOF
{
  "policies": {
    "RequestedLocales": ["de"],
    "DontCheckDefaultBrowser": true,
    "Homepage": {
      "URL": "http://localhost/",
      "Locked": false,
      "StartPage": "homepage"
    }
  }
}
EOF
fi

# New-tab extension: logo background + conference / schedule shortcuts
FF_EXT_SRC="$FF_CONF/newtab-ext"
FF_XPI="/usr/local/share/osgeo-desktop/firefox-newtab-ext.xpi"
if [ -d "$FF_EXT_SRC" ] && [ -f "$FF_EXT_SRC/manifest.json" ] ; then
   FF_EXT_BUILD=`mktemp -d`
   cp "$FF_EXT_SRC/manifest.json" "$FF_EXT_SRC/newtab.html" "$FF_EXT_BUILD/"
   if [ -f "$FF_CONF/newtab-logo.png" ] ; then
      cp "$FF_CONF/newtab-logo.png" "$FF_EXT_BUILD/logo.png"
   elif [ -f "$FF_EXT_SRC/logo.png" ] ; then
      cp "$FF_EXT_SRC/logo.png" "$FF_EXT_BUILD/logo.png"
   fi
   if command -v zip >/dev/null 2>&1 && [ -f "$FF_EXT_BUILD/logo.png" ] ; then
      rm -f "$FF_XPI"
      ( cd "$FF_EXT_BUILD" && zip -qr "$FF_XPI" manifest.json newtab.html logo.png )
   elif [ -f "$FF_CONF/fossgis2027-newtab.xpi" ] ; then
      cp "$FF_CONF/fossgis2027-newtab.xpi" "$FF_XPI"
   fi
   rm -rf "$FF_EXT_BUILD"
fi
if [ -f "$FF_XPI" ] ; then
   # Also sideload into Firefox distribution so first start picks it up
   for FF_LIB in /usr/lib/firefox /usr/lib/firefox-esr ; do
      if [ -d "$FF_LIB" ] ; then
         mkdir -p "$FF_LIB/distribution/extensions"
         cp "$FF_XPI" \
            "$FF_LIB/distribution/extensions/fossgis2027-newtab@osgeolive.local.xpi"
      fi
   done
   echo "FOSSGIS: Firefox new-tab extension installed"
fi

# Firefox as default browser (system + live user + skel)
FF_DESKTOP="firefox.desktop"
if [ -f /usr/share/applications/firefox.desktop ] ; then
   FF_DESKTOP="firefox.desktop"
elif [ -f /usr/share/applications/firefox-esr.desktop ] ; then
   FF_DESKTOP="firefox-esr.desktop"
fi
set_ff_mime() {
   LIST="$1"
   mkdir -p "`dirname "$LIST"`"
   if [ ! -f "$LIST" ] ; then
      printf '%s\n' '[Default Applications]' > "$LIST"
   elif ! grep -q '^\[Default Applications\]' "$LIST" ; then
      printf '\n%s\n' '[Default Applications]' >> "$LIST"
   fi
   for MIME in \
      x-scheme-handler/http \
      x-scheme-handler/https \
      text/html \
      application/xhtml+xml \
      application/xhtml_xml ; do
      if grep -q "^${MIME}=" "$LIST" ; then
         sed -i -e "s|^${MIME}=.*|${MIME}=${FF_DESKTOP}|" "$LIST"
      else
         # Insert after [Default Applications]
         sed -i -e "/^\[Default Applications\]/a ${MIME}=${FF_DESKTOP}" "$LIST"
      fi
   done
}
set_ff_mime /etc/xdg/xdg-Lubuntu/mimeapps.list
set_ff_mime "$USER_HOME/.config/mimeapps.list"
set_ff_mime /etc/skel/.config/mimeapps.list
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/mimeapps.list" 2>/dev/null || true
if command -v update-alternatives >/dev/null 2>&1 && [ -x /usr/bin/firefox ] ; then
   update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/firefox 200 \
      >/dev/null 2>&1 || true
   update-alternatives --set x-www-browser /usr/bin/firefox >/dev/null 2>&1 || true
fi
if command -v xdg-settings >/dev/null 2>&1 ; then
   su - "$USER_NAME" -c "xdg-settings set default-web-browser $FF_DESKTOP" \
      >/dev/null 2>&1 || true
fi
echo "FOSSGIS: Firefox set as default browser ($FF_DESKTOP)"

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
