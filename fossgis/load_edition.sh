# Source this file (POSIX sh) to load the FOSSGIS edition settings:
#   . /usr/local/share/gisvm/fossgis/load_edition.sh
# Uses the copy in $FOSSGIS_DIR prepared by build_chroot.sh and falls back
# to the edition.conf of the checkout. Default is under gisvm (not /tmp):
# systemd-nspawn mounts a tmpfs on /tmp from the live fstab.
# All variables are exported.

: "${FOSSGIS_DIR:=/usr/local/share/gisvm/fossgis-local}"
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
