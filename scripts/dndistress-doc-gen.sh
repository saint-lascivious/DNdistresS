#!/usr/bin/env bash

# dndistress-doc-gen.sh - Generate README.md for dndistress.

set -euo pipefail

ROOT_DIR="$(
    CDPATH=''
    cd -- "$(dirname -- "$0")/.." && pwd
)"

CLI="$ROOT_DIR/dndistress"
OUT="$ROOT_DIR/README.md"

TOPICS_ORDER="description general info usage runtime resolver domains \
    environment status topics install uninstall show version binary burst \
    column custom directory duration file format local location maximum \
    force-maximum output port qps random remote seconds top type deny-any \
    url verbosity"

if [ ! -f "$CLI" ]; then
    printf '%s\n' "error: CLI not found at $CLI" >&2
    exit 1
fi

if [ ! -x "$CLI" ]; then

    chmod +x "$CLI"

fi

read_cli_var() {
    local key="$1"

    awk -F= -v key="$key" '
        $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            v=$2
            sub(/^[[:space:]]+/, "", v)
            sub(/[[:space:]]+$/, "", v)
            gsub(/^["\047]|["\047]$/, "", v)
            print v
            exit
        }
    ' "$CLI"

}

read_generated_at() {

    date -u '+%Y-%m-%d %H:%M:%S UTC'

}

DOC_VERSION="$(read_cli_var VERSION)"
DOC_AUTHOR="$(read_cli_var AUTHOR_NAME)"
DOC_COPYRIGHT_YEAR="$(read_cli_var COPYRIGHT_YEAR)"
DOC_CONTACT="$(read_cli_var CONTACT)"
DOC_LICENSE="$(read_cli_var LICENSE)"

[ -n "${DOC_VERSION:-}" ] || DOC_VERSION="unknown"

[ -n "${DOC_AUTHOR:-}" ] || DOC_AUTHOR="unknown"

[ -n "${DOC_COPYRIGHT_YEAR:-}" ] || DOC_COPYRIGHT_YEAR="unknown"

[ -n "${DOC_CONTACT:-}" ] || DOC_CONTACT="unknown"

[ -n "${DOC_LICENSE:-}" ] || DOC_LICENSE="unknown"

SCRIPT_NAME="$(basename -- "$0")"
GENERATED_AT="$(read_generated_at)"

need_cmd() {
    command -v "$1" >/dev/null 2>&1
}

make_tmpdir() {
    base="${1:-${TMPDIR:-/tmp}}"

    if need_cmd mktemp; then
        d="$(mktemp -d "$base/dndistress.XXXXXX" 2>/dev/null || true)"

        if [ -n "$d" ] && [ -d "$d" ]; then
            printf '%s\n' "$d"
            return 0
        fi

    fi

    umask 077
    i=0

    while [ "$i" -lt 1000 ]; do
        d="$base/dndistress.$$.$i"

        if mkdir "$d" 2>/dev/null; then
            printf '%s\n' "$d"
            return 0
        fi

        i=$((i + 1))
    done

    return 1
}

OUT_DIR="$(dirname -- "$OUT")"
TMP_DIR="$(make_tmpdir)"
TMP_OUT="$TMP_DIR/README.md"

trap 'rm -fr "$TMP_DIR"' EXIT

if ! mkdir -p "$OUT_DIR" 2>/dev/null; then
    printf '%s\n' "error: failed to create output directory: $OUT_DIR" >&2
    exit 1
fi

if [ ! -w "$OUT_DIR" ]; then
    printf '%s\n' "error: output directory not writable: $OUT_DIR" >&2
    exit 1
fi

run_help() {
    local topic="$1"

    if [ "$topic" = "general" ]; then

        if ! "$CLI" --help 2>&1; then
            printf '%s\n' "error: failed to get help for topic '$topic'" >&2
            return 1
        fi

    else

        if ! "$CLI" --help "$topic" 2>&1; then
            printf '%s\n' "error: failed to get help for topic '$topic'" >&2
            return 1
        fi

    fi

}

