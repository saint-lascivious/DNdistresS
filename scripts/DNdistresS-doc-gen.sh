#!/usr/bin/env bash

# DNdistresS-doc-gen.sh - generate README.md for DNdistresS

set -euo pipefail

ROOT_DIR="$(
    CDPATH=''
    cd -- "$(dirname -- "$0")/.." && pwd
)"

SCRIPT="$ROOT_DIR/DNdistresS"
OUT="$ROOT_DIR/README.md"

TOPICS_ORDER="usage topics what why install uninstall examples show version info \
    description  runtime status environment exit-codes resolver domains binary qps \
    burst  force-burst batch maximum force-maximum auto-tune clock-tick-ms \
    drain-timeout-ms duration output type random deny-any allow-any dig-options \
    dig-options-mode strict-dig-options location local remote port file url format \
    column top custom directory seconds with-systemd with-bash-completion full \
    verbosity log-mode"

README_EXCLUDE_TOPICS="topics-list general help"

is_readme_topic() {

    case " $README_EXCLUDE_TOPICS " in
        *" $1 "*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac

}

if [ ! -f "$SCRIPT" ]; then
    printf '%s\n' "error: SCRIPT not found at $SCRIPT" >&2
    exit 1
fi

if [ ! -x "$SCRIPT" ]; then

    chmod +x "$SCRIPT"

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
    ' "$SCRIPT"

}

read_generated_at() {

    date -u '+%Y-%m-%d %H:%M:%S UTC'

}

read_cli_runtime_version() {
    "$SCRIPT" --version 2>/dev/null | awk '
        NF >= 2 {
            v = $2
            sub(/^v/, "", v)
            print v
            exit
        }
    '
}

DOC_NAME="$(read_cli_var NAME)"
DOC_VERSION="$(read_cli_runtime_version)"
DOC_COPYRIGHT="$(read_cli_var COPYRIGHT_YEAR)"
DOC_AUTHOR="$(read_cli_var AUTHOR_NAME)"

[ -n "${DOC_NAME:-}" ] || DOC_NAME="unknown"

[ -n "${DOC_VERSION:-}" ] || DOC_VERSION="$(read_cli_var VERSION)"

[ -n "${DOC_VERSION:-}" ] || DOC_VERSION="unknown"

[ -n "${DOC_COPYRIGHT:-}" ] || DOC_COPYRIGHT="unknown"

[ -n "${DOC_AUTHOR:-}" ] || DOC_AUTHOR="unknown"

SCRIPT_NAME="$(basename -- "$0")"
GENERATED_AT="$(read_generated_at)"

need_cmd() {
    command -v "$1" >/dev/null 2>&1
}

make_tmpdir() {
    base="${1:-${TMPDIR:-/tmp}}"

    if need_cmd mktemp; then
        d="$(mktemp -d "$base/DNdistresS.XXXXXX" 2>/dev/null || true)"

        if [ -n "$d" ] && [ -d "$d" ]; then
            printf '%s\n' "$d"
            return 0
        fi

    fi

    umask 077
    i=0

    while [ "$i" -lt 1000 ]; do
        d="$base/DNdistresS.$$.$i"

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

        if ! "$SCRIPT" --help 2>&1; then
            printf '%s\n' "error: failed to get help for topic '$topic'" >&2
            return 1
        fi

    else

        if ! "$SCRIPT" --help "$topic" 2>&1; then
            printf '%s\n' "error: failed to get help for topic '$topic'" >&2
            return 1
        fi

    fi

}

