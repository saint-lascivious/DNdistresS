#!/bin/sh

# run-smoke-test.sh - Run the smoke test suite for dndistress.

set -eu

QUIET=0

while [ "$#" -gt 0 ]; do

    case "$1" in
        q|-q|quiet|--quiet)
            QUIET=1
            ;;
        h|-h|help|--help)
            printf 'Usage: %s [q|-q|quiet|--quiet]\n' "${0##*/}"
            exit 0
            ;;
        *)
            printf 'error: unknown option: %s\n' "$1" >&2
            printf 'Usage: %s [q|-q|quiet|--quiet]\n' "${0##*/}" >&2
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

[ "$QUIET" -eq 1 ] || printf '%s\n\n' "Running dndistress smoke tests..."

if [ "$QUIET" -eq 1 ]; then
    if sh "$SMOKE" --quiet; then
        exit 0
    else
        rc=$?
        printf '\n%s\n' "✗ some smoke tests failed."
        exit "$rc"
    fi
else
    if sh "$SMOKE"; then
        printf '\n%s\n' "✓ all smoke tests passed!"
        exit 0
    else
        rc=$?
        printf '\n%s\n' "✗ some smoke tests failed."
        exit "$rc"
    fi
fi
