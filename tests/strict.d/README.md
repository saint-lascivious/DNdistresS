# strict.d

`tests/run-strict.sh` executes `tests/strict.d/*.sh` in lexical order.

## Purpose

Strict checks are for **drift/consistency** and should fail when contract-level expectations are violated.

## File naming

Use numeric prefixes to control order:

- `10-*.sh`
- `20-*.sh`
- `30-*.sh`

Example:

- `10-exit-code-contract.sh`
- `20-help-topic-contract.sh`
- `30-readme-topics-sync.sh`

## Script contract

Each strict test SHOULD:

- be executable shell (`#!/bin/sh`)
- use `set -eu`
- accept positional args:

1. `$1` = SCRIPT path (defaults to repo `DNdistresS`)
2. `$2` = README path (defaults to repo `README.md`)

- optionally read `QUIET` env (`0|1`)

### Exit codes

- `0` = pass
- `1` = assertion failure (real test failure)
- `2` = test infrastructure/setup error (missing file, bad args, etc.)
- `3` = test skipped (not implemented, not applicable, etc.)

### Output

- `ok:` lines are informational and should be printed to `stdout` only when `QUIET=0`.
- `not ok:` lines are failures and must always be printed to `stderr` (even when `QUIET=1`).
- On failure: print concise diagnostics to `stderr`.
- On success: optional one-line success text (or stay silent).
- Respect `QUIET=1` by suppressing non-essential output.

### Safety rules

Each strict test SHOULD NOT:
- Perform network calls unless the test explicitly requires it.
- Do destructive writes outside temp files.
- Mutate repository files.
- Depend on external state (e.g., system config, user environment) unless explicitly required.
- Depend on the existence or absence of each other (strict tests SHOULD be independent).

### Template

```sh
#!/bin/sh

# script-name.sh - basic description of function.

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

failed=0

ok() {
    [ "$QUIET" -eq 1 ] || printf 'ok: %s\n' "$1"
}

not_ok() {
    printf 'not ok: %s\n' "$1" >&2
    failed=1
}

# ...check logic...


[ "$failed" -eq 0 ] || exit 1

exit 0

```

## Adding a new strict test

1. Create a new script in `tests/strict.d/` with a numeric prefix for ordering.
2. Implement the test logic following the contract and conventions.
3. Make it executable (`chmod +x`).
4. Run `tests/run-strict.sh` to verify it works and fails on expected conditions.
