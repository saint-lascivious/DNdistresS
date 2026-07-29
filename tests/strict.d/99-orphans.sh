#!/bin/sh

# orphans.sh - finds defined but unreferenced functions in DNdistresS.

set -eu

QUIET=0

ALLOWLIST='
strict_smoke_orphan_pass
'

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

[ -r "$SCRIPT" ] || {
    printf 'error: script not readable: %s\n' "$SCRIPT" >&2
    exit 2
}

is_allowlisted() {
    fn="$1"
    printf '%s\n' "$ALLOWLIST" | awk 'NF' | grep -Fx -- "$fn" >/dev/null 2>&1
}

funcs_file="${TMPDIR:-/tmp}/.DNdistresS-orphans-funcs.$$"
refs_file="${TMPDIR:-/tmp}/.DNdistresS-orphans-refs.$$"
trap 'rm -f "$funcs_file" "$refs_file"' EXIT HUP INT TERM

awk '
/^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ {
    s=$0
    sub(/^[[:space:]]*/, "", s)
    sub(/[[:space:]]*\(\)[[:space:]]*\{.*/, "", s)
    printf "%s\t%d\n", s, NR
}
' "$SCRIPT" > "$funcs_file"

[ -s "$funcs_file" ] || exit 0

awk -v defsfile="$funcs_file" '
    BEGIN {

        while ((getline line < defsfile) > 0) {
            split(line, a, "\t")
            fn = a[1]
            dl[fn] = a[2] + 0
            order[++n] = fn
            refs[fn] = 0
        }

        close(defsfile)
    }
    {
        line = $0
        sub(/\r$/, "", line)

        if (line ~ /^[[:space:]]*#/) next

        while (match(line, /[A-Za-z_][A-Za-z0-9_]*/)) {
            tok = substr(line, RSTART, RLENGTH)

            if ((tok in dl) && NR != dl[tok]) refs[tok]++

            line = substr(line, RSTART + RLENGTH)
        }

    }
    END {

        for (i = 1; i <= n; i++) {
            fn = order[i]
            printf "%s\t%d\n", fn, refs[fn] + 0
        }

    }
' "$SCRIPT" > "$refs_file"

failed=0

ok() {

    [ "$QUIET" -eq 1 ] || printf 'ok: %s\n' "$1"

}

not_ok() {

    [ "$QUIET" -eq 1 ] || printf 'not ok: %s\n' "$1"

    failed=1
}

while IFS="$(printf '\t')" read -r fn refs; do

    [ -n "$fn" ] || continue

    refs="${refs:-0}"

    [ "$refs" -ge 1 ] && continue

    if is_allowlisted "$fn"; then
        allowlisted=1
    else
        allowlisted=0
    fi

    if [ "$allowlisted" -eq 1 ]; then

        [ "$QUIET" -ne 1 ] && printf 'note: allowlisted orphan: %s()\n' "$fn" >&2

    else

        not_ok "unreferenced function: $fn()"

    fi

done < "$refs_file"

if [ "$failed" -eq 0 ]; then

    ok "no unallowlisted orphan functions"

fi

[ "$failed" -eq 0 ] || exit 1

exit 0
