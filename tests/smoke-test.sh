#!/bin/sh

# smoke-test.sh - a suite of smoke tests for DNdistresS

set -eu

QUIET=0
STRICT=0
SUMMARY=0

usage() {
    printf 'Usage: %s [q|-q|quiet|--quiet] [s|-s|strict|--strict]\n' "${0##*/}"
}

while [ "$#" -gt 0 ]; do

    case "$1" in
        q|-q|quiet|--quiet)
            QUIET=1
            ;;
        s|-s|strict|--strict)
            STRICT=1
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

if [ "$QUIET" -eq 1 ]; then
    exec >/dev/null 2>&1
fi

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/DNdistresS"

pass=0
fail=0
skip_count=0

ok() {
    pass=$((pass + 1))

    [ "$SUMMARY" -eq 1 ] || printf ' - %s ✓\n' "$1"

}

not_ok() {
    fail=$((fail + 1))

    [ "$SUMMARY" -eq 1 ] || printf ' - %s ✗\n' "$1"

}

skip() {
    skip_count=$((skip_count + 1))

    [ "$SUMMARY" -eq 1 ] || printf ' - %s ↷\n' "$1"
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

assert_help_topic_ok() {
    name="$1"
    topic="$2"
    marker="${3:-}"

    set +e
    out="$("$SCRIPT" --help "$topic" 2>&1)"
    rc=$?
    set -e

    if [ "$rc" -eq 0 ] && [ -n "$out" ]; then

        ok "$name"

    else

        not_ok "$name"

        printf '  topic: [%s]\n  rc: [%s]\n' "$topic" "$rc"
        return 0
    fi

    if [ -n "$marker" ]; then

        assert_contains "${name} contains marker" "$out" "$marker"

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

assert_fail_cli() {
    name="$1"
    shift

    assert_fail_cmd "$name" run_script_quiet "$@"

}

run_fail_matrix() {

    while IFS='|' read -r name args; do

        [ -n "$name" ] || continue

        # shellcheck disable=SC2086
        assert_fail_cli "$name" $args

    done
}

assert_cmd_exit_code() {
    name="$1"
    want="$2"
    shift 2

    set +e
    "$@" >/dev/null 2>&1
    rc=$?
    set -e

    if [ "$rc" -eq "$want" ]; then

        ok "$name"

    else

        not_ok "$name"

        printf '  got rc : [%s]\n  want rc: [%s]\n' "$rc" "$want"
    fi
}

run_script_quiet() {
    "$SCRIPT" "$@" >/dev/null 2>&1
}

run_in_lib() (
    # shellcheck disable=SC2030
    export DNDISTRESS_TEST_MODE=1
    export _VERBOSITY=0
    # shellcheck disable=SC1090
    . "$SCRIPT"

    "$@" 2>/dev/null
)

has_lib_func() {
    fn="$1"

    run_in_lib command -v "$fn" >/dev/null 2>&1

}

SECTION_REPORT=""
_SECTION_ACTIVE=0
_SECTION_NAME=""
_SECTION_PASS_START=0
_SECTION_FAIL_START=0
_SECTION_SKIP_START=0

section_begin() {
    name="$1"

    if [ "$_SECTION_ACTIVE" -eq 1 ]; then

        section_end

    fi

    _SECTION_ACTIVE=1
    _SECTION_NAME="$name"
    _SECTION_PASS_START="$pass"
    _SECTION_FAIL_START="$fail"
    _SECTION_SKIP_START="$skip_count"

    [ "$SUMMARY" -eq 1 ] || printf '\n[%s]\n' "$_SECTION_NAME"

}

section_end() {
    [ "$_SECTION_ACTIVE" -eq 1 ] || return 0

    s_pass=$((pass - _SECTION_PASS_START))
    s_fail=$((fail - _SECTION_FAIL_START))
    s_skip=$((skip_count - _SECTION_SKIP_START))

    SECTION_REPORT="${SECTION_REPORT}${_SECTION_NAME}|${s_pass}|${s_fail}|${s_skip}
"

    [ "$SUMMARY" -eq 1 ] || printf '   section: %s (pass=%s fail=%s skip=%s)\n' "$_SECTION_NAME" "$s_pass" "$s_fail" "$s_skip"

    _SECTION_ACTIVE=0
    _SECTION_NAME=""
    _SECTION_PASS_START=0
    _SECTION_FAIL_START=0
    _SECTION_SKIP_START=0
}

print_section_report() {

    [ -n "$SECTION_REPORT" ] || return 0

    printf '\n[section summary]\n'

    printf '%s' "$SECTION_REPORT" | awk -F'|' '
        NF >= 4 && $1 != "" {
            n++
            name[n]  = $1
            spass[n] = $2 + 0
            sfail[n] = $3 + 0
            sskip[n] = $4 + 0

            total_pass += spass[n]
            total_fail += sfail[n]
            total_skip += sskip[n]

            ln = length(name[n])
            lp = length(spass[n] "")
            lf = length(sfail[n] "")

            if (ln > max_name) max_name = ln

            if (lp > max_pass) max_pass = lp

            if (lf > max_fail) max_fail = lf

        }

        END {
            tname = "total"

            for (i = 1; i <= n; i++) {
                name_pad = max_name - length(name[i]) + 1

                printf " - %s:%*spass=%-*d  fail=%-*d skip=%d\n",
                       name[i], name_pad, "",
                       max_pass, spass[i],
                       max_fail, sfail[i],
                       sskip[i]
            }

            if (n > 0) printf "\n"

            name_pad = max_name - length(tname) + 1

            printf " - %s:%*spass=%d fail=%d skip=%d\n",
                   tname, name_pad, "",
                   total_pass, total_fail, total_skip
        }
    '

}

run_if_all_lib_funcs() {
    missing=""

    while [ "$#" -gt 0 ]; do
        [ "$1" = "--" ] && shift && break

        if ! has_lib_func "$1"; then
            missing="${missing}${missing:+, }$1"
        fi

        shift
    done

    if [ -n "$missing" ]; then
        label="${1:-test-block}"

        skip "${label} skipped (missing lib function(s): ${missing})"

        return 0
    fi

    "$@"

}

run_if_lib_func() {
    fn="$1"
    shift

    if has_lib_func "$fn"; then
        "$@"
    else
        label="${1:-$fn}"

        skip "${label} skipped (missing lib function: ${fn})"

        return 0
    fi

}

strict_section_title() {
    base="${1##*/}"
    base="${base%.sh}"

    printf '%s\n' "$base" \
        | sed 's/^[0-9][0-9]*-//; s/[-_]/ /g'
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

test_canonical_help_topic_aliases() {
    assert_eq "canonical_help_topic maps --resolver-strategy" \
        "$(run_in_lib canonical_help_topic --resolver-strategy)" "resolver-strategy"

    assert_eq "canonical_help_topic maps log_mode" \
        "$(run_in_lib canonical_help_topic log_mode)" "log-mode"

    assert_eq "canonical_help_topic maps _DIG_OPTIONS_MODE" \
        "$(run_in_lib canonical_help_topic _DIG_OPTIONS_MODE)" "dig-options-mode"

    assert_fail_cmd "canonical_help_topic rejects unknown alias" \
        run_in_lib canonical_help_topic definitely-not-a-topic
}

section_begin "help"

assert_ok_cmd "script is executable" test -x "$SCRIPT"

while IFS='|' read -r topic marker; do

    [ -n "$topic" ] || continue

    assert_help_topic_ok "help topic: $topic" "$topic" "$marker"

done <<'EOF'
topics|Options:
general|Usage:
environment|Topic: environment
auto-tune|Topic: auto-tune
qps|queries/sec
random|Pool:
burst|token bucket
force-burst|Topic: force-burst
resolver-strategy|resolver
EOF

assert_ok_cmd "help reverse parsing: --help -q" run_script_quiet --help -q

assert_ok_cmd "help reverse parsing: -q --help" run_script_quiet -q --help

run_if_lib_func canonical_help_topic test_canonical_help_topic_aliases

section_end

run_timer_period() (
    # shellcheck disable=SC2031
    export DNDISTRESS_TEST_MODE=1
    # shellcheck disable=SC1090
    . "$SCRIPT"
    _TIMER_PERIOD="$1"

    timer_period_seconds

)

test_rand_int_range() {
    r="$(run_in_lib rand_int_range 5 10 2>/dev/null || true)"
    case "$r" in
        5|6|7|8|9|10)
            ok "rand_int_range returns value in range [5,10]"
            ;;
        *)
            not_ok "rand_int_range returns value in range [5,10]"
            printf '  got: [%s]\n' "$r"
            ;;
    esac

    assert_fail_cmd "rand_int_range rejects max < min" run_in_lib rand_int_range 10 5

    assert_fail_cmd "rand_int_range rejects non-integer min" run_in_lib rand_int_range abc 10

}

test_init_query_type_tracking() {
    # shellcheck disable=SC2016
    tracked="$(run_in_lib eval 'RANDOM_RR_POOL="a mx mx txt bad-type"; init_query_type_tracking; printf "%s\n" "$QTYPE_KEYS"')"

    assert_eq "init_query_type_tracking normalizes/dedupes pool" "$tracked" "A MX TXT"

}

test_is_ipv6_addr_basic() {

    assert_ok_cmd "is_ipv6_addr_basic validates IPv6" run_in_lib is_ipv6_addr_basic "::1"

}

test_is_local_ipv4() {

    assert_ok_cmd "is_local_ipv4 recognizes loopback" run_in_lib is_local_ipv4 "127.0.0.1"

    assert_ok_cmd "is_local_ipv4 recognizes private ranges" run_in_lib is_local_ipv4 "10.0.0.1"

}

test_is_port() {

    assert_ok_cmd "is_port accepts valid port 53" run_in_lib is_port "53"

    assert_ok_cmd "is_port accepts high port 65535" run_in_lib is_port "65535"

    assert_fail_cmd "is_port rejects 0" run_in_lib is_port "0"

    assert_fail_cmd "is_port rejects 65536" run_in_lib is_port "65536"

}

test_init_random_rr_pool() {

    assert_ok_cmd "init_random_rr_pool initializes pool" run_in_lib init_random_rr_pool

}

test_rr_type_from_id() {

    assert_eq "rr_type_from_id maps 1 to A" "$(run_in_lib rr_type_from_id 1)" "A"

    assert_eq "rr_type_from_id maps 28 to AAAA" "$(run_in_lib rr_type_from_id 28)" "AAAA"

    assert_fail_cmd "rr_type_from_id rejects invalid ID" run_in_lib rr_type_from_id 99999

}

test_parse_dns_opt() {
    parsed="$(run_in_lib eval "parse_dns_opt '1.1.1.1#5353'; printf '%s|%s\n' \"\$PARSED_DNS_HOST\" \"\$PARSED_DNS_PORT\"")"

    assert_eq "parse_dns_opt parses host#port" "$parsed" "1.1.1.1|5353"

    parsed="$(run_in_lib eval "parse_dns_opt '[2001:4860:4860::8888]:53'; printf '%s|%s\n' \"\$PARSED_DNS_HOST\" \"\$PARSED_DNS_PORT\"")"

    assert_eq "parse_dns_opt parses [ipv6]:port" "$parsed" "2001:4860:4860::8888|53"

    assert_fail_cmd "parse_dns_opt rejects invalid port" run_in_lib parse_dns_opt "1.1.1.1#99999"

    assert_fail_cmd "parse_dns_opt rejects unterminated [ipv6" run_in_lib parse_dns_opt "[::1"

    assert_fail_cmd "parse_dns_opt rejects unbalanced ipv6]" run_in_lib parse_dns_opt "::1]"

    assert_fail_cmd "parse_dns_opt rejects empty bracket host []:53" run_in_lib parse_dns_opt "[]:53"

    assert_fail_cmd "parse_dns_opt rejects missing port [::1]:" run_in_lib parse_dns_opt "[::1]:"

}

