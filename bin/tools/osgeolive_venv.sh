#!/bin/sh
#############################################################################
#
# Purpose: Shared Python venv for packages missing from Ubuntu 26.04.
#          Source from install scripts: . "$BUILD_DIR/tools/osgeolive_venv.sh"
#
#############################################################################

OSGEOLIVE_VENV="${OSGEOLIVE_VENV:-/opt/osgeolive-venv}"

osgeolive_venv_ensure() {
   if [ -x "$OSGEOLIVE_VENV/bin/python" ] ; then
      return 0
   fi
   apt-get install --yes --no-install-recommends python3-venv python3-pip
   python3 -m venv "$OSGEOLIVE_VENV"
   "$OSGEOLIVE_VENV/bin/pip" install --upgrade pip wheel
}

osgeolive_venv_pip() {
   osgeolive_venv_ensure || return 1
   "$OSGEOLIVE_VENV/bin/pip" install "$@"
}

osgeolive_venv_bin() {
   echo "$OSGEOLIVE_VENV/bin/$1"
}
