#!/bin/sh
#############################################################################
#
# Purpose: Build FOSSGIS edition desktop wallpaper (v3b) and Plymouth
#          watermark from sources under local/artwork/sources/.
#
# Usage:   fossgis/tools/build_wallpaper.sh
#
# Inputs (local/artwork/sources/):
#   heigit-audimax_205_1.jpg
#   fossgis-logo-2027-heidelberg.svg  (preferred) or .png
#
# Outputs:
#   local/artwork/drafts/v3b-audimax205.png
#   local/artwork/fossgis-desktop.png
#   desktop-conf/plymouth/lubuntu-logo/watermark.png
#   desktop-conf/plymouth/lubuntu-logo/lubuntu_logo.png
#
# Layout: 16:9 (1920x1080 and optional HiDPI master), branding inset
# ~110 px from edges, no OSGeoLive corner emblem. WallpaperMode=zoom.
#
#############################################################################

set -eu

TOOLS_DIR=`cd "$(dirname "$0")" && pwd`
PROJECT_DIR=`cd "$TOOLS_DIR/../.." && pwd`
SRC="$PROJECT_DIR/local/artwork/sources"
OUT_DIR="$PROJECT_DIR/local/artwork"
DRAFT_DIR="$OUT_DIR/drafts"
PLYMOUTH_DIR="$PROJECT_DIR/desktop-conf/plymouth/lubuntu-logo"

die() {
   echo "build_wallpaper: ERROR: $*" >&2
   exit 1
}

need_cmd() {
   command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

need_cmd convert
need_cmd identify

PHOTO="$SRC/heigit-audimax_205_1.jpg"
[ -f "$PHOTO" ] || die "missing $PHOTO (copy from conference Artwork/Title/)"

LOGO_SVG="$SRC/fossgis-logo-2027-heidelberg.svg"
LOGO_PNG="$SRC/fossgis-logo-2027-heidelberg.png"
LOGO_TR="$DRAFT_DIR/logo-heidelberg-tr.png"

mkdir -p "$DRAFT_DIR" "$OUT_DIR"

# Transparent circular logo
if [ -f "$LOGO_SVG" ] && command -v inkscape >/dev/null 2>&1 ; then
   inkscape "$LOGO_SVG" \
      --export-type=png --export-filename="$DRAFT_DIR/logo-heidelberg.png" \
      --export-width=900 --export-background-opacity=0 \
      >/dev/null 2>&1 || die "inkscape export failed"
   convert "$DRAFT_DIR/logo-heidelberg.png" -fuzz 8% -transparent black "$LOGO_TR"
elif [ -f "$LOGO_PNG" ] ; then
   convert "$LOGO_PNG" -fuzz 8% -transparent black "$LOGO_TR"
else
   die "missing logo SVG/PNG under $SRC"
fi

# Primary target: Lifebook FHD 1920x1080 (16:9), inset ~110 px
W=1920
H=1080
INSET=110
LOGO_SIZE=420

compose_wallpaper() {
   width="$1"
   height="$2"
   inset="$3"
   logo_px="$4"
   dest="$5"
   convert "$PHOTO" -resize "${width}x${height}^" -gravity center -extent "${width}x${height}" \
      \( -size "${width}x${height}" xc:'rgba(0,0,0,0.18)' \) -compose over -composite \
      \( "$LOGO_TR" -resize "${logo_px}x${logo_px}" \) \
         -gravity southeast -geometry "+${inset}+${inset}" -compose over -composite \
      -font DejaVu-Sans-Bold -pointsize 36 -fill 'rgba(255,255,255,0.95)' \
      -gravity northwest -annotate "+${inset}+$((inset - 10))" 'OSGeoLive 17 · FOSSGIS 2027' \
      -font DejaVu-Sans -pointsize 22 -fill '#ee7f00' \
      -annotate "+${inset}+$((inset + 38))" 'Heidelberg Edition' \
      -quality 92 "$dest"
}

compose_wallpaper "$W" "$H" "$INSET" "$LOGO_SIZE" "$DRAFT_DIR/v3b-audimax205.png"
cp "$DRAFT_DIR/v3b-audimax205.png" "$OUT_DIR/fossgis-desktop.png"

# Optional sharper master for HiDPI (same relative insets)
compose_wallpaper 2880 1620 165 630 "$DRAFT_DIR/v3b-audimax205-2880.png"

# Plymouth watermark / lubuntu_logo (banner)
mkdir -p "$PLYMOUTH_DIR"
convert -size 480x72 xc:none \
   \( "$LOGO_TR" -resize 60x60 \) -gravity west -geometry +8+0 -compose over -composite \
   -font DejaVu-Sans-Bold -pointsize 22 -fill white \
   -gravity west -annotate +80+0 'FOSSGIS 2027 Edition' \
   "$PLYMOUTH_DIR/watermark.png"
cp "$PLYMOUTH_DIR/watermark.png" "$PLYMOUTH_DIR/lubuntu_logo.png"

echo "build_wallpaper: wrote $DRAFT_DIR/v3b-audimax205.png"
echo "build_wallpaper: wrote $OUT_DIR/fossgis-desktop.png"
echo "build_wallpaper: wrote $PLYMOUTH_DIR/watermark.png"
identify "$OUT_DIR/fossgis-desktop.png" "$PLYMOUTH_DIR/watermark.png"