test_timer_period_seconds() {

    assert_eq "timer_period_seconds parses _TIMER_PERIOD override" "$(run_timer_period "1h 30m")" "5400"

    assert_fail_cmd "timer_period_seconds rejects invalid _TIMER_PERIOD" run_timer_period "banana"

}

test_validate_and_build_dig_options() {

    if ! command -v dig >/dev/null 2>&1; then
        return 0
    fi

    assert_fail_cmd "validate_and_build_dig_options rejects invalid mode" \
        run_in_lib eval '_BINARY=dig; _DIG_OPTIONS_MODE=nope; validate_and_build_dig_options'

    # shellcheck disable=SC2016
    effective="$(run_in_lib eval '
        _BINARY=dig
        _DIG_OPTIONS_MODE=append
        _DIG_OPTIONS="+time=2 +tries=1 custom-token"
        validate_and_build_dig_options
        printf "%s\n" "$DIG_OPTIONS_EFFECTIVE"
    ')"

    assert_contains "validate_and_build_dig_options append keeps +short" \
        "$effective" "+short"

    assert_contains "validate_and_build_dig_options append keeps custom token" \
        "$effective" "custom-token"

    # shellcheck disable=SC2016
    effective_replace="$(run_in_lib eval '
        _BINARY=dig
        _DIG_OPTIONS_MODE=replace
        _DIG_OPTIONS="+time=2 +tries=1"
        validate_and_build_dig_options
        printf "%s\n" "$DIG_OPTIONS_EFFECTIVE"
    ')"

    assert_contains "validate_and_build_dig_options replace auto-appends +short" \
        "$effective_replace" "+short"
}

