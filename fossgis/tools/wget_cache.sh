#!/bin/bash
#############################################################################
#
# Purpose: FOSSGIS wget cache wrapper.
#          build_chroot.sh installs it as /usr/local/bin/wget in the chroot
#          for the duration of the build; setdown.sh removes it again.
#          Downloads are served from the local cache (local/cache/downloads
#          on the host, mounted at /var/cache/fossgis-downloads) and new
#          successful downloads are stored there as <host>/<path>.
#          Calls it does not fully understand (several URLs, query strings,
#          output to stdout, unknown options) go to the real wget unchanged.
#
# Environment:
#   FOSSGIS_CACHE_REFRESH=1   download again and replace cached files
#   FOSSGIS_REAL_WGET         real wget (default /usr/bin/wget)
#   FOSSGIS_DOWNLOAD_CACHE    cache directory (default /var/cache/fossgis-downloads)
#
#############################################################################

REAL_WGET="${FOSSGIS_REAL_WGET:-/usr/bin/wget}"
CACHE_DIR="${FOSSGIS_DOWNLOAD_CACHE:-/var/cache/fossgis-downloads}"

passthrough() {
    exec "$REAL_WGET" "$@"
}

if [ ! -d "$CACHE_DIR" ] || [ ! -w "$CACHE_DIR" ] ; then
    passthrough "$@"
fi

args=("$@")
urls=()
output=""
prefix="."
force_dirs=0
i=0
while [ "$i" -lt "${#args[@]}" ] ; do
    a="${args[$i]}"
    case "$a" in
        http://*|https://*|ftp://*) urls+=("$a") ;;
        -O) i=$((i + 1)) ; output="${args[$i]}" ;;
        -O?*) output="${a#-O}" ;;
        --output-document=*) output="${a#*=}" ;;
        -P) i=$((i + 1)) ; prefix="${args[$i]}" ;;
        --directory-prefix=*) prefix="${a#*=}" ;;
        -x|--force-directories) force_dirs=1 ;;
        -t) i=$((i + 1)) ;;
        -c|--continue|-N|--timestamping|-nv|--no-verbose|-q|--quiet) ;;
        --progress=*|--tries=*|--no-check-certificate) ;;
        *) passthrough "$@" ;;
    esac
    i=$((i + 1))
done

[ "${#urls[@]}" -eq 1 ] || passthrough "$@"
url="${urls[0]}"
[ "$output" = "-" ] && passthrough "$@"

rest="${url#*://}"
host="${rest%%/*}"
path="${rest#"$host"}"
case "$path" in
    ""|*/|*\?*|*#*|*%*|*/../*|*/./*) passthrough "$@" ;;
esac
case "$host" in
    ""|*..*|*/*) passthrough "$@" ;;
esac
cache_file="$CACHE_DIR/$host$path"

if [ -n "$output" ] ; then
    target="$output"
elif [ "$force_dirs" -eq 1 ] ; then
    target="$prefix/$host$path"
else
    target="$prefix/${path##*/}"
fi

if [ "$FOSSGIS_CACHE_REFRESH" != "1" ] && [ -s "$cache_file" ] ; then
    mkdir -p "$(dirname "$target")" || exit 1
    cp -p "$cache_file" "$target" || exit 1
    echo "wget-cache: hit $url -> $target" >&2
    exit 0
fi

"$REAL_WGET" "$@"
rc=$?
if [ "$rc" -eq 0 ] && [ -s "$target" ] ; then
    if mkdir -p "$(dirname "$cache_file")" && \
       cp -p "$target" "$cache_file.part.$$" && \
       mv -f "$cache_file.part.$$" "$cache_file" ; then
        echo "wget-cache: stored $url" >&2
    else
        rm -f "$cache_file.part.$$"
        echo "wget-cache: could not store $url" >&2
    fi
fi
exit "$rc"
