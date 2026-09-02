#!/bin/sh

# readme-index-sync.sh - checks README Index anchors vs SCRIPT --help topics

set -eu

QUIET=0

usage() {
    printf 'Usage: %s [q|-q|quiet|--quiet] [SCRIPT_PATH] [README_PATH]\n' "${0##*/}"
}

while [ "$#" -gt 0 ]; do

    case "$1" in
        q|-q|quiet|--quiet)
            QUIET=1
            ;;
        h|-h|help|--help)

            usage
            
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            printf 'error: unknown option: %s\n' "$1" >&2
            
            usage >&2
            
            exit 2
            ;;
        *)
            break
            ;;
    esac

    shift
done

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
SCRIPT="${1:-$ROOT_DIR/DNdistresS}"
README="${2:-$ROOT_DIR/README.md}"

[ -r "$README" ] || {
    printf 'error: README not readable: %s\n' "$README" >&2
    exit 2
}

[ -r "$SCRIPT" ] || {
    printf 'error: SCRIPT not readable: %s\n' "$SCRIPT" >&2
    exit 2
}

[ -x "$SCRIPT" ] || {
    printf 'error: SCRIPT not executable: %s\n' "$SCRIPT" >&2
    exit 2
}

cli_topics="$(

    "$SCRIPT" --help topics 2>/dev/null | awk '
        /^[[:space:]]+General:/  { sect=1; next }
        /^[[:space:]]+Commands:/ { sect=1; next }
        /^[[:space:]]+Options:/  { sect=1; next }
        /^[[:space:]]+Aliases:/            { sect=0; next }
        /^[[:space:]]+Machine-readable:/   { sect=0; next }

        sect && /^[[:space:]]{4}[[:alnum:] _-]+$/ {

            for (i=1; i<=NF; i++) {
                if ($i ~ /^[a-z][a-z0-9-]*$/) print $i
            }

        }

    ' | awk '!seen[$0]++' | grep -Ev '^(help|general|topics-list)$' || true

)"

index_topics="$(

    awk '
        /^##[[:space:]]+Index[[:space:]]*$/ { in_index=1; next }

        in_index && /^##[[:space:]]+[a-z][a-z0-9-]*[[:space:]]*$/ { exit }

        in_index && /^[[:space:]]*-[[:space:]]+\[[^]]+\]\(#[a-z][a-z0-9-]*\)/ {
            t=$0
            sub(/^.*\(#/, "", t)
            sub(/\).*/, "", t)
            print t
        }

    ' "$README" | awk '!seen[$0]++' \
      | grep -Ev '^(contributing|security|smoke-test-suite|bug-reports|feature-requests|pull-requests)$' || true

)"

failed=0

ok() {

    [ "$QUIET" -eq 1 ] || printf 'ok: %s\n' "$1"

}

not_ok() {
    printf 'not ok: %s\n' "$1" >&2
    failed=1
}

for t in $cli_topics; do

    if ! printf '%s\n' "$index_topics" | grep -Fx -- "$t" >/dev/null 2>&1; then

        not_ok "README index anchor exists for topic: $t"

    else

        ok "README index anchor exists for topic: $t"

    fi

done

for t in $index_topics; do

    if ! printf '%s\n' "$cli_topics" | grep -Fx -- "$t" >/dev/null 2>&1; then

        not_ok "README index anchor maps to SCRIPT topic: $t"

    else

        ok "README index anchor maps to SCRIPT topic: $t"

    fi

done

[ "$failed" -eq 0 ] || exit 1

exit 0