test_compute_runtime_metrics_behavior() {

    assert_ok_cmd "compute_runtime_metrics runs with default state" \
        run_in_lib eval 'compute_runtime_metrics >/dev/null 2>&1'

    assert_ok_cmd "compute_runtime_metrics runs with synthetic counters" \
        run_in_lib eval '
            TOTAL_SENT=100
            TOTAL_OK=95
            TOTAL_FAIL=5
            compute_runtime_metrics >/dev/null 2>&1
        '

}

test_rand_u32() {
    r="$(run_in_lib rand_u32 2>/dev/null || true)"

    case "$r" in
        ''|*[!0-9]*)

            not_ok "rand_u32 returns a non-negative integer"

            printf '  got: [%s]\n' "$r"
            ;;
        *)

            ok "rand_u32 returns a non-negative integer"

            ;;
    esac

}

test_bump_query_type_count() {
    # shellcheck disable=SC2016
    counted="$(run_in_lib eval '
        QUERY_TYPE_FILE="${TMPDIR:-/tmp}/DNdistresS-qtypes.$$"
        : > "$QUERY_TYPE_FILE"
        _RANDOM=1
        bump_query_type_count a
        bump_query_type_count mx
        bump_query_type_count "bad-type"
        sort "$QUERY_TYPE_FILE"
        rm -f "$QUERY_TYPE_FILE"
    ')"

    assert_contains "bump_query_type_count records normalized A" "$counted" "A"

    assert_contains "bump_query_type_count records normalized MX" "$counted" "MX"

    assert_contains "bump_query_type_count records OTHER for invalid type" "$counted" "OTHER"

    result="$(

        run_in_lib sh -c "
            QUERY_TYPE_FILE=\"\${TMPDIR:-/tmp}/DNdistresS-qtguard.$$\"
            : > \"\$QUERY_TYPE_FILE\"
            _RANDOM=0
            bump_query_type_count A
            wc -l < \"\$QUERY_TYPE_FILE\" | tr -d \" \"
            rm -f \"\$QUERY_TYPE_FILE\"
        "

    )"

    assert_eq "bump_query_type_count skips write when _RANDOM=0" "$result" "0"

}

test_is_ipv4_addr() {

    assert_ok_cmd "is_ipv4_addr validates valid IPv4" run_in_lib is_ipv4_addr "192.168.1.1"

    assert_fail_cmd "is_ipv4_addr rejects invalid IPv4" run_in_lib is_ipv4_addr "256.1.1.1"

}

test_is_valid_target_dir() {

    assert_fail_cmd "is_valid_target_dir rejects relative paths" run_in_lib is_valid_target_dir "./relative"

    assert_ok_cmd "is_valid_target_dir accepts absolute paths" run_in_lib is_valid_target_dir "/etc"

}

test_pick_query_type() {

    assert_ok_cmd "pick_query_type function exists" run_in_lib eval 'pick_query_type >/dev/null 2>&1'

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

}

test_pick_query_type_pool_override() {
    picked="$(

        run_in_lib eval "_RANDOM=1; _TYPE=A; RANDOM_RR_POOL='AAAA CNAME MX NS TXT'; init_random_rr_pool; pick_query_type; printf '%s\n' \"\$PICKED_QTYPE\""

    )"

    case "$picked" in
        AAAA|CNAME|MX|NS|TXT)

            ok "pick_query_type respects RANDOM_RR_POOL override"

            ;;
        *)

            not_ok "pick_query_type respects RANDOM_RR_POOL override"

            printf "  got unexpected RR type: [%s]\n" "$picked"
            ;;
    esac

}

