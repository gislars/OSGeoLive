#!/bin/bash
#############################################################################
#
# Purpose: Verify that commits are clean before they leave the local
#          repository: secrets, forbidden paths and file sizes, whitespace,
#          shell/python syntax, authorship, merge rules on master and the
#          record of the last full build.
#
# Usage:   check_clean.sh [options] <from>..<to>
#          check_clean.sh [options] <ref>     commits of <ref> not on any remote
#          check_clean.sh --all               master and the archive branches
#          check_clean.sh --push <remote_ref> <local_sha> <remote_sha>
#                                             (used by the pre-push hook)
#
# Options: --archive             archive branch: syntax, author and subject
#                                checks only report, they do not fail
#          --master              master rules: topic merges with "Tested:"
#                                trailer and upstream-diff.md entry after the
#                                tag fossgis2027-base
#          --require-full-build  build/last-full-build.txt must name <to>
#                                with result=green
#
# Allow lists (next to this script):
#   check_clean.allow  "line:<ERE>" ignores matching added lines,
#                      "path:<ERE>" ignores keyword hits in matching paths.
#                      Values from local.env and local *.nmconnection files
#                      are never ignored.
#   check_clean.large  paths of files between 10 MB and 100 MB that may be
#                      committed.
#
#############################################################################

set -u

AUTHOR="gislars <lars@lingner.eu>"
BASE_TAG="fossgis2027-base"
UPSTREAM_DOC="docs/fossgis/upstream-diff.md"
BUILD_DIRS_ERE='^(bin|app-conf|desktop-conf|sources\.list\.d|fossgis)/'
# matched against the lower-cased line: assignments only, so prose such as
# "passwords.txt" or "getent passwd" does not count
SECRET_ERE='(psk|passw(or)?d|token|secret|api[_-]?key)[a-z0-9_]*["'"'"']?[[:space:]]*(:|=)|begin [a-z ]*private key'
MAX_SIZE=$((100 * 1024 * 1024))
LARGE_SIZE=$((10 * 1024 * 1024))

# main checkout, also when running inside a linked worktree
GIT_COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir) || exit 2
TOP=$(dirname "$GIT_COMMON_DIR")
TOOLS_DIR=$(cd "$(dirname "$0")" && pwd)
ALLOW_FILE="$TOOLS_DIR/check_clean.allow"
LARGE_FILE="$TOOLS_DIR/check_clean.large"
BUILD_RECORD="$TOP/build/last-full-build.txt"

ARCHIVE=0
MASTER=0
REQUIRE_BUILD=0
RANGE=""
LABEL=""

usage() {
    sed -n '/^# Usage:/,/^# Allow lists/p' "$0" | sed '$d; s/^# \{0,1\}//'
    exit 2
}

while [ "$#" -gt 0 ] ; do
    case "$1" in
        --archive) ARCHIVE=1 ;;
        --master) MASTER=1 ;;
        --require-full-build) REQUIRE_BUILD=1 ;;
        --all)
            rc=0
            "$0" --master master || rc=1
            for ref in $(git for-each-ref --format='%(refname:short)' 'refs/heads/fossgis20[0-9][0-9]') ; do
                "$0" --archive "$ref" || rc=1
            done
            exit "$rc"
            ;;
        --push)
            [ "$#" -eq 4 ] || usage
            case "$2" in
                refs/heads/fossgis20[0-9][0-9]) ARCHIVE=1 ;;
                refs/heads/master) MASTER=1 ; REQUIRE_BUILD=1 ;;
            esac
            RANGE="$3"
            LABEL="push $2"
            shift 3
            ;;
        -h|--help) usage ;;
        -*) usage ;;
        *) [ -z "$RANGE" ] || usage ; RANGE="$1" ;;
    esac
    shift
done
[ -n "$RANGE" ] || usage

case "$RANGE" in
    *..*)
        TIP=$(git rev-parse --verify -q "${RANGE#*..}^{commit}") || { echo "unknown revision: $RANGE" >&2 ; exit 2 ; }
        set -- "$RANGE"
        ;;
    *)
        TIP=$(git rev-parse --verify -q "$RANGE^{commit}") || { echo "unknown revision: $RANGE" >&2 ; exit 2 ; }
        set -- "$TIP" --not --remotes
        ;;
esac
[ -n "$LABEL" ] || LABEL="$RANGE"

FAILS=0
WARNS=0
fail() { echo "FAIL: $*" ; FAILS=$((FAILS + 1)) ; }
warn() { echo "WARN: $*" ; WARNS=$((WARNS + 1)) ; }
strict() { if [ "$ARCHIVE" -eq 1 ] ; then warn "$@" ; else fail "$@" ; fi ; }

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Allow list patterns
: > "$TMP_DIR/allow_line"
: > "$TMP_DIR/allow_path"
if [ -f "$ALLOW_FILE" ] ; then
    sed -n 's/^line://p' "$ALLOW_FILE" > "$TMP_DIR/allow_line"
    sed -n 's/^path://p' "$ALLOW_FILE" > "$TMP_DIR/allow_path"
