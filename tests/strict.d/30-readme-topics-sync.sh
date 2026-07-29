#!/bin/sh

# readme-topics-sync.sh - checks README topic headings vs CLI --help topics.

set -eu

QUIET=0

usage() {
    printf 'Usage: %s [q|-q|quiet|--quiet] [SCRIPT_PATH]\n' "${0##*/}"
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
CLI="${1:-$ROOT_DIR/DNdistresS}"
README="${2:-$ROOT_DIR/README.md}"

[ -x "$CLI" ] || { printf 'error: CLI not executable: %s\n' "$CLI" >&2; exit 2; }

[ -r "$README" ] || { printf 'error: README not readable: %s\n' "$README" >&2; exit 2; }

cli_topics="$(

    "$CLI" --help topics 2>/dev/null | awk '
        /^[[:space:]]+General:/  { sect=1; next }
        /^[[:space:]]+Commands:/ { sect=1; next }
        /^[[:space:]]+Options:/  { sect=1; next }
        /^[[:space:]]*Aliases accepted:/ { sect=0; next }

        sect && /^[[:space:]]{4}[[:alnum:] _-]+$/ {
            for (i=1; i<=NF; i++) {
                if ($i ~ /^[a-z][a-z0-9-]*$/) print $i
            }
        }
    ' | awk '!seen[$0]++' | grep -Ev '^(help|general)$' || true

)"

readme_topics="$(

    awk '
        /^##[[:space:]]+[a-z][a-z0-9-]*[[:space:]]*$/ {
            t=$2
            if (!seen[t]++) print t
        }
    ' "$README" || true

)"

failed=0

ok() {

    [ "$QUIET" -eq 1 ] || printf 'ok: %s\n' "$1"

}

not_ok() {

    [ "$QUIET" -eq 1 ] || printf 'not ok: %s\n' "$1"

    failed=1
}

for t in $cli_topics; do

    if ! printf '%s\n' "$readme_topics" | grep -Fx -- "$t" >/dev/null 2>&1; then

        not_ok "README heading exists for topic: $t"

    else

        ok "README heading exists for topic: $t"

    fi

done

for t in $readme_topics; do

    if ! printf '%s\n' "$cli_topics" | grep -Fx -- "$t" >/dev/null 2>&1; then

        not_ok "README heading maps to CLI topic: $t"

    else

        ok "README heading maps to CLI topic: $t"

    fi

done

[ "$failed" -eq 0 ] || exit 1

exit 0
