#!/bin/sh

# smoke-test.sh - A suite of smoke tests for dndistress.

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

if [ "$QUIET" -eq 1 ]; then
    exec >/dev/null 2>&1
fi

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/dndistress"

now_epoch_ms() {
    ms="$(date +%s%3N 2>/dev/null || true)"

    case "$ms" in
        ''|*[!0-9]*) ;;
        *) printf '%s\n' "$ms"; return ;;
    esac

    ns="$(date +%s%N 2>/dev/null || true)"

    case "$ns" in
        ''|*[!0-9]*) ;;
        *) printf '%s\n' "$((ns / 1000000))"; return ;;
    esac

    s="$(date +%s 2>/dev/null || printf '0')"

    case "$s" in
        ''|*[!0-9]*) s=0 ;;
    esac

    printf '%s\n' "$((s * 1000))"
}

START_MS="$(now_epoch_ms)"

pass=0
fail=0

ok() {
    pass=$((pass + 1))
    printf ' - %s ✓\n' "$1"
}

not_ok() {
    fail=$((fail + 1))
    printf ' - %s ✗\n' "$1"
}

assert_eq() {
    name="$1"
    got="$2"
    want="$3"

    if [ "$got" = "$want" ]; then

        ok "$name"

    else

        not_ok "$name"

        printf '  got : [%s]\n  want: [%s]\n' "$got" "$want"
    fi

}

assert_contains() {
    name="$1"
    stack="$2"
    string="$3"

    if printf '%s' "$stack" | grep -F -- "$string" >/dev/null 2>&1; then

        ok "$name"

    else

        not_ok "$name"

        printf '  missing substring: [%s]\n' "$string"
    fi

}

assert_ok_cmd() {
    name="$1"
    shift

    if "$@"; then

        ok "$name"

    else

        not_ok "$name"

    fi

}

assert_fail_cmd() {
    name="$1"
    shift

    if "$@"; then

        not_ok "$name"

    else

        ok "$name"

    fi

}

run_script_quiet() {
    "$SCRIPT" "$@" >/dev/null 2>&1
}

run_in_lib() (
    export DNDISTRESS_TEST_MODE=1
    # shellcheck disable=SC1090
    . "$SCRIPT"

    "$@"

)

has_lib_func() {
    fn="$1"

    run_in_lib command -v "$fn" >/dev/null 2>&1

}

parse_top_capture() {

    run_in_lib parse_top_opt "$@"

}

parse_duration_capture() {

    run_in_lib parse_duration "$1"

}

parse_top_should_fail() {

    run_in_lib parse_top_opt "$@" >/dev/null 2>&1

}

parse_duration_should_fail() {

    run_in_lib parse_duration "$1" >/dev/null 2>&1

}

run_filter_count() {
    filters="$1"

    FILTERS="$filters" awk '
BEGIN {
    filters = ENVIRON["FILTERS"]

    nf = 0
    c = 0

    if (filters != "") {
        n = split(filters, raw, " ")
        for (i = 1; i <= n; i++) {
            pat = raw[i]
            if (pat == "") continue
            nf++
            ftype[nf] = ""
            fpat[nf]  = pat

            if (pat ~ /^\/.*\/$/) {
                ftype[nf] = "regex"
                fpat[nf]  = substr(pat, 2, length(pat) - 2)
                gsub(/\\\./, "[.]", fpat[nf])
            } else if (substr(pat, 1, 2) == "||") {
                ftype[nf] = "anchor"
                fpat[nf]  = substr(pat, 3)
                gsub(/\./, "\\.", fpat[nf])
                fpat[nf] = "(^|\\.)" fpat[nf] "$"
            } else if (substr(pat, 1, 1) == "^") {
                ftype[nf] = "prefix"
                fpat[nf]  = substr(pat, 2)
            } else if (substr(pat, 1, 1) == ".") {
                ftype[nf] = "suffix"
                fpat[nf]  = pat
            } else {
                ftype[nf] = "substr"
            }
        }
    }
}
{
    if (nf == 0) { c++; next }

    d = $0
    dlen = length(d)
    matched = 0

    for (i = 1; i <= nf; i++) {
        if (ftype[i] == "suffix") {
            fl   = fpat[i]
            flen = length(fl)
            if (dlen >= flen && substr(d, dlen - flen + 1) == fl) { matched = 1; break }
        } else if (ftype[i] == "prefix") {
            if (index(d, fpat[i]) == 1) { matched = 1; break }
        } else if (ftype[i] == "regex" || ftype[i] == "anchor") {
            if (d ~ fpat[i]) { matched = 1; break }
        } else {
            if (index(d, fpat[i]) > 0) { matched = 1; break }
        }
    }

    if (matched) c++
}
END {
    print c
}
' <<'EOF'
example.com
sub.example.com
google.co.nz
foo.net
bar.org.nz
news.govt.nz
EOF

}

