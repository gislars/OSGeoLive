#!/bin/sh
# Build FOSSGIS offline documentation into local/data/docs/html.
# Runs Sphinx inside ubuntu:24.04 (Sphinx 4.3.2 from requirements.txt does not
# target the host Python 3.14 on Lubuntu 26.04).
#
# Usage: fossgis/build_docs.sh
# Requires: docker, osgeolive-doc/ checkout, network for the first image pull.

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DOC_DIR="$ROOT_DIR/osgeolive-doc"
OUT_DIR="$ROOT_DIR/local/data/docs/html"
REQ_FILE="$DOC_DIR/requirements.txt"

if [ ! -d "$DOC_DIR/.git" ] ; then
   echo "build_docs: missing $DOC_DIR (clone git@github.com:gislars/OSGeoLive-doc.git)" >&2
   exit 1
fi
if [ ! -f "$REQ_FILE" ] ; then
   echo "build_docs: missing $REQ_FILE" >&2
   exit 1
fi
if ! command -v docker >/dev/null 2>&1 ; then
   echo "build_docs: docker is required" >&2
   exit 1
fi

DOCS_COMMIT=$(git -C "$DOC_DIR" rev-parse HEAD)
mkdir -p "$OUT_DIR"
find "$OUT_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

echo "build_docs: building $DOCS_COMMIT (de + en) -> $OUT_DIR"

docker run --rm \
   -v "$DOC_DIR:/docs:rw" \
   -v "$OUT_DIR:/out:rw" \
   -w /docs \
   ubuntu:24.04 \
   bash -lc '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3 python3-venv python3-pip cmake make \
   gettext git ca-certificates cpanminus build-essential
cpanm --quiet --notest Text::SimpleTable::AutoWidth
python3 -m venv /tmp/doc-venv
. /tmp/doc-venv/bin/activate
pip install -q -U pip wheel
# Sphinx 4.3 still imports pkg_resources; pin setuptools that still ships it
pip install -q setuptools==69.5.1
pip install -q -r requirements.txt Pillow
rm -rf /tmp/doc-build
mkdir -p /tmp/doc-build
cmake -S /docs -B /tmp/doc-build -DHTML=ON -DDE=ON
cmake --build /tmp/doc-build -j"$(nproc)"
# Sphinx writes to <build>/_build/html/{en,de} (see cmake doc target)
HTML_ROOT=""
for CAND in /tmp/doc-build/_build/html /tmp/doc-build/doc/_build/html ; do
   if [ -d "$CAND" ] ; then
      HTML_ROOT="$CAND"
      break
   fi
done
if [ -z "$HTML_ROOT" ] ; then
   echo "build_docs: sphinx html output not found" >&2
   find /tmp/doc-build -type d -name html 2>/dev/null | head -20 >&2 || true
   exit 1
fi
cp -a "$HTML_ROOT"/. /out/
'

printf '%s\n' "$DOCS_COMMIT" > "$ROOT_DIR/local/data/docs/COMMIT"
echo "build_docs: done (COMMIT=$DOCS_COMMIT)"
ls -la "$OUT_DIR" | head -20