discover_topics() {
    local output

    if output="$("$SCRIPT" --help topics-list 2>/dev/null)"; then
        printf '%s\n' "$output" | awk '/^[a-z][a-z0-9-]*$/ { print }' | awk '!seen[$0]++'
        return 0
    fi

    if ! output="$("$SCRIPT" --help topics 2>&1)"; then
        printf '%s\n' "error: failed to discover topics from SCRIPT" >&2
        return 1
    fi

    printf '%s\n' "$output" | awk '
        /^[[:space:]]+General:/  { sect=1; next }
        /^[[:space:]]+Commands:/ { sect=1; next }
        /^[[:space:]]+Options:/  { sect=1; next }
        /^[[:space:]]+Aliases:/  { sect=0; next }

        sect && /^[[:space:]]{4}/ {

            for (i=1; i<=NF; i++) {
                if ($i ~ /^[a-z][a-z0-9-]*$/) print $i
            }

        }
    ' | awk '!seen[$0]++' || true

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
        general|what|why|info|description|usage|runtime|resolver|domains|environment|exit-codes|status|topics|examples)
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

emit_static_example_run_section() {
    cat <<'EOF'
## Simple Example Run

```text
A short sample run of DNdistresS with a 10-second duration and otherwise
default (and thus very conservative) settings:

user@hostname:~$ ./DNdistresS --duration 10
[·] queries sent:           161
[·] queries completed:      161
[·] answers received:       450
[·] QPS (active):           16.2
[·] QPS (total):            7.32
[·] completed QPS (window): 16.15
[·] completed QPS (total):  7.32
[·] answer QPS (window):    45.14
[·] answer QPS (total):     20.45
[✓] done!
```

EOF

}

emit_index_group() {
    local group="$1"
    local printed=0
    local t

    for t in "${README_TOPICS_ARR[@]}"; do

        [ "$(topic_group "$t")" = "$group" ] || continue

        if [ "$printed" -eq 0 ]; then
            printf '### %s\n' "$group"
            printed=1
        fi

        printf '%s\n' "- [$t](#$t)"
    done

    [ "$printed" -eq 0 ] || printf '\n'

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

extract_help_explainer() {
    local topic="$1"
    local output body

    if ! output="$("$SCRIPT" --help "$topic" 2>&1)"; then
        return 1
    fi

    body="$(
        printf '%s\n' "$output" | awk '
            BEGIN { started=0 }
            /^Topic:[[:space:]]*/ { started=1; next }
            started == 0 { next }
            /^See also:[[:space:]]*$/ { exit }
            { print }
        ' | awk '
            { line[++n]=$0 }
            END {
                s=1

                while (s<=n && line[s] ~ /^[[:space:]]*$/) s++

                e=n

                while (e>=s && line[e] ~ /^[[:space:]]*$/) e--

                for (i=s; i<=e; i++) print line[i]

            }
        '
    )"

    [ -n "$body" ] || return 1

    printf '%s\n' "$body"
}

emit_intro_explainer_section() {
    local topic="$1"
    local heading="$2"
    local body=""

    printf '## %s\n\n' "$heading"

    if body="$(extract_help_explainer "$topic" 2>/dev/null)" && [ -n "$body" ]; then
        printf '%s\n' '```text'
        printf '%s\n' "$body"
        printf '%s\n\n' '```'
    else
        printf '%s\n' '```text'
        printf '%s\n' "$heading explainer unavailable."
        printf '%s\n\n' '```'
    fi
}

emit_intro_explainers() {

    emit_intro_explainer_section "what" "What Is It?"

    emit_intro_explainer_section "why" "OK. Sure, I Guess. Why?"

}