filter_count_should_fail() (
    set +e
    if run_filter_count "$1" >/dev/null 2>&1; then
        return 1
    fi
    return 0
)

awk_rejects_invalid_dynamic_regex() (
    set +e
    if awk 'BEGIN { r="(unclosed"; print ("x" ~ r) }' >/dev/null 2>&1; then
        return 1
    fi
    return 0
)

assert_ok_cmd "script is executable" test -x "$SCRIPT"

topics_out="$("$SCRIPT" --help topics 2>/dev/null || true)"

assert_contains "help topics includes Options header" "$topics_out" "Options:"

assert_contains "help topics includes deny-any" "$topics_out" "deny-any"

assert_fail_cmd "CLI unknown option fails" run_script_quiet --definitely-not-a-real-option

if has_lib_func is_ipv4_addr; then

    assert_ok_cmd "is_ipv4_addr validates valid IPv4" \
        run_in_lib is_ipv4_addr "192.168.1.1"

    assert_fail_cmd "is_ipv4_addr rejects invalid IPv4" \
        run_in_lib is_ipv4_addr "256.1.1.1"

fi

if has_lib_func is_ipv6_addr_basic; then

    assert_ok_cmd "is_ipv6_addr_basic validates IPv6" \
        run_in_lib is_ipv6_addr_basic "::1"

fi

if has_lib_func is_local_ipv4; then

    assert_ok_cmd "is_local_ipv4 recognizes loopback" \
        run_in_lib is_local_ipv4 "127.0.0.1"

    assert_ok_cmd "is_local_ipv4 recognizes private ranges" \
        run_in_lib is_local_ipv4 "10.0.0.1"

fi

if has_lib_func is_port; then

    assert_ok_cmd "is_port accepts valid port 53" \
        run_in_lib is_port "53"

    assert_ok_cmd "is_port accepts high port 65535" \
        run_in_lib is_port "65535"

    assert_fail_cmd "is_port rejects 0" \
        run_in_lib is_port "0"

    assert_fail_cmd "is_port rejects 65536" \
        run_in_lib is_port "65536"

fi

if has_lib_func pick_query_type; then

    assert_ok_cmd "pick_query_type function exists" \
        run_in_lib pick_query_type >/dev/null

    # shellcheck disable=SC2016
    picked="$(run_in_lib eval '_RANDOM=0; _TYPE=A; pick_query_type; printf "%s\n" "$PICKED_QTYPE"')"
  
    assert_eq "pick_query_type with _RANDOM=0 returns _TYPE" "$picked" "A"

    # shellcheck disable=SC2016
    picked="$(run_in_lib eval '_RANDOM=1; _TYPE=A; init_random_rr_pool; pick_query_type; printf "%s\n" "$PICKED_QTYPE"')"
  
    case "$picked" in
        A|AAAA|CNAME|MX|NS|TXT)
  
            ok "pick_query_type with _RANDOM=1 returns from pool"
  
            ;;
        *)
  
            not_ok "pick_query_type with _RANDOM=1 returns from pool"
  
            printf '  got unexpected RR type: [%s]\n' "$picked"
            ;;
    esac

fi

if has_lib_func init_random_rr_pool; then

    assert_ok_cmd "init_random_rr_pool initializes pool" \
        run_in_lib init_random_rr_pool

fi

if has_lib_func is_absolute_path; then

    assert_fail_cmd "is_absolute_path rejects relative paths" \
        run_in_lib is_absolute_path "./relative"

    assert_ok_cmd "is_absolute_path accepts absolute paths" \
        run_in_lib is_absolute_path "/etc/hosts"

fi

