#!/bin/sh
# Prepare FOSSGIS OSM extracts on the build host before a VM build.
# Reads fossgis/edition.conf (and optional local/local.env overrides).
# Writes into local/data/osm/:
#   <MAP_CITY>.osm.pbf   primary extract (relation boundary)
#   <MAP_CITY>.osm       OSM XML for osm2pgrouting (not shipped in the ISO)
#   <MAP_CITY>.stamp     SHA-256 of the PBF that produced the XML
#
# Idempotent: wget -N for the source PBF; extract/XML only when the source
# or relation changes (stamp mismatch or missing outputs).

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

. "$ROOT_DIR/fossgis/edition.conf"
if [ -f "$ROOT_DIR/local/local.env" ] ; then
   # shellcheck disable=SC1091
   . "$ROOT_DIR/local/local.env"
fi

: "${MAP_CITY:?MAP_CITY missing in edition.conf}"
: "${OSM_RELATION:?OSM_RELATION missing in edition.conf}"
: "${OSM_SOURCE_PBF_URL:?OSM_SOURCE_PBF_URL missing in edition.conf}"

OUT_DIR="$ROOT_DIR/local/data/osm"
mkdir -p "$OUT_DIR"

SOURCE_NAME=$(basename "$OSM_SOURCE_PBF_URL")
SOURCE_PBF="$OUT_DIR/$SOURCE_NAME"
CITY_PBF="$OUT_DIR/${MAP_CITY}.osm.pbf"
CITY_OSM="$OUT_DIR/${MAP_CITY}.osm"
CITY_STAMP="$OUT_DIR/${MAP_CITY}.stamp"

EXTRACT_PY="$ROOT_DIR/bin/extract_osm_by_relation.py"

need_cmd() {
   command -v "$1" >/dev/null 2>&1 || {
      echo "prepare_data: missing command '$1' (install osmium-tool and gdal-bin)" >&2
      exit 1
   }
}
need_cmd wget
need_cmd osmium
need_cmd ogr2ogr
need_cmd python3
need_cmd sha256sum

echo "prepare_data: source $OSM_SOURCE_PBF_URL"
wget -N --progress=dot:mega -P "$OUT_DIR" "$OSM_SOURCE_PBF_URL"

SOURCE_SHA=$(sha256sum "$SOURCE_PBF" | awk '{print $1}')
STAMP_OK=0
if [ -f "$CITY_STAMP" ] && [ -f "$CITY_PBF" ] && [ -f "$CITY_OSM" ] ; then
   EXPECTED=$(awk '{print $1}' "$CITY_STAMP")
   ACTUAL=$(sha256sum "$CITY_PBF" | awk '{print $1}')
   # stamp line 1 = sha of city pbf; line 2 = sha of source used
   SOURCE_IN_STAMP=$(awk 'NR==2 {print $1}' "$CITY_STAMP")
   if [ "$EXPECTED" = "$ACTUAL" ] && [ "$SOURCE_IN_STAMP" = "$SOURCE_SHA" ] ; then
      STAMP_OK=1
   fi
fi

if [ "$STAMP_OK" -eq 1 ] ; then
   echo "prepare_data: $MAP_CITY extract up to date, nothing to do"
   exit 0
fi

echo "prepare_data: extract relation $OSM_RELATION -> $CITY_PBF"
python3 "$EXTRACT_PY" \
   --relation "$OSM_RELATION" \
   --pbf "$SOURCE_PBF" \
   --format pbf \
   --output "$CITY_PBF"

echo "prepare_data: write OSM XML for osm2pgrouting -> $CITY_OSM"
osmium cat "$CITY_PBF" -o "$CITY_OSM" -f xml --overwrite

CITY_SHA=$(sha256sum "$CITY_PBF" | awk '{print $1}')
{
   echo "$CITY_SHA  ${MAP_CITY}.osm.pbf"
   echo "$SOURCE_SHA  $SOURCE_NAME"
   echo "relation=$OSM_RELATION"
} > "$CITY_STAMP"

echo "prepare_data: wrote $CITY_PBF, $CITY_OSM, $CITY_STAMP"
ls -lh "$CITY_PBF" "$CITY_OSM" "$CITY_STAMP"
