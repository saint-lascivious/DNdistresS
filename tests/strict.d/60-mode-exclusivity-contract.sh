#!/bin/sh

# 60-mode-exclusivity-contract.sh - command modes exclusive with run modes.

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
SCRIPT="${1:-$ROOT_DIR/DNdistresS}"
USAGE=2

[ -r "$SCRIPT" ] || {
    printf 'error: script not readable: %s\n' "$SCRIPT" >&2
    exit 2
}

[ -x "$SCRIPT" ] || {
    printf 'error: SCRIPT not executable: %s\n' "$SCRIPT" >&2
    exit 2
}

failed=0

ok() {
    [ "$QUIET" -eq 1 ] || printf 'ok: %s\n' "$1"
}

not_ok() {
    printf 'not ok: %s\n' "$1" >&2
    failed=1
}

assert_exit() {
    desc="$1"
    expected="$2"
    shift 2

    set +e
    "$SCRIPT" "$@" >/dev/null 2>&1
    rc=$?
    set -e

    if [ "$rc" -eq "$expected" ]; then

        ok "$desc"

    else

        not_ok "$desc (got=$rc expected=$expected)"

    fi

}

assert_exit "version cannot be combined with --qps" "$USAGE" --version --qps 10

assert_exit "show cannot be combined with --qps" "$USAGE" show w --qps 10

assert_exit "install cannot be combined with --qps" "$USAGE" install /tmp --qps 10

assert_exit "uninstall cannot be combined with --qps" "$USAGE" uninstall /tmp --qps 10

assert_exit "-v cannot be combined with -q" "$USAGE" -v -q 10

assert_exit "-S cannot be combined with -q" "$USAGE" -S w -q 10

assert_exit "-i cannot be combined with -q" "$USAGE" -i /tmp -q 10

assert_exit "-u cannot be combined with -q" "$USAGE" -u /tmp -q 10

[ "$failed" -eq 0 ] || exit 1

exit 0
