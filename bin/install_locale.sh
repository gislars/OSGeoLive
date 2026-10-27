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

apt-get install --yes \
   language-pack-de language-pack-de-base language-pack-gnome-de \
   qt6-translations-l10n manpages-de \
   hunspell-de-de aspell-de hyphen-de mythes-de \
   console-setup firefox-locale-de \
   gnome-keyring libpam-gnome-keyring

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

# Firefox prefers German
mkdir -p /etc/firefox/policies
cat > /etc/firefox/policies/policies.json << EOF
{
  "policies": {
    "RequestedLocales": ["de"]
  }
}
EOF

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
