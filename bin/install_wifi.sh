#!/bin/sh
#############################################################################
#
# Purpose: Optional venue WLAN profile from local.env (FOSSGIS)
#
#############################################################################
# Copyright (c) 2026 FOSSGIS e.V. and others.
# Licensed under the GNU LGPL version >= 2.1.
#############################################################################

./diskspace_probe.sh "`basename $0`" begin
BUILD_DIR=`pwd`
####

# Values come from load_edition.sh (edition.conf + local/local.env)
if [ -z "${WIFI_SSID:-}" ] || [ -z "${WIFI_PSK:-}" ] ; then
   echo "FOSSGIS: WIFI_SSID/WIFI_PSK not set, skipping WLAN profile"
   "$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
   exit 0
fi

KEY_MGMT="${WIFI_KEY_MGMT:-wpa-psk}"
case "$KEY_MGMT" in
   wpa-psk|sae) ;;
   *)
      echo "ERROR: WIFI_KEY_MGMT must be wpa-psk or sae (got: $KEY_MGMT)" >&2
      exit 1
      ;;
esac

CONN_DIR="/etc/NetworkManager/system-connections"
mkdir -p "$CONN_DIR"
CONN_FILE="$CONN_DIR/fossgis.nmconnection"

# UUID stays stable across rebuilds for the same SSID
UUID=$(printf '%s' "$WIFI_SSID" | md5sum | awk '{print $1}')
UUID=$(printf '%s-%s-%s-%s-%s' \
   "$(echo "$UUID" | cut -c1-8)" \
   "$(echo "$UUID" | cut -c9-12)" \
   "$(echo "$UUID" | cut -c13-16)" \
   "$(echo "$UUID" | cut -c17-20)" \
   "$(echo "$UUID" | cut -c21-32)")

umask 077
cat > "$CONN_FILE" << EOF
[connection]
id=FOSSGIS
uuid=$UUID
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
key-mgmt=$KEY_MGMT
psk=$WIFI_PSK

[ipv4]
method=auto

[ipv6]
method=auto
EOF
chmod 600 "$CONN_FILE"
echo "FOSSGIS: wrote WLAN profile $CONN_FILE (ssid=$WIFI_SSID, key-mgmt=$KEY_MGMT)"
echo "FOSSGIS: WARNING: the PSK is stored in the ISO; use a workshop-only network"

####
"$BUILD_DIR"/diskspace_probe.sh "`basename $0`" end
