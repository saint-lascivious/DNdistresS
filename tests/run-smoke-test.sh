#!/bin/sh

set -eu

QUIET=0

usage() {
    printf 'Usage: %s [q|-q|quiet|--quiet]\n' "${0##*/}"
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
        *)
            printf 'error: unknown option: %s\n' "$1" >&2

            usage >&2

            exit 2
            ;;
    esac
    shift
done

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
SMOKE="$ROOT_DIR/tests/smoke-test.sh"

if [ ! -f "$SMOKE" ]; then
    printf 'error: missing smoke test script: %s\n' "$SMOKE" >&2
    exit 2
fi

printf '%s\n\n' "Running dndistress smoke tests..."

if sh "$SMOKE"; then
    printf '\n%s\n' "✓ all smoke tests passed!"
    exit 0
else

    [ "$QUIET" -eq 1 ] || printf '\n%s\n' "error: some smoke tests failed."

fi