test_make_tmpdir() {
    tmp_base="${TMPDIR:-/tmp}/DNdistresS-smoke.$$"

    mkdir -p "$tmp_base"

    made_tmp="$(run_in_lib make_tmpdir "$tmp_base")"

    case "$made_tmp" in
        "$tmp_base"/*)

            if [ -d "$made_tmp" ]; then

                ok "make_tmpdir creates directory beneath requested base"

            else

                not_ok "make_tmpdir creates directory beneath requested base"

                printf "  returned path is not a directory: [%s]\n" "$made_tmp"
            fi

            ;;
        *)

            not_ok "make_tmpdir creates directory beneath requested base"

            printf "  got path outside base: [%s]\n" "$made_tmp"
            ;;
    esac

    rm -rf "$made_tmp" "$tmp_base"

}

test_apply_concurrency_safety_clamps() {
    result="$(run_in_lib eval "_QPS=10; _BURST=100; _FORCE_BURST=0; _MAXIMUM=5; _FORCE_MAXIMUM=0; apply_concurrency_safety_clamps; printf '%s\n' \"\$_BURST\"")"

    assert_eq "apply_concurrency_safety_clamps clamps burst to QPS*2" "$result" "20"

    result="$(run_in_lib eval "_QPS=10; _BURST=100; _FORCE_BURST=1; _MAXIMUM=5; _FORCE_MAXIMUM=0; apply_concurrency_safety_clamps; printf '%s\n' \"\$_BURST\"")"

    assert_eq "apply_concurrency_safety_clamps respects _FORCE_BURST=1" "$result" "100"

    result="$(run_in_lib eval "_QPS=10; _BURST=10; _FORCE_BURST=0; _MAXIMUM=500; _FORCE_MAXIMUM=0; apply_concurrency_safety_clamps; printf '%s\n' \"\$_MAXIMUM\"")"

    assert_eq "apply_concurrency_safety_clamps clamps maximum to 128" "$result" "128"

    result="$(run_in_lib eval "_QPS=10; _BURST=10; _FORCE_BURST=0; _MAXIMUM=500; _FORCE_MAXIMUM=1; apply_concurrency_safety_clamps; printf '%s\n' \"\$_MAXIMUM\"")"

    assert_eq "apply_concurrency_safety_clamps respects _FORCE_MAXIMUM=1" "$result" "500"

    result="$(run_in_lib eval "_QPS=20; _BURST=4; _FORCE_BURST=0; _MAXIMUM=2; _FORCE_MAXIMUM=0; _DIG_BATCH_SIZE=16; apply_concurrency_safety_clamps; printf '%s\n' \"\$_DIG_BATCH_SIZE_EFFECTIVE\"")"

    assert_eq "apply_concurrency_safety_clamps clamps _DIG_BATCH_SIZE_EFFECTIVE to _BURST" "$result" "4"

}

test_latency_stats_file() {
    # shellcheck disable=SC2016
    out_edges="$(run_in_lib eval '
        f="${TMPDIR:-/tmp}/DNdistresS-latstats-edges.$$"
        printf "%s\n" 10 20 30 40 100 > "$f"
        latency_stats_file "$f" 0 50 edges1
        rm -f "$f"
    ' 2>/dev/null || true)"

    out_edges_fmt="$(printf '%s\n' "$out_edges" | awk 'NF{printf "%s|%s|%s|%s\n",$1,$2,$3,$4; exit}')"

    assert_eq "latency_stats_file edges1 trims min/max and reports stats" \
        "$out_edges_fmt" "30.00|30|30|3"

    # shellcheck disable=SC2016
    out_pct="$(run_in_lib eval '
        f="${TMPDIR:-/tmp}/DNdistresS-latstats-pct.$$"
        printf "%s\n" 10 20 30 40 100 > "$f"
        latency_stats_file "$f" 20 95 percent
        rm -f "$f"
    ' 2>/dev/null || true)"

    out_pct_fmt="$(printf '%s\n' "$out_pct" | awk 'NF{printf "%s|%s|%s|%s\n",$1,$2,$3,$4; exit}')"

    assert_eq "latency_stats_file percent mode trims and computes percentile" \
        "$out_pct_fmt" "30.00|30|40|3"

    assert_fail_cmd "latency_stats_file fails on unreadable file" \
        run_in_lib latency_stats_file "/definitely/not/a/file"

}

test_resolver_targets_for_dispatch() {
    out="$(run_in_lib eval '
        _REMOTE_POOL="1.1.1.1#53
8.8.8.8#53
9.9.9.9#53"
        _RESOLVER_STRATEGY=parallel
        resolver_targets_for_dispatch remote | wc -l | tr -d " "
    ' 2>/dev/null || true)"

    assert_eq "resolver_targets_for_dispatch returns full pool in parallel mode" "$out" "3"

}

test_compute_dispatch_profile_parallel() {
    # shellcheck disable=SC2016
    out="$(run_in_lib eval '
        _REMOTE_POOL="1.1.1.1#53
8.8.8.8#53
9.9.9.9#53"
        _RESOLVER_STRATEGY=parallel
        _BURST=2
        _BURST_EFFECTIVE=2
        _DIG_BATCH=1
        _DIG_BATCH_SIZE=2
        _DIG_BATCH_SIZE_EFFECTIVE=2
        compute_dispatch_profile remote || exit 1
        printf "%s|%s|%s|%s|%s|%s\n" \
            "$DISPATCH_FANOUT" \
            "$DISPATCH_TOKEN_COST" \
            "$DISPATCH_BURST_LOGICAL" \
            "$_BURST" \
            "$_DIG_BATCH_SIZE_EFFECTIVE" \
            "$DIG_BATCH_LOGICAL_SIZE_EFFECTIVE"
    ' 2>/dev/null || true)"

    assert_eq "compute_dispatch_profile parallel applies global budget semantics" \
        "$out" "3|3|1|3|3|1"
}

test_select_fastest_resolver() {
    # shellcheck disable=SC2016
    out="$(run_in_lib eval '
        TMPD="${TMPDIR:-/tmp}/DNdistresS-fastest.$$"
        mkdir -p "$TMPD"
        TMPDIR="$TMPD"
        domains="$TMPD/domains.txt"
        printf "%s\n" example.com example.net > "$domains"

        _TYPE=A
        _RANDOM=0
        _OUTPUT=quiet
        _FASTEST_PROBE_COUNT=5
        _FASTEST_PROBE_DOMAIN=random
        _REMOTE_POOL="1.1.1.1#53
9.9.9.9#53
8.8.8.8#53"

        FAKE_NOW=0

        mono_ms() {
            printf "%s\n" "$FAKE_NOW"
        }

        query_one() {
            h="$4"

            case "$h" in
                1.1.1.1)
                    FAKE_NOW=$((FAKE_NOW + 10))
                    ;;
                9.9.9.9)
                    FAKE_NOW=$((FAKE_NOW + 20))
                    ;;
                8.8.8.8)
                    FAKE_NOW=$((FAKE_NOW + 30))
                    ;;
                *)
                    FAKE_NOW=$((FAKE_NOW + 50))
                    ;;
            esac

            return 0
        }

        select_fastest_resolver remote "$domains" || exit 1
        printf "%s|%s|%s\n" "$RESOLVER" "$_PORT" "$_REMOTE_POOL"

        rm -rf "$TMPD"

    ' 2>/dev/null || true)"

    assert_eq "select_fastest_resolver picks lowest-latency endpoint" "$out" "1.1.1.1|53|1.1.1.1#53"

}

test_parse_resolver_cli_and_pool_helpers() {
    # shellcheck disable=SC2016
    out="$(run_in_lib eval '
        _LOCAL_POOL=""
        _REMOTE_POOL=""
        _LOCATION="auto"
        _LOCATION_FORCED=0
        _LOCATION_EXPLICIT=0
        _PORT=53
        SEEN_L=0
        SEEN_R=0

        parse_resolver_cli_arg local --local "127.0.0.1,127.0.0.1#53,[::1]:54" || exit 1

        printf "%s|%s|%s|%s|%s\n" \
            "$(pool_count "$_LOCAL_POOL")" \
            "$(pool_nth "$_LOCAL_POOL" 1)" \
            "$(pool_nth "$_LOCAL_POOL" 2)" \
            "$_PORT" \
            "$_LOCATION"
    ' 2>/dev/null || true)"

    assert_eq "parse_resolver_cli_arg local list dedupes and sets location/port" \
        "$out" "2|127.0.0.1#53|::1#54|54|local"

    assert_fail_cmd "parse_resolver_cli_arg rejects malformed resolver token" \
        run_in_lib eval 'parse_resolver_cli_arg local --local "[::1"'
}

test_validate_pool_for_mode_zoneid() {
    assert_ok_cmd "validate_pool_for_mode local-strict allows link-local zone id" \
        run_in_lib eval '_LOCAL_POOL="fe80::1%eth0#53"; validate_pool_for_mode local local-strict'

    assert_fail_cmd "validate_pool_for_mode dns rejects zone id in local pool" \
        run_in_lib eval '_LOCAL_POOL="fe80::1%eth0#53"; validate_pool_for_mode local dns'

    assert_fail_cmd "validate_pool_for_mode dns rejects zone id in remote pool" \
        run_in_lib eval '_REMOTE_POOL="fe80::1%eth0#53"; validate_pool_for_mode remote dns'

    assert_ok_cmd "validate_pool_for_mode dns accepts global IPv6" \
        run_in_lib eval '_REMOTE_POOL="2001:4860:4860::8888#53"; validate_pool_for_mode remote dns'
}

test_fetch_source_cache_lifecycle() {
    # shellcheck disable=SC2016
    out="$(run_in_lib eval '
        t="${TMPDIR:-/tmp}/DNdistresS-fetch.$$"
        mkdir -p "$t"

        _FILE=""
        _URL="https://example.invalid/source.txt"
        _DIRECTORY="$t/cache"
        _SECONDS=60

        dl=0
        download_file() { dl=$((dl + 1)); printf "payload-%s\n" "$dl" > "$2"; }
        validate_zip_file() { return 0; }

        now_idx=0
        now_ms() {
            now_idx=$((now_idx + 1))
            case "$now_idx" in
                1) printf "%s\n" 100000 ;;
                2) printf "%s\n" 120000 ;;
                3) printf "%s\n" 250000 ;;
                4) printf "%s\n" 260000 ;;
                5) printf "%s\n" 270000 ;;
                *) printf "%s\n" 270000 ;;
            esac
        }

        d1="$t/d1"; d2="$t/d2"; d3="$t/d3"; d4="$t/d4"; d5="$t/d5"

        fetch_source "$d1" || exit 1
        c1="$dl"

        fetch_source "$d2" || exit 1
        c2="$dl"

        key="$(printf "%s\n" "$_URL" | cksum | awk "{ print \$1 }")"
        printf "%s\n" "nope" > "$_DIRECTORY/$key.stamp"

        fetch_source "$d3" || exit 1
        c3="$dl"

        _SECONDS=0

        fetch_source "$d4" || exit 1
        c4="$dl"

        fetch_source "$d5" || exit 1
        c5="$dl"

        printf "%s|%s|%s|%s|%s\n" "$c1" "$c2" "$c3" "$c4" "$c5"

        rm -rf "$t"
    ' 2>/dev/null || true)"

    assert_eq "fetch_source cache lifecycle (hit/stale/_SECONDS=0/stamp-parse-fail)" \
        "$out" "1|1|2|3|4"
}

test_enforce_file_ceiling() {
    # shellcheck disable=SC2016
    assert_ok_cmd "enforce_file_ceiling passes when size == max" \
        run_in_lib eval '
            f="${TMPDIR:-/tmp}/DNdistresS-ceiling-ok.$$"
            printf "%s" "12345" > "$f"
            enforce_file_ceiling "$f" 5 "test"
            rc=$?
            rm -f "$f"
            exit "$rc"
        '

    # shellcheck disable=SC2016
    assert_fail_cmd "enforce_file_ceiling fails when size > max" \
        run_in_lib eval '
            f="${TMPDIR:-/tmp}/DNdistresS-ceiling-fail.$$"
            printf "%s" "123456" > "$f"
            enforce_file_ceiling "$f" 5 "test"
            rc=$?
            rm -f "$f"
            exit "$rc"
        '
}

test_max_domains_lines_ceiling_cli() {
    if ! command -v dig >/dev/null 2>&1 && ! command -v nslookup >/dev/null 2>&1; then
        skip "_MAX_DOMAINS_LINES CLI ceiling check skipped (dig/nslookup unavailable)"
        return 0
    fi

    f="${TMPDIR:-/tmp}/DNdistresS-max-lines.$$"
    printf '%s\n' "example.com" "example.net" > "$f"

    assert_cmd_exit_code "_MAX_DOMAINS_LINES ceiling triggers EXIT_RUNTIME" 1 \
        env _MAX_DOMAINS_LINES=1 "$SCRIPT" -f "$f" -F plain -t 2 -q 1 -D 1

    rm -f "$f"
}

test_extract_domain_semantics() {
    # shellcheck disable=SC2016
    got_plain="$(run_in_lib eval '
        _FORMAT=plain
        _COLUMN=0
        printf "%s\n" \
            "Example.COM." \
            "-bad.com" \
            "ok-domain.org" \
            "bad..dots" \
            "a_b.example" \
            "ok.net" \
            | extract_domains | paste -sd, -
    ' 2>/dev/null || true)"

    assert_eq "extract_domains plain mode normalizes/trims/rejects invalid labels" \
        "$got_plain" "example.com,ok-domain.org,ok.net"

    # shellcheck disable=SC2016
    got_custom="$(run_in_lib eval '
        printf "%s\n" \
            " Foo.com. #comment" \
            "# full-line comment" \
            "bad..x" \
            "ok.net" \
            | extract_custom_domains | paste -sd, -
    ' 2>/dev/null || true)"

    assert_eq "extract_custom_domains strips comments and normalizes" \
        "$got_custom" "foo.com,ok.net"
}

test_fetch_source_lock_contention() {
    # shellcheck disable=SC2016
    out="$(run_in_lib eval '
        t="${TMPDIR:-/tmp}/DNdistresS-fetch-lock.$$"
        mkdir -p "$t"

        _FILE=""
        _URL="https://example.invalid/lock.txt"
        _DIRECTORY="$t/cache"
        _SECONDS=60

        download_file() {
            printf "%s\n" "payload" > "$2"
        }

        validate_zip_file() {
            return 0
        }

        mkdir -p "$_DIRECTORY"

        key="$(printf "%s\n" "$_URL" | cksum | awk "{ print \$1 }")"
        lock="$_DIRECTORY/$key.lock.d"

        mkdir -p "$lock"

        ( sleep 0.2; rmdir "$lock" 2>/dev/null || true ) &

        fetch_source "$t/out" || exit 1

        [ -n "$FETCH_SOURCE_PATH" ] || exit 1

        [ -f "$FETCH_SOURCE_PATH" ] || exit 1

        printf "%s\n" "ok"

        rm -rf "$t"
    ' 2>/dev/null || true)"

    assert_eq "fetch_source acquires lock after transient contention" "$out" "ok"

}

test_worker_pool_lifecycle_and_timeout() {
    # shellcheck disable=SC2016
    out="$(run_in_lib eval '
        t="${TMPDIR:-/tmp}/DNdistresS-workers.$$"

        mkdir -p "$t"

        TMPDIR="$t"
        ANSWERS_FILE="$t/answers.txt"
        : > "$ANSWERS_FILE"

        DRAIN_FORCED=0

        query_one() {
            d="$1"
            out_file="$3"
            printf "%s\n" "$d" >> "$out_file"
            return 0
        }

        start_worker_pool 2 || exit 1

        enqueue_job "A|example.com|127.0.0.1|53" || exit 1

        enqueue_job "A|example.net|127.0.0.1|53" || exit 1

        stop_worker_pool graceful 500 || exit 1

        sum_completed_shards

        first_completed="$COMPLETED"

        start_worker_pool 1 || exit 1

        pid="$WORKER_PIDS"

        kill -STOP "$pid" 2>/dev/null || true

        stop_worker_pool graceful 50 || exit 1

        printf "%s|%s|%s\n" "$first_completed" "${DRAIN_FORCED:-0}" "$WORKER_COUNT"

        rm -rf "$t"

    ' 2>/dev/null || true)"

    assert_eq "worker pool lifecycle and drain-timeout force path" "$out" "2|1|0"

}

test_cleanup_all_idempotent() {
    # shellcheck disable=SC2016
    out="$(run_in_lib eval '
        t="${TMPDIR:-/tmp}/DNdistresS-cleanup.$$"

        mkdir -p "$t"

        TMPDIR="$t"
        CLEANED=0
        WORKER_PIDS=""
        WORKER_FIFOS=""
        WORKER_COUNT=0
        WORKER_NEXT=1

        FETCH_CACHE_TMP="$TMPDIR/pending.tmp"
        : > "$FETCH_CACHE_TMP"

        cleanup_all graceful 0 || exit 1

        [ "$CLEANED" -eq 1 ] || exit 1

        cleanup_all graceful 0 || exit 1

        if [ -d "$TMPDIR" ]; then
            printf "%s\n" "still-there"
        else
            printf "%s\n" "gone"
        fi

    ' 2>/dev/null || true)"

    assert_eq "cleanup_all is idempotent and removes temp dir" "$out" "gone"

}

test_extract_zip_ceiling() {

    if ! command -v zip >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then

        skip "zip extract ceiling check skipped (zip/unzip unavailable)"

        return 0
    fi

    # shellcheck disable=SC2016
    out="$(run_in_lib eval '
        t="${TMPDIR:-/tmp}/DNdistresS-zip-ceiling.$$"

        mkdir -p "$t"

        payload="$t/payload.txt"
        printf "%s\n" "0123456789" > "$payload"

        ( cd "$t" && zip -q src.zip payload.txt ) || exit 1

        _MAX_EXTRACT_BYTES=5

        if extract_zip_to_file "$t/src.zip" "$t/out.txt"; then
            printf "%s\n" "unexpected-pass"
        else
            printf "%s\n" "expected-fail"
        fi

        rm -rf "$t"
    ' 2>/dev/null || true)"

    assert_eq "extract_zip_to_file enforces _MAX_EXTRACT_BYTES ceiling" "$out" "expected-fail"

}

test_on_abort_exit_code_cli() {

    if ! command -v dig >/dev/null 2>&1 && ! command -v nslookup >/dev/null 2>&1; then

        skip "abort signal contract skipped (dig/nslookup unavailable)"

        return 0
    fi

    f="${TMPDIR:-/tmp}/DNdistresS-abort.$$"
    printf '%s\n' "example.com" > "$f"

    set +e
    "$SCRIPT" -f "$f" -F plain -t 1 -q 1 -D 0 >/dev/null 2>&1 &
    pid=$!

    sleep 0.3

    kill -INT "$pid" >/dev/null 2>&1 || true

    waited=0

    while kill -0 "$pid" >/dev/null 2>&1; do

        sleep 0.1

        waited=$((waited + 1))

        [ "$waited" -lt 50 ] || break

    done

    if kill -0 "$pid" >/dev/null 2>&1; then
        kill -KILL "$pid" >/dev/null 2>&1 || true
    fi

    wait "$pid"
    rc=$?
    set -e

    rm -f "$f"

    assert_eq "SIGINT abort path exits with 130" "$rc" "130"

}

test_stop_reason_exit_code_mapping_fault_injected() {

    if command -v dig >/dev/null 2>&1; then
        test_bin="dig"
    elif command -v nslookup >/dev/null 2>&1; then
        test_bin="nslookup"
    else

        skip "fault-injected stop-reason mapping skipped (dig/nslookup unavailable)"

        return 0
    fi

    # shellcheck disable=SC2016
    rc_resolver="$(run_in_lib eval '
        _BINARY="'"$test_bin"'"

        f="${TMPDIR:-/tmp}/DNdistresS-fi-resolver.$$"
        printf "%s\n" "example.com" > "$f"

        DNDISTRESS_TEST_FAULT_STOP_REASON="resolver-pick-fail"
        DNDISTRESS_TEST_FAULT_USED=0

        set +e
        do_DNdistresS -f "$f" -F plain -t 1 -q 1 -D 1 >/dev/null 2>&1
        rc=$?
        set -e

        rm -f "$f"

        printf "%s\n" "$rc"
    ' 2>/dev/null || true)"

    assert_eq "fault-injected resolver-pick-fail maps to EXIT_RESOLVER" "$rc_resolver" "7"

    # shellcheck disable=SC2016
    rc_queue="$(run_in_lib eval '
        _BINARY="'"$test_bin"'"

        f="${TMPDIR:-/tmp}/DNdistresS-fi-queue.$$"
        printf "%s\n" "example.com" > "$f"

        DNDISTRESS_TEST_FAULT_STOP_REASON="queue-fail"
        DNDISTRESS_TEST_FAULT_USED=0

        set +e
        do_DNdistresS -f "$f" -F plain -t 1 -q 1 -D 1 >/dev/null 2>&1
        rc=$?
        set -e

        rm -f "$f"

        printf "%s\n" "$rc"
    ' 2>/dev/null || true)"

    assert_eq "fault-injected queue-fail maps to EXIT_QUEUE" "$rc_queue" "8"
}

section_begin "randomness"

run_if_lib_func rand_int_range test_rand_int_range

run_if_lib_func init_random_rr_pool test_init_random_rr_pool

run_if_lib_func init_query_type_tracking test_init_query_type_tracking

run_if_lib_func rand_u32 test_rand_u32

run_if_lib_func bump_query_type_count test_bump_query_type_count

section_end

section_begin "validators"

run_if_lib_func is_ipv4_addr test_is_ipv4_addr

run_if_lib_func is_ipv6_addr_basic test_is_ipv6_addr_basic

run_if_lib_func is_local_ipv4 test_is_local_ipv4

run_if_lib_func is_port test_is_port

run_if_lib_func is_valid_target_dir test_is_valid_target_dir

run_if_lib_func make_tmpdir test_make_tmpdir

section_end

section_begin "resolver"

run_if_lib_func rr_type_from_id test_rr_type_from_id

run_if_lib_func pick_query_type test_pick_query_type

run_if_all_lib_funcs pick_query_type init_random_rr_pool -- test_pick_query_type_pool_override

run_if_all_lib_funcs parse_resolver_cli_arg pool_count pool_nth append_pool_unique -- test_parse_resolver_cli_and_pool_helpers

run_if_lib_func validate_pool_for_mode test_validate_pool_for_mode_zoneid

run_if_lib_func parse_dns_opt test_parse_dns_opt

run_if_lib_func latency_stats_file test_latency_stats_file

run_if_lib_func resolver_targets_for_dispatch test_resolver_targets_for_dispatch

run_if_lib_func compute_dispatch_profile test_compute_dispatch_profile_parallel

run_if_lib_func select_fastest_resolver test_select_fastest_resolver

section_end

section_begin "lib-parsers"

skip "parse_burst_opt coverage handled by CLI burst parsing checks"

run_if_lib_func timer_period_seconds test_timer_period_seconds

skip "calendar_alias_seconds covered indirectly via timer_period_seconds"

run_if_lib_func compute_runtime_metrics test_compute_runtime_metrics_behavior

run_if_lib_func validate_and_build_dig_options test_validate_and_build_dig_options

run_if_lib_func fetch_source test_fetch_source_cache_lifecycle

run_if_lib_func fetch_source test_fetch_source_lock_contention

run_if_lib_func extract_domains test_extract_domain_semantics

section_end

section_begin "parsers"

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

    not_ok "library parser tests skipped"

    printf "  functions unavailable after refactor\n"

fi

assert_eq "filter no filters returns all" "$(run_filter_count '')" "6"

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

run_fail_matrix <<'EOF'
CLI invalid --location value fails|--location nowhere
CLI invalid --dig-options-mode value fails|--dig-options-mode nope
CLI invalid --resolver-strategy value fails|--resolver-strategy nope
random mode conflicts with TYPE MX|--random --type MX
TYPE ANY is denied by default|-T ANY -f /dev/null -F plain -t 1 -q 1 -D 1
TYPE 255 (ANY) is denied by default|-T 255 -f /dev/null -F plain -t 1 -q 1 -D 1
EOF

section_end

section_begin "safety"

run_if_lib_func apply_concurrency_safety_clamps test_apply_concurrency_safety_clamps

run_if_lib_func enforce_file_ceiling test_enforce_file_ceiling

run_if_lib_func extract_zip_to_file test_extract_zip_ceiling

test_max_domains_lines_ceiling_cli

section_end

section_begin "runtime"

if command -v nslookup >/dev/null 2>&1; then
    tmp_domains_ns="${TMPDIR:-/tmp}/DNdistresS-smoke-ns.$$"
    printf '%s\n' "example.com" > "$tmp_domains_ns"

    assert_fail_cmd "strict dig-options fails when binary is nslookup" \
        env _BINARY=nslookup _STRICT_DIG_OPTIONS=1 "$SCRIPT" --dig-options +short -f "$tmp_domains_ns" -F plain -t 1 -q 1 -D 1 >/dev/null 2>&1

    assert_ok_cmd "non-strict dig-options is tolerated with nslookup" \
        env _BINARY=nslookup _STRICT_DIG_OPTIONS=0 "$SCRIPT" --dig-options +short -f "$tmp_domains_ns" -F plain -t 1 -q 1 -D 1 >/dev/null 2>&1

    assert_ok_cmd "batch request is tolerated and disabled with nslookup" \
        env _BINARY=nslookup "$SCRIPT" --batch 8 -f "$tmp_domains_ns" -F plain -t 1 -q 1 -D 1 >/dev/null 2>&1

    rm -f "$tmp_domains_ns"

fi

if command -v dig >/dev/null 2>&1 || command -v nslookup >/dev/null 2>&1; then
    tmp_domains="${TMPDIR:-/tmp}/DNdistresS-smoke-domains.$$"
    printf '%s\n' "example.com" > "$tmp_domains"

    out="$("$SCRIPT" -V 5 -f "$tmp_domains" -F plain -t 1 -q 1 -D 1 2>&1 || true)"

    assert_contains "auto-tune disabled emits trace skip log at V5" "$out" \
        "skipping auto-tune"

    out="$("$SCRIPT" --auto-tune -V 3 -f "$tmp_domains" -F plain -t 1 -q 1 -D 1 2>&1 || true)"

    assert_contains "auto-tune enabled emits warmup info log at V3" "$out" \
        "probing"

    assert_contains "auto-tune enabled emits derived info log at V3" "$out" \
        "derived _MAXIMUM="

    tmp_domains="${TMPDIR:-/tmp}/DNdistresS-smoke-domains2.$$"
    printf '%s\n' "example.com" > "$tmp_domains"

    out="$(
        _AUTO_TUNE_SAMPLES_MIN=3 _AUTO_TUNE_SAMPLES_MAX=5 \
        "$SCRIPT" --auto-tune -V 4 -f "$tmp_domains" -F plain -t 1 -q 1 -D 1 2>&1 || true
    )"

    assert_contains "auto-tune range clamps min when sample pool is smaller" \
        "$out" "_AUTO_TUNE_SAMPLES_MIN ("

    assert_contains "auto-tune range clamps max when sample pool is smaller" \
        "$out" "_AUTO_TUNE_SAMPLES_MAX ("

    rm -f "${TMPDIR:-/tmp}/DNdistresS-smoke-domains.$$" "$tmp_domains"

else

    ok "skip auto-tune runtime logging checks (dig/nslookup unavailable)"

fi

burst_help_out="$("$SCRIPT" --help burst 2>&1 || true)"

assert_contains "burst help mentions burst clamp concept" \
    "$burst_help_out" "capped"

assert_contains "burst help includes QPS clamp multiplier" \
    "$burst_help_out" "_QPS * 2"

assert_ok_cmd "burst option -B 50 parses without error" \
    run_script_quiet -B 50 --help burst

assert_ok_cmd "burst option -B 100! parses with force override" \
    run_script_quiet -B 100! --help burst

force_burst_help_out="$("$SCRIPT" --help force-burst 2>&1 || true)"

assert_contains "force-burst help describes clamp override" \
    "$force_burst_help_out" "Overrides the burst safety clamp"

version_out="$("$SCRIPT" --version 2>&1 || true)"

assert_contains "version output contains name/version prefix" "$version_out" "DNdistresS v"

warranty_out="$("$SCRIPT" show w 2>&1)"

assert_contains "show warranty shows warranty" "$warranty_out" "THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY"

conditions_out="$("$SCRIPT" show c 2>&1)"

assert_contains "show conditions shows conditions" "$conditions_out" "You may convey verbatim copies of the Program's source code as you"

run_if_all_lib_funcs start_worker_pool enqueue_job stop_worker_pool sum_completed_shards -- test_worker_pool_lifecycle_and_timeout

run_if_lib_func cleanup_all test_cleanup_all_idempotent

run_if_lib_func do_DNdistresS test_stop_reason_exit_code_mapping_fault_injected

test_on_abort_exit_code_cli

section_end

if [ "$STRICT" -eq 1 ]; then
    STRICT_DIR="$ROOT_DIR/tests/strict.d"

    if [ ! -d "$STRICT_DIR" ]; then

        section_begin "strict"

        not_ok "strict directory exists"

        printf '  missing dir: %s\n' "$STRICT_DIR"

        section_end

    else
        strict_list="${TMPDIR:-/tmp}/DNdistresS-strict-list.$$"

        rm -f "$strict_list"

        find "$STRICT_DIR" -type f -name '*.sh' 2>/dev/null | sort > "$strict_list"

        if [ ! -s "$strict_list" ]; then

            section_begin "strict"

            not_ok "strict tests discovered"

            printf '  no strict tests found in: %s\n' "$STRICT_DIR"

            section_end

        else

            while IFS= read -r strict_test; do

                [ -n "$strict_test" ] || continue

                name="${strict_test##*/}"
                title="$(strict_section_title "$name")"

                section_begin "$title"

                start="$(date +%s)"
                strict_out="${TMPDIR:-/tmp}/DNdistresS-strict-out.$$.$name"

                rm -f "$strict_out"

                set +e

                sh "$strict_test" "$SCRIPT" "$ROOT_DIR/README.md" >"$strict_out" 2>&1

                rc=$?
                set -e
                end="$(date +%s)"
                elapsed=$((end - start))

                strict_seen=0
                strict_fail_seen=0

                while IFS= read -r line || [ -n "$line" ]; do

                    case "$line" in
                        ok:\ *)

                            ok "${line#ok: }"

                            strict_seen=1
                            ;;
                        not\ ok:\ *)

                            not_ok "${line#not ok: }"

                            strict_seen=1
                            strict_fail_seen=1
                            ;;
                    esac

                done < "$strict_out"

                if [ "$strict_seen" -eq 0 ]; then

                    if [ "$rc" -eq 0 ]; then

                        ok "$name (${elapsed}s)"

                    else

                        not_ok "$name (${elapsed}s)"

                    fi

                elif [ "$rc" -ne 0 ] && [ "$strict_fail_seen" -eq 0 ]; then

                    not_ok "$name failed before reporting checks (${elapsed}s)"

                fi

                if [ "$rc" -ne 0 ] && [ "$SUMMARY" -ne 1 ]; then

                    sed -n '/^ok: /d;/^not ok: /d;p' "$strict_out" | sed 's/^/  /'

                fi

                rm -f "$strict_out"

                section_end

            done < "$strict_list"
        fi

        rm -f "$strict_list"

    fi

fi

print_section_report

[ "$fail" -eq 0 ] || exit 1
