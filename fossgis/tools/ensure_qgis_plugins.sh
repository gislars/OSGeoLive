#!/bin/sh
#############################################################################
#
# Purpose: Before an ISO build, refresh QGIS plugin pins from plugins.qgis.org
#          (cached) and rebuild local/data/qgis/qgis4-osgeolive-plugins.zip
#          only when plugin versions changed or the ZIP is missing/stale.
#          Otherwise reuse the existing ZIP.
#
# Usage:   ensure_qgis_plugins.sh [--force]
#          --force  pass through to update_qgis_plugins.py (ignore XML TTL)
#
# Called from builder_vm.sh build on the host. The ZIP under local/ is what
# install_qgis.sh unpacks; git may still have an older pins.json until commit.
#
#############################################################################

set -eu

TOOLS_DIR=`cd "$(dirname "$0")" && pwd`
REPO_ROOT=`cd "$TOOLS_DIR/../.." && pwd`
PINS="$TOOLS_DIR/qgis_plugins_pins.json"
ZIP_DIR="$REPO_ROOT/local/data/qgis"
ZIP="$ZIP_DIR/qgis4-osgeolive-plugins.zip"
STAMP="$ZIP_DIR/qgis4-osgeolive-plugins.stamp"

FORCE_ARGS=""
for ARG in "$@" ; do
   case "$ARG" in
   --force) FORCE_ARGS="--force" ;;
   -h|--help)
      echo "Usage: ensure_qgis_plugins.sh [--force]"
      exit 0
      ;;
   *)
      echo "Usage: ensure_qgis_plugins.sh [--force]" >&2
      exit 2
      ;;
   esac
done

plugins_hash() {
   python3 -c '
import hashlib, json, sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
plugins = data.get("plugins") or {}
blob = json.dumps(plugins, sort_keys=True, ensure_ascii=False).encode("utf-8")
print(hashlib.sha256(blob).hexdigest())
' "$1"
}

[ -f "$PINS" ] || {
   echo "ensure_qgis_plugins: missing $PINS" >&2
   exit 1
}

echo "ensure_qgis_plugins: checking pins against plugins.qgis.org ..."
BEFORE=`plugins_hash "$PINS"`
python3 "$TOOLS_DIR/update_qgis_plugins.py" $FORCE_ARGS
AFTER=`plugins_hash "$PINS"`

NEED_ZIP=0
if [ ! -f "$ZIP" ] ; then
   echo "ensure_qgis_plugins: ZIP missing, will build."
   NEED_ZIP=1
elif [ "$BEFORE" != "$AFTER" ] ; then
   echo "ensure_qgis_plugins: plugin versions changed, will rebuild ZIP."
   NEED_ZIP=1
elif [ ! -f "$STAMP" ] ; then
   echo "ensure_qgis_plugins: no stamp for existing ZIP, will rebuild once."
   NEED_ZIP=1
elif [ "`cat "$STAMP"`" != "$AFTER" ] ; then
   echo "ensure_qgis_plugins: ZIP stamp outdated, will rebuild."
   NEED_ZIP=1
fi

if [ "$NEED_ZIP" -eq 0 ] ; then
   echo "ensure_qgis_plugins: pins unchanged, reusing $ZIP"
   exit 0
fi

echo "ensure_qgis_plugins: building $ZIP ..."
python3 "$TOOLS_DIR/build_qgis_plugins_zip.py"
mkdir -p "$ZIP_DIR"
echo "$AFTER" > "$STAMP"
echo "ensure_qgis_plugins: done (stamp=$AFTER)."