capture_smoke_output() {
    local smoke_script="$ROOT_DIR/tests/smoke-test.sh"
    local output=""
    local status=0

    if [ ! -f "$smoke_script" ]; then
        printf '%s\n' "(smoke test script not found at tests/smoke-test.sh)"
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

README_TOPICS_ARR=()

for t in "${TOPICS_ARR[@]}"; do

    is_readme_topic "$t" || continue

    README_TOPICS_ARR+=("$t")
done

SMOKE_OUTPUT="$(capture_smoke_output)"

emit_development_index() {
    printf '%s\n' "### Development"
    printf '%s\n' "- [contributing](#contributing)"
    printf '%s\n' "- [security](#security)"
    printf '%s\n' "- [smoke-test-suite](#smoke-test-suite)"
    printf '%s\n' "- [bug-reports](#bug-reports)"
    printf '%s\n' "- [feature-requests](#feature-requests)"
    printf '%s\n' "- [pull-requests](#pull-requests)"
    printf '\n'
}

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

- `tests/smoke-test.sh`

The script returns non-zero on failure.

#### Run tests

##### Linux / macOS / Windows (PowerShell + Git Bash)
```bash
bash ./tests/smoke-test.sh
```

##### Strict mode
```bash
bash ./tests/smoke-test.sh --strict
```

##### Windows (WSL)
```powershell
wsl bash ./tests/smoke-test.sh
```

#### Example run

EOF

    printf '%s\n' '```text'
    printf '%s\n' "$SMOKE_OUTPUT"
    printf '%s\n' '```'

    cat <<'EOF'

#### Quiet mode

```bash
bash ./tests/smoke-test.sh --quiet
```

Aliases: `q`, `-q`, `quiet`, `--quiet`.

### Bug Reports

Open an issue on [GitHub Issues](../../issues) with:

- A description of the problem
- Steps to reproduce
- Expected vs actual behaviour
- Script version (`DNdistresS --version`)

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
  Generated by $SCRIPT_NAME at $GENERATED_AT.
-->

EOF

    cat <<'EOF'
<table align="center"><tr><td>
<pre>
 _____   _____       _ _                             _____
|  __ \ |  __ \     | (_)       _                   / ____)
| |  \ \| |  \ \  __| |_  ___ _| |_  ____ _____  __( (____
| |   | | |   | |/ _  | |/___)_   _)/ ___) ___ |/___)____ \
| |__/ /| |   | | |_| | |___ | | |_| |   | ____|___ |____) )
|_____/ |_|   |_|\____|_(___/   \__)_|   |_____(___(______/
</pre>
</td></tr></table>

EOF

    cat <<'EOF'
<p align="center">
  Harass your local Domain Name Server.
</p>

EOF

    emit_intro_explainers

    emit_static_example_run_section

    cat <<'EOF'
## Quick Start

- [install](#install)
- [examples](#examples)
- [usage](#usage)

## Index

EOF

    emit_index_group "General"

    emit_index_group "Commands"

    emit_index_group "Options"

    emit_development_index

    for t in "${README_TOPICS_ARR[@]}"; do

        emit_topic "$t"

    done

    emit_development_section

printf '\n---\n\n> Generated by [%s](scripts/%s) at %s.\n' \
    "$(basename -- "$0")" "$(basename -- "$0")" "$GENERATED_AT"
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

    printf '%s\n' "generated DNdistresS README.md"
    CONTENT_CHANGED=1
fi

print_topic_summary_group() {
    local group="$1"
    local label
    local t
    local printed=0

    label="$(printf '%s' "$group" | tr '[:upper:]' '[:lower:]')"
    printf '    - %s:\n' "$label"

    for t in "${README_TOPICS_ARR[@]}"; do

        [ "$(topic_group "$t")" = "$group" ] || continue

        printf '       - %s\n' "$t"
        printed=1
    done

    [ "$printed" -eq 1 ] || printf '       - (none)\n'

}

if [ "$CONTENT_CHANGED" -eq 1 ]; then
    printf '\n%s\n' " - summary:"
    printf '    - topics: %d\n' "${#README_TOPICS_ARR[@]}"

    print_topic_summary_group "General"

    print_topic_summary_group "Commands"

    print_topic_summary_group "Options"

    printf '    - development:\n'
    printf '       - contributing\n'
    printf '       - security\n'
    printf '       - smoke-test-suite\n'
    printf '       - bug-reports\n'
    printf '       - feature-requests\n'
    printf '       - pull-requests\n'

    printf '    - output: %s\n' "$OUT"
    printf '\n✓ documentation generated successfully.\n'
fi
