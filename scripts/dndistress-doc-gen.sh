#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(
    CDPATH=''
    cd -- "$(dirname -- "$0")/.." && pwd
)"

CLI="$ROOT_DIR/dndistress"
OUT="$ROOT_DIR/README.md"

TOPICS_FALLBACK="general usage topics info description runtime resolver domains environment status install uninstall show version binary burst column custom directory duration file format local location maximum force-maximum output port qps remote seconds top type deny-any url verbosity"
TOPICS_PREFERRED="description general info usage runtime resolver domains environment status topics install uninstall show version binary burst column custom directory duration file format local location maximum force-maximum output port qps remote seconds top type deny-any url verbosity"

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

OUT_DIR="$(dirname -- "$OUT")"

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

    awk -v pref="$TOPICS_PREFERRED" '
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

TOPICS_NL="$(discover_topics || true)"
if [ -z "$TOPICS_NL" ]; then
    printf '%s\n' "warning: topic discovery failed; using fallback list" >&2
    TOPICS_NL="$(printf '%s\n' "$TOPICS_FALLBACK" | tr ' ' '\n')"
fi

TOPICS_NL="$(printf '%s\n' "$TOPICS_NL" | reorder_topics)"

mapfile -t TOPICS_ARR < <(printf '%s\n' "$TOPICS_NL" | awk 'NF')

emit_testing_section() {
    cat <<'EOF'

## Smoke Test Suite

Smoke tests are run via:

- `tests/run-smoke-test.sh`

This wrapper runs `tests/smoke-test.sh` and returns non-zero on failure.

### Run tests

#### Linux / macOS
```bash
bash ./tests/run-smoke-test.sh
```

#### Windows (PowerShell + Git Bash)
```powershell
bash ./tests/run-smoke-test.sh
```

#### Windows (WSL)
```powershell
wsl bash ./tests/run-smoke-test.sh
```

### Quiet mode

```bash
bash ./tests/run-smoke-test.sh --quiet
```

Aliases: `q`, `-q`, `quiet`, `--quiet`.
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

    DNdistresS Copyright (C) $DOC_COPYRIGHT_YEAR $DOC_AUTHOR

    This program comes with ABSOLUTELY NO WARRANTY; for details type 'show w'.
    This is free software, and you are welcome to redistribute it
    under certain conditions; type 'show c' for details.
\`\`\`

---

## Quick Start

- [install](#install)
- [usage](#usage)
- [uninstall](#uninstall)

Security: see [SECURITY.md](SECURITY.md).

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

    printf '\n### Testing\n'
    printf '%s\n' '- [smoke-test-suite](#smoke-test-suite)'

    for t in "${TOPICS_ARR[@]}"; do

        emit_topic "$t"

    done

    emit_testing_section

    printf '\n---\n\n> Generated by %s at %s.\n' "$(basename -- "$0")" "$GENERATED_AT"
} > "$OUT" || {
    printf '%s\n' "error: failed to write to $OUT" >&2
    exit 1
}

printf '%s\n' "generated: $OUT"

printf '\n%s\n' "summary:"
printf '  topics: %d\n' "${#TOPICS_ARR[@]}"
printf '  sections: general, commands, options, testing\n'
printf '  output: %s\n' "$OUT"
printf '\n✓ documentation generated successfully.\n'
