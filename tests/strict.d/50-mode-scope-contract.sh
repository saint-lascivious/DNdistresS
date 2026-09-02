#!/bin/sh

# 50-mode-scope-contract.sh - mode-scoped flags must fail outside scope

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
    printf 'error: SCRIPT not readable: %s\n' "$SCRIPT" >&2
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

assert_exit "--full alone is rejected (install-only flag out of scope)" "$USAGE" --full

assert_exit "--full with version is rejected (install-only flag out of scope)" "$USAGE" --full --version

assert_exit "--with-systemd alone is rejected (scope violation)" "$USAGE" --with-systemd

assert_exit "--without-systemd alone is rejected (scope violation)" "$USAGE" --without-systemd

assert_exit "--with-systemd with version is rejected (scope violation)" "$USAGE" --with-systemd --version

assert_exit "--without-systemd with version is rejected (scope violation)" "$USAGE" --without-systemd --version

assert_exit "--with-bash-completion alone is rejected (scope violation)" "$USAGE" --with-bash-completion

assert_exit "--without-bash-completion alone is rejected (scope violation)" "$USAGE" --without-bash-completion

assert_exit "--with-bash-completion with version is rejected (scope violation)" "$USAGE" --with-bash-completion --version

assert_exit "--without-bash-completion with version is rejected (scope violation)" "$USAGE" --without-bash-completion --version

[ "$failed" -eq 0 ] || exit 1

exit 0
