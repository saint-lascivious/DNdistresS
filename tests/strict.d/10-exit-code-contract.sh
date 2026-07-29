#!/bin/sh

# exit-code-contract.sh - deterministic exit code contract checks.

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

failed=0

ok() {

    [ "$QUIET" -eq 1 ] || printf 'ok: %s\n' "$1"

}

not_ok() {

    [ "$QUIET" -eq 1 ] || printf 'not ok: %s\n' "$1"

    failed=1
}

expect_exit() {
    name="$1"
    want="$2"
    shift 2

    set +e
    "$@" >/dev/null 2>&1
    rc=$?
    set -e

    if [ "$rc" -ne "$want" ]; then

        not_ok "$name (got $rc, want $want)"

    else

        ok "$name"

    fi

}

expect_exit "unknown option" 2 "$CLI" --definitely-not-a-real-option

expect_exit "invalid _VERBOSITY env" 2 env _VERBOSITY=9 "$CLI" --version

expect_exit "invalid _PORT env" 2 env _PORT=0 "$CLI"

expect_exit "invalid LOG_MODE env" 2 env LOG_MODE=invalid "$CLI" --version

expect_exit "install mode rejects run flags" 2 "$CLI" install -f /dev/null -F plain -t 1 -q 1 -D 1

expect_exit "uninstall mode rejects run flags" 2 "$CLI" uninstall -f /dev/null -F plain -t 1 -q 1 -D 1

expect_exit "show mode rejects run flags" 2 "$CLI" show w -f /dev/null -F plain -t 1 -q 1 -D 1

[ "$failed" -eq 0 ] || exit 1

exit 0