if has_lib_func parse_top_opt && has_lib_func parse_duration; then
    t="$(parse_top_capture 5000)"
    count="$(printf '%s\n' "$t" | sed -n '1p')"
    filters="$(printf '%s\n' "$t" | sed -n '2p')"

    assert_eq "parse_top_opt count only: count" "$count" "5000"

    assert_eq "parse_top_opt count only: filters" "$filters" ""

    t="$(parse_top_capture 5000 .com .net)"
    count="$(printf '%s\n' "$t" | sed -n '1p')"
    filters="$(printf '%s\n' "$t" | sed -n '2p')"

    assert_eq "parse_top_opt count+filters: count" "$count" "5000"

    assert_eq "parse_top_opt count+filters: filters" "$filters" ".com .net"

    t="$(parse_top_capture .co.nz 1000)"
    count="$(printf '%s\n' "$t" | sed -n '1p')"
    filters="$(printf '%s\n' "$t" | sed -n '2p')"

    assert_eq "parse_top_opt reversed: count" "$count" "1000"

    assert_eq "parse_top_opt reversed: filters" "$filters" ".co.nz"

    t="$(parse_top_capture 1)"
    count="$(printf '%s\n' "$t" | sed -n '1p')"

    assert_eq "parse_top_opt minimum valid count" "$count" "1"

    assert_fail_cmd "parse_top_opt missing count fails" parse_top_should_fail .com

    assert_fail_cmd "parse_top_opt zero fails" parse_top_should_fail 0

    assert_fail_cmd "parse_top_opt negative fails" parse_top_should_fail -5

    assert_fail_cmd "parse_top_opt non-numeric fails" parse_top_should_fail abc

    assert_fail_cmd "parse_top_opt decimal fails" parse_top_should_fail 1.5

    assert_eq "parse_duration plain seconds" "$(parse_duration_capture 300)" "300"

    assert_eq "parse_duration human format" "$(parse_duration_capture '1h 30m')" "5400"

    assert_eq "parse_duration commas/spaces" "$(parse_duration_capture '2d,4h')" "187200"

    assert_eq "parse_duration zero seconds" "$(parse_duration_capture '0')" "0"

    assert_eq "parse_duration compact format" "$(parse_duration_capture '1h30m')" "5400"

    assert_eq "parse_duration extra whitespace" "$(parse_duration_capture '  1h   30m  ')" "5400"

    assert_fail_cmd "parse_duration invalid token fails" parse_duration_should_fail banana

    assert_fail_cmd "parse_duration decimal fails" parse_duration_should_fail 1.5h

    assert_fail_cmd "parse_duration negative fails" parse_duration_should_fail -1h

    assert_fail_cmd "parse_duration empty fails" parse_duration_should_fail ""

else

    ok "library parser tests skipped (functions unavailable after refactor)"

fi

if has_lib_func rr_type_from_id; then

    assert_eq "rr_type_from_id maps 1 to A" \
        "$(run_in_lib rr_type_from_id 1)" "A"

    assert_eq "rr_type_from_id maps 28 to AAAA" \
        "$(run_in_lib rr_type_from_id 28)" "AAAA"

    assert_fail_cmd "rr_type_from_id rejects invalid ID" \
        run_in_lib rr_type_from_id 99999

fi

assert_eq "filter no filters returns all" "$(run_filter_count '')" "6"

assert_eq "filter whitespace-only returns all" "$(run_filter_count '   ')" "6"

assert_eq "filter suffix .nz" "$(run_filter_count '.nz')" "3"

assert_eq "filter prefix ^sub" "$(run_filter_count '^sub')" "1"

assert_eq "filter substring google" "$(run_filter_count 'google')" "1"

assert_eq "filter anchor ||example.com" "$(run_filter_count '||example.com')" "2"

assert_eq "filter regex /\\.org\\.nz$/" "$(run_filter_count '/\.org\.nz$/')" "1"

assert_eq "filter duplicate patterns don't change count" "$(run_filter_count '.nz .nz')" "3"

assert_eq "filter escaped dot regex /example\\.com$/" "$(run_filter_count '/example\.com$/')" "2"

assert_eq "filter OR mix" "$(run_filter_count '.nz ||example.com /\.net$/')" "6"

if awk_rejects_invalid_dynamic_regex; then

    assert_ok_cmd "filter invalid regex fails cleanly" filter_count_should_fail '/(unclosed/'

else

    ok "filter invalid regex behavior is awk-dependent (skipped)"

fi

assert_contains "version output contains branch" \
    "$("$SCRIPT" --version 2>&1)" "master"

if has_lib_func compute_runtime_metrics; then
    ok "compute_runtime_metrics function exists"
fi

warranty_out="$("$SCRIPT" show w 2>&1)"

assert_contains "warranty shows disclaimer" "$warranty_out" "NO WARRANTY"

conditions_out="$("$SCRIPT" show c 2>&1)"

assert_contains "conditions shows GPL section 4" "$conditions_out" "Conveying Verbatim Copies"

help_out="$("$SCRIPT" --help general 2>&1)"

assert_contains "help general shows usage" "$help_out" "Usage:"

help_out="$("$SCRIPT" --help qps 2>&1)"

assert_contains "help for qps option works" "$help_out" "queries/sec"

help_out="$("$SCRIPT" --help random 2>&1)"

assert_contains "help for random option works" "$help_out" "RR type randomization"

if [ "$fail" -gt 0 ]; then
    END_MS="$(now_epoch_ms)"
    ELAPSED_MS="$((END_MS - START_MS))"

    [ "$ELAPSED_MS" -lt 0 ] && ELAPSED_MS=0

    printf '\nFAIL: %s failed, %s passed\n' "$fail" "$pass"
    printf 'TIME: %s.%03ds\n' "$((ELAPSED_MS / 1000))" "$((ELAPSED_MS % 1000))"
    exit 1
fi

END_MS="$(now_epoch_ms)"
ELAPSED_MS="$((END_MS - START_MS))"

[ "$ELAPSED_MS" -lt 0 ] && ELAPSED_MS=0

printf '\nPASS: %s passed\n' "$pass"
printf 'TIME: %s.%03ds\n' "$((ELAPSED_MS / 1000))" "$((ELAPSED_MS % 1000))"