fi
matches_any() {
    [ -s "$2" ] && printf '%s\n' "$1" | grep -q -E -f "$2"
}
is_large_allowed() {
    [ -f "$LARGE_FILE" ] && grep -v '^#' "$LARGE_FILE" | grep -q -x -F -- "$1"
}

# Known secret values, never printed
{
    for env_file in "$TOP/local/local.env" "$TOP/local.env" ; do
        [ -f "$env_file" ] || continue
        sed -n -E 's/^[[:space:]]*(export[[:space:]]+)?[A-Za-z0-9_]*(PSK|PASS|PASSWORD|SSID|TOKEN|SECRET|KEY)[A-Za-z0-9_]*=//p' "$env_file"
    done
    find "$TOP/local" "$TOP/osgeolive_old" -maxdepth 4 -name '*.nmconnection' -type f 2>/dev/null | \
    while IFS= read -r nm_file ; do
        sed -n -E 's/^(psk|password|ssid)=//p' "$nm_file"
    done
} | sed -E "s/\r$//; s/^[\"']//; s/[\"'][[:space:]]*$//" | awk 'length($0) >= 6' | sort -u > "$TMP_DIR/secrets"

# Print added lines of a diff as "path<TAB>line"
added_lines() {
    awk '/^\+\+\+ / { f = substr($0, 5); sub(/^b\//, "", f); next }
         /^\+/ { print f "\t" substr($0, 2) }'
}

declare -A CHANGED=()
COUNT=0

check_commit() {
    local c="$1" short subject author committer nparents meta path sha mode size hit_path hit_line
    short=$(git rev-parse --short "$c")
    subject=$(git log -1 --format=%s "$c")
    author=$(git log -1 --format='%an <%ae>' "$c")
    committer=$(git log -1 --format='%cn <%ce>' "$c")
    nparents=$(($(git rev-list --parents -n 1 "$c" | wc -w) - 1))

    [ "$author" = "$AUTHOR" ] || strict "$short: author is '$author'"
    [ "$committer" = "$AUTHOR" ] || strict "$short: committer is '$committer'"
    case "$subject" in
        WIP*|wip*|fixup!*|squash!*) strict "$short: subject '$subject'" ;;
    esac

    if [ "$nparents" -gt 1 ] ; then
        git show --remerge-diff --format= --no-color --no-ext-diff -U0 "$c" | added_lines > "$TMP_DIR/added"
    else
        git show --format= --no-color --no-ext-diff -U0 "$c" | added_lines > "$TMP_DIR/added"
    fi
    git log -1 --format=%B "$c" | sed 's/^/COMMIT_MSG\t/' >> "$TMP_DIR/added"

    # 1. secrets
    if [ -s "$TMP_DIR/secrets" ] && grep -q -F -f "$TMP_DIR/secrets" "$TMP_DIR/added" ; then
        fail "$short: contains a value from local.env or a local *.nmconnection in: $(grep -F -f "$TMP_DIR/secrets" "$TMP_DIR/added" | cut -f1 | sort -u | tr '\n' ' ')"
    fi
    while IFS=$'\t' read -r hit_path hit_line ; do
        matches_any "$hit_path" "$TMP_DIR/allow_path" && continue
        matches_any "$hit_line" "$TMP_DIR/allow_line" && continue
        fail "$short: possible secret in $hit_path: $(printf '%s' "$hit_line" | cut -c1-120)"
    done < <(awk -v pat="$SECRET_ERE" 'tolower(substr($0, index($0, "\t") + 1)) ~ pat' "$TMP_DIR/added")

    [ "$nparents" -gt 1 ] && return 0

    # 2. paths and sizes
    while IFS= read -r -d '' meta && IFS= read -r -d '' path ; do
        mode=$(echo "$meta" | cut -d' ' -f2)
        sha=$(echo "$meta" | cut -d' ' -f4)
        CHANGED["$path"]=1
        case "$path" in
            local/*|build/*|osgeolive_old/*) fail "$short: local-only path $path" ;;
        esac
        case "${path##*/}" in
            workarounds*.md) fail "$short: workaround notes must stay local: $path" ;;
            *.pbf|*.iso) fail "$short: data file must stay local: $path" ;;
            *.nmconnection|local.env) fail "$short: secret file: $path" ;;
        esac
        [ "$mode" = "160000" ] && continue
        size=$(git cat-file -s "$sha")
        if [ "$size" -gt "$MAX_SIZE" ] ; then
            fail "$short: $path is larger than 100 MB ($size bytes)"
        elif [ "$size" -gt "$LARGE_SIZE" ] && ! is_large_allowed "$path" ; then
            fail "$short: $path is larger than 10 MB ($size bytes) and not in check_clean.large"
        fi
    done < <(git diff-tree -r -z --root --no-commit-id --no-renames --diff-filter=AM "$c")

    # 3. conflict markers and whitespace errors
    if ! git show --check --format= --no-color "$c" > "$TMP_DIR/check" 2>&1 ; then
        grep -E ':[0-9]+: ' "$TMP_DIR/check" > "$TMP_DIR/check_msgs"
        if grep -q 'conflict marker' "$TMP_DIR/check_msgs" ; then
            fail "$short: leftover conflict markers:"
            grep 'conflict marker' "$TMP_DIR/check_msgs" | sed -n 's/^/      /; 1,10p'
        fi
        if grep -v -q 'conflict marker' "$TMP_DIR/check_msgs" ; then
            strict "$short: whitespace errors ($(grep -v -c 'conflict marker' "$TMP_DIR/check_msgs") lines, git diff --check):"
            grep -v 'conflict marker' "$TMP_DIR/check_msgs" | sed -n 's/^/      /; 1,5p'
        fi
    fi
}