discover_topics() {
    local output

    if ! output="$("$CLI" --help topics 2>&1)"; then
        printf '%s\n' "error: failed to discover topics from CLI" >&2
        return 1
    fi

    printf '%s\n' "$output" | awk '
        /^[[:space:]]+General:/  { sect=1; next }
        /^[[:space:]]+Commands:/ { sect=1; next }
        /^[[:space:]]+Options:/  { sect=1; next }
        /^[[:space:]]*Aliases accepted:/ { sect=0; next }

        sect && /^[[:space:]]{4}[[:alnum:] _-]+$/ {
            for (i=1; i<=NF; i++) {
                if ($i ~ /^[a-z][a-z0-9-]*$/) print $i
            }
        }
    ' | awk '!seen[$0]++' | grep -v '^help$' || true

}

reorder_topics() {

    awk -v pref="$TOPICS_ORDER" '
        NF {
            have[$1]=1
            order_list[++order_n]=$1
        }
        END {
            m=split(pref, p, " ")
            for (i=1; i<=m; i++) {
                if (have[p[i]]) {
                    print p[i]
                    emitted[p[i]]=1
                }
            }
            for (i=1; i<=order_n; i++) {
                if (!emitted[order_list[i]]) print order_list[i]
            }
        }
    '

}

topic_group() {

    case "$1" in
        general|info|description|usage|runtime|resolver|domains|environment|status|topics)
            printf '%s\n' "General"
            ;;
        install|uninstall|show|version)
            printf '%s\n' "Commands"
            ;;
        *)
            printf '%s\n' "Options"
            ;;
    esac

}

emit_topic() {
    local topic="$1"

    printf '\n## %s\n\n' "$topic"
    printf '%s\n' '```text'

    if ! run_help "$topic"; then
        printf '%s\n' "(error: failed to retrieve help for topic '$topic')"
    fi

    printf '%s\n' '```'
}

capture_smoke_output() {
    local smoke_script="$ROOT_DIR/tests/run-smoke-test.sh"
    local output
    local status=0

    if [ ! -f "$smoke_script" ]; then
        printf '%s\n' "(smoke test script not found at tests/run-smoke-test.sh)"
        return 0
    fi

    output="$(sh "$smoke_script" 2>&1)" || status=$?

    if [ "$status" -ne 0 ]; then
        printf '%s\n' "warning: smoke tests failed during doc generation (exit $status)" >&2
    fi

    if [ -n "$output" ]; then
        printf '%s\n' "$output"
    else
        printf '%s\n' "(no smoke test output captured)"
    fi
}

TOPICS_NL="$(discover_topics || true)"

if [ -z "$TOPICS_NL" ]; then
    printf '%s\n' "warning: topic discovery failed; using fallback list" >&2
    TOPICS_NL="$(printf '%s\n' "$TOPICS_ORDER" | tr ' ' '\n')"
fi

TOPICS_NL="$(printf '%s\n' "$TOPICS_NL" | reorder_topics)"

mapfile -t TOPICS_ARR < <(printf '%s\n' "$TOPICS_NL" | awk 'NF')

SMOKE_OUTPUT="$(capture_smoke_output)"

