# Source this file (POSIX sh) to load the FOSSGIS edition settings:
#   . /usr/local/share/gisvm/fossgis/load_edition.sh
# Uses the copy in $FOSSGIS_DIR (default /tmp/fossgis) prepared by
# build_chroot.sh and falls back to the edition.conf of the checkout.
# All variables are exported.

: "${FOSSGIS_DIR:=/tmp/fossgis}"
export FOSSGIS_DIR

set -a
if [ -f "$FOSSGIS_DIR/edition.conf" ] ; then
    . "$FOSSGIS_DIR/edition.conf"
elif [ -f /usr/local/share/gisvm/fossgis/edition.conf ] ; then
    . /usr/local/share/gisvm/fossgis/edition.conf
fi
if [ -f "$FOSSGIS_DIR/local.env" ] ; then
    . "$FOSSGIS_DIR/local.env"
fi
set +a