while read -r c ; do
    [ -n "$c" ] || continue
    COUNT=$((COUNT + 1))
    check_commit "$c"
done < <(git rev-list --reverse "$@")

# 3. syntax of changed scripts as they are at the tip
for path in "${!CHANGED[@]}" ; do
    case "$path" in
        *.sh|*.py) ;;
        *) continue ;;
    esac
    git cat-file -e "$TIP:$path" 2>/dev/null || continue
    file="$TMP_DIR/syntax/${path//\//__}"
    mkdir -p "$TMP_DIR/syntax"
    git show "$TIP:$path" > "$file"
    case "$path" in
        *.sh)
            first=$(head -n 1 "$file")
            case "$first" in
                *bash*) shell="bash" ;;
                *) shell="sh" ;;
            esac
            if ! "$shell" -n "$file" 2> "$TMP_DIR/err" ; then
                strict "$path: $shell -n: $(head -n 3 "$TMP_DIR/err" | tr '\n' ' ')"
            fi
            if command -v shellcheck > /dev/null ; then
                case "$first" in
                    '#!'*) sc_shell="" ;;
                    *) sc_shell="--shell=sh" ;;
                esac
                # shellcheck disable=SC2086
                if ! shellcheck -S error $sc_shell "$file" > "$TMP_DIR/err" 2>&1 ; then
                    strict "$path: shellcheck errors:"
                    sed -n "s|$file|$path|g; s/^/      /; 1,20p" "$TMP_DIR/err"
                fi
            fi
            ;;
        *.py)
            if ! python3 -m py_compile "$file" 2> "$TMP_DIR/err" ; then
                strict "$path: py_compile: $(tail -n 2 "$TMP_DIR/err" | tr '\n' ' ')"
            fi
            ;;
    esac
done

# 4. merge rules on master
if [ "$MASTER" -eq 1 ] ; then
    if ! git rev-parse -q --verify "refs/tags/$BASE_TAG" > /dev/null ; then
        echo "NOTE: tag $BASE_TAG does not exist yet, merge rules skipped"
    else
        while read -r c ; do
            [ -n "$c" ] || continue
            git merge-base --is-ancestor "$c" "$BASE_TAG" && continue
            short=$(git rev-parse --short "$c")
            if [ "$(($(git rev-list --parents -n 1 "$c" | wc -w) - 1))" -lt 2 ] ; then
                fail "$short: direct commit on master after $BASE_TAG, use a topic branch and merge --no-ff"
                continue
            fi
            if [ -z "$(git log -1 --format='%(trailers:key=Tested,valueonly)' "$c")" ] ; then
                fail "$short: merge without 'Tested:' trailer"
            fi
            changed=$(git diff --name-only "$c^1" "$c")
            if printf '%s\n' "$changed" | grep -q -E "$BUILD_DIRS_ERE" && \
               ! printf '%s\n' "$changed" | grep -q -x -F "$UPSTREAM_DOC" ; then
                fail "$short: merge changes the build but not $UPSTREAM_DOC"
            fi
        done < <(git rev-list --first-parent "$@")
    fi
fi

# 5. full build record
if [ "$REQUIRE_BUILD" -eq 1 ] ; then
    if [ ! -f "$BUILD_RECORD" ] ; then
        fail "no full build record ($BUILD_RECORD)"
    else
        rec_commit=$(sed -n 's/^commit=//p' "$BUILD_RECORD")
        rec_result=$(sed -n 's/^result=//p' "$BUILD_RECORD")
        [ "$rec_commit" = "$TIP" ] || fail "last full build was for ${rec_commit:-?}, not for $TIP"
        [ "$rec_result" = "green" ] || fail "last full build result is '${rec_result:-?}', not green"
    fi
fi

MODE="topic"
[ "$MASTER" -eq 1 ] && MODE="master"
[ "$ARCHIVE" -eq 1 ] && MODE="archive"
echo "check_clean: $LABEL ($MODE): $COUNT commits, $FAILS failures, $WARNS warnings"
[ "$FAILS" -eq 0 ]
