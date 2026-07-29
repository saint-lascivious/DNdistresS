#!/bin/sh

# help-topic-contract.sh - every advertised topic must resolve via --help <topic>.

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

[ -x "$CLI" ] || { printf 'error: CLI not executable: %s\n' "$CLI" >&2; exit 2; }

topics="$(

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

[ -n "$topics" ] || { printf 'error: no help topics discovered\n' >&2; exit 1; }

failed=0

ok() {

    [ "$QUIET" -eq 1 ] || printf 'ok: %s\n' "$1"

}

not_ok() {

    [ "$QUIET" -eq 1 ] || printf 'not ok: %s\n' "$1"

    failed=1
}

for t in $topics; do
    set +e
    out="$("$CLI" --help "$t" 2>&1)"
    rc=$?
    set -e

    if [ "$rc" -eq 0 ] && [ -n "$out" ]; then

        ok "help topic resolves: $t"

    else

        not_ok "help topic resolves: $t (exit=$rc, empty=$([ -z "$out" ] && printf yes || printf no))"

    fi

done

[ "$failed" -eq 0 ] || exit 1

exit 0