emit_development_section() {
    cat <<'EOF'

## Development

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute
to this project.

### Security

For security-related issues, see [SECURITY.md](SECURITY.md).

Please do **not** open a public issue for security vulnerabilities.

### Smoke Test Suite

Smoke tests are run via:

- `tests/run-smoke-test.sh`

This wrapper runs `tests/smoke-test.sh` and returns non-zero on failure.

#### Run tests

##### Linux / macOS / Windows (PowerShell + Git Bash)
```bash
bash ./tests/run-smoke-test.sh
```

##### Windows (WSL)
```powershell
wsl bash ./tests/run-smoke-test.sh
```

#### Example run

EOF

    printf '%s\n' '```text'
    printf '%s\n' "$SMOKE_OUTPUT"
    printf '%s\n' '```'

    cat <<'EOF'

#### Quiet mode

```bash
bash ./tests/run-smoke-test.sh --quiet
```

Aliases: `q`, `-q`, `quiet`, `--quiet`.

### Bug Reports

Open an issue on [GitHub Issues](../../issues) with:

- A description of the problem
- Steps to reproduce
- Expected vs actual behaviour
- Script version (`dndistress --version`)

### Feature Requests

Feature requests are welcome via [GitHub Issues](../../issues).

Please describe the use case, not just the desired behaviour.

### Pull Requests

Pull requests should:

- Target the `master` branch
- Include a clear description of what was changed and why
- Update help texts or documentation when behavior changes
- Trigger no ShellCheck warnings or errors
- Pass the smoke test suite before submission
EOF

}

{

    cat <<EOF
<!--
  This file was generated by $SCRIPT_NAME at $GENERATED_AT.

                        DO NOT edit this file directly.

 Instead, edit the dndistress script and then run this script to regenerate it.
-->

# DNdistresS

\`\`\`text
           _____   _____       _ _                             _____
          |  __ \ |  __ \     | (_)       _                   / ____)
          | |  \ \| |  \ \  __| |_  ___ _| |_  ____ _____  __( (____
          | |   | | |   | |/ _  | |/___)_   _)/ ___) ___ |/___)____ \\
          | |__/ /| |   | | |_| | |___ | | |_| |   | ____|___ |____) )
          |_____/ |_|   |_|\____|_(___/   \__)_|   |_____(___(______/

    Contact: $DOC_CONTACT
    License: $DOC_LICENSE
    Version: $DOC_VERSION

    DNdistresS Copyright $DOC_COPYRIGHT_YEAR $DOC_AUTHOR

    This program comes with ABSOLUTELY NO WARRANTY; for details type 'show w'.
    This is free software, and you are welcome to redistribute it
    under certain conditions; type 'show c' for details.
\`\`\`

---

## Quick Start

- [install](#install)
- [usage](#usage)

## Index
EOF

    current_group=""
    for t in "${TOPICS_ARR[@]}"; do
        g="$(topic_group "$t")"
        if [ "$g" != "$current_group" ]; then
            printf '\n### %s\n' "$g"
            current_group="$g"
        fi
        printf '%s\n' "- [$t](#$t)"
    done

    printf '\n### Development\n'
    printf '%s\n' '- [development](#development)'

    for t in "${TOPICS_ARR[@]}"; do

        emit_topic "$t"

    done

    emit_development_section

    printf '\n---\n\n> Generated by %s at %s.\n' "$(basename -- "$0")" "$GENERATED_AT"
} > "$TMP_OUT" || {
    printf '%s\n' "error: failed to write to temp file" >&2
    exit 1
}

strip_timestamps() {
    sed \
        -e 's/This file was generated by .*/TIMESTAMP_LINE/' \
        -e 's/Generated by .* at .*/TIMESTAMP_LINE/' \
        -e 's/^> Generated by .*$/> Generated by SCRIPT at TIMESTAMP./' \
        "$1"
}

if [ -f "$OUT" ] && diff -q <(strip_timestamps "$TMP_OUT") <(strip_timestamps "$OUT") > /dev/null 2>&1; then
    printf '%s\n' "no content changes detected, skipping"
    CONTENT_CHANGED=0
else

    cp "$TMP_OUT" "$OUT" || {
        printf '%s\n' "error: failed to write to $OUT" >&2
        exit 1
    }

    printf '%s\n' "generated dndistress README.md"
    CONTENT_CHANGED=1
fi

if [ "$CONTENT_CHANGED" -eq 1 ]; then
    printf '\n%s\n' "summary:"
    printf '  topics: %d\n' "${#TOPICS_ARR[@]}"
    printf '  sections: general, commands, options, development\n'
    printf '  output: %s\n' "$OUT"
    printf '\n✓ documentation generated successfully.\n'
fi
