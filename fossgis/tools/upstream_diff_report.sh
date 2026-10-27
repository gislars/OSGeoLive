#!/bin/sh
#############################################################################
#
# Purpose: Cross-check docs/fossgis/upstream-diff.md against the actual
#          difference between the fork and OSGeo upstream.
#          Lists the diffstat, all merges on master since the upstream base
#          and every changed file that the document does not mention (by
#          path or by one of its parent directories followed by "/").
#
# Usage:   upstream_diff_report.sh [upstream (default osgeo/master)] [branch (default master)]
#
#############################################################################

UPSTREAM="${1:-osgeo/master}"
BRANCH="${2:-master}"
DOC="docs/fossgis/upstream-diff.md"

git rev-parse -q --verify "$UPSTREAM^{commit}" > /dev/null || { echo "unknown revision: $UPSTREAM" >&2 ; exit 2 ; }
git rev-parse -q --verify "$BRANCH^{commit}" > /dev/null || { echo "unknown revision: $BRANCH" >&2 ; exit 2 ; }

BASE=$(git merge-base "$UPSTREAM" "$BRANCH")
echo "Upstream:   $UPSTREAM $(git rev-parse --short "$UPSTREAM")"
echo "Merge base: $(git log -1 --format='%h %ad %s' --date=short "$BASE")"
echo "Branch:     $BRANCH $(git describe --long --tags "$BRANCH" 2>/dev/null)"
echo "Upstream commits not yet merged: $(git rev-list --count "$BRANCH..$UPSTREAM")"
echo

echo "== Changed files ($UPSTREAM...$BRANCH)"
git diff --stat=100 "$UPSTREAM...$BRANCH" | cat
echo

echo "== Merges on $BRANCH since the merge base"
git log --first-parent --merges --format='%h %ad %s' --date=short "$BASE..$BRANCH" | cat
echo

if ! git cat-file -e "$BRANCH:$DOC" 2>/dev/null ; then
    echo "$DOC does not exist on $BRANCH"
    exit 1
fi
git show "$BRANCH:$DOC" > "${TMPDIR:-/tmp}/upstream-diff.$$"
DOC_COPY="${TMPDIR:-/tmp}/upstream-diff.$$"

echo "== Changed files not mentioned in $DOC"
missing=0
for path in $(git diff --name-only "$UPSTREAM...$BRANCH") ; do
    found=0
    grep -q -F -- "\`$path\`" "$DOC_COPY" && found=1
    parent="$path"
    while [ "$found" -eq 0 ] && [ "${parent%/*}" != "$parent" ] ; do
        parent="${parent%/*}"
        grep -q -F -- "\`$parent/\`" "$DOC_COPY" && found=1
    done
    if [ "$found" -eq 0 ] ; then
        echo "  $path"
        missing=$((missing + 1))
    fi
done
rm -f "$DOC_COPY"
[ "$missing" -eq 0 ] && echo "  none"
[ "$missing" -eq 0 ]
