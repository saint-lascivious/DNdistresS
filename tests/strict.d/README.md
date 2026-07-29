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

- `10-orphans.sh`
- `20-readme-topics-sync.sh`

## Script contract

Each strict test must:

- be executable shell (`#!/bin/sh`)
- use `set -eu`
- accept positional args:

1. `$1` = CLI script path (defaults to repo `DNdistresS`)
2. `$2` = README path (defaults to repo `README.md`)

- optionally read `QUIET` env (`0|1`)

## Exit codes

- `0` = pass
- `1` = assertion failure (real test failure)
- `2` = test infrastructure/setup error (missing file, bad args, etc.)

## Output

- On failure: print concise diagnostics to `stderr`.
- On success: optional one-line success text (or stay silent).
- Respect `QUIET=1` by suppressing non-essential output.

## Safety rules

- No network calls unless the test explicitly requires it.
- No destructive writes outside temp files.
- Do not mutate repository files.
- Keep checks deterministic and fast.

## Minimal template

```sh
#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
SCRIPT="${1:-$ROOT_DIR/DNdistresS}"
README="${2:-$ROOT_DIR/README.md}"
QUIET="${QUIET:-0}"

[ -x "$SCRIPT" ] || { printf 'error: CLI not executable: %s\n' "$SCRIPT" >&2; exit 2; }

[ -r "$README" ] || { printf 'error: README not readable: %s\n' "$README" >&2; exit 2; }

# ...check logic...

[ "$QUIET" -eq 1 ] || printf 'ok: %s\n' "${0##*/}"

exit 0

```

## Adding a new strict test

1. Create a new script in `tests/strict.d/` with a numeric prefix for ordering.
2. Implement the test logic following the contract and conventions.
3. Make it executable (`chmod +x`).
4. Run `tests/run-strict.sh` to verify it works and fails on expected conditions.
