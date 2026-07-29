#!/bin/sh

# smoke-test.sh - a suite of smoke tests for DNdistresS

set -eu

QUIET=0
STRICT=0
SUMMARY=0

while [ "$#" -gt 0 ]; do

    case "$1" in
        q|-q|quiet|--quiet)
            QUIET=1
            ;;
        s|-s|strict|--strict)
            STRICT=1
            ;;
        h|-h|help|--help)
            printf 'Usage: %s [q|-q|quiet|--quiet] [s|-s|strict|--strict]\n' "${0##*/}"
            exit 0
            ;;
        *)
            printf 'error: unknown option: %s\n' "$1" >&2
            printf 'Usage: %s [q|-q|quiet|--quiet] [s|-s|strict|--strict]\n' "${0##*/}" >&2
            exit 2
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

ok() {
    pass=$((pass + 1))

    [ "$SUMMARY" -eq 1 ] || printf ' - %s ✓\n' "$1"

}

not_ok() {
    fail=$((fail + 1))

    [ "$SUMMARY" -eq 1 ] || printf ' - %s ✗\n' "$1"

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

section_begin() {
    name="$1"

    if [ "$_SECTION_ACTIVE" -eq 1 ]; then

        section_end

    fi

    _SECTION_ACTIVE=1
    _SECTION_NAME="$name"
    _SECTION_PASS_START="$pass"
    _SECTION_FAIL_START="$fail"

    [ "$SUMMARY" -eq 1 ] || printf '\n[%s]\n' "$_SECTION_NAME"

}

section_end() {
    [ "$_SECTION_ACTIVE" -eq 1 ] || return 0

    s_pass=$((pass - _SECTION_PASS_START))
    s_fail=$((fail - _SECTION_FAIL_START))

    SECTION_REPORT="${SECTION_REPORT}${_SECTION_NAME}|${s_pass}|${s_fail}
"

    [ "$SUMMARY" -eq 1 ] || printf '   section: %s (pass=%s fail=%s)\n' "$_SECTION_NAME" "$s_pass" "$s_fail"

    _SECTION_ACTIVE=0
    _SECTION_NAME=""
    _SECTION_PASS_START=0
    _SECTION_FAIL_START=0
}

print_section_report() {

    [ -n "$SECTION_REPORT" ] || return 0

    printf '\n[section summary]\n'

    printf '%s' "$SECTION_REPORT" | awk -F'|' '
        NF >= 3 && $1 != "" {
            n++
            name[n]  = $1
            spass[n] = $2 + 0
            sfail[n] = $3 + 0

            total_pass += spass[n]
            total_fail += sfail[n]

            ln = length(name[n])
            lp = length(spass[n])

            if (ln > max_name) max_name = ln

            if (lp > max_pass) max_pass = lp

        }
        END {

            if (length("total") > max_name) max_name = length("total")

            if (length(total_pass) > max_pass) max_pass = length(total_pass)

            for (i = 1; i <= n; i++) {
                name_pad = max_name - length(name[i]) + 1
                pass_pad = max_pass - length(spass[i]) + 1

                printf " - %s:%*spass=%s%*sfail=%s\n",
                       name[i], name_pad, "",
                       spass[i], pass_pad, "",
                       sfail[i]
            }

            printf "\n"

            name_pad = max_name - length("total") + 1
            pass_pad = max_pass - length(total_pass) + 1

            printf " - total:%*spass=%s%*sfail=%s\n",
                   name_pad, "",
                   total_pass, pass_pad, "",
                   total_fail
        }
    '

}

run_if_all_lib_funcs() {

    while [ "$#" -gt 0 ]; do

        [ "$1" = "--" ] && shift && break

        has_lib_func "$1" || return 0

        shift
    done

    "$@"

}

run_if_lib_func() {
    fn="$1"
    shift

    if has_lib_func "$fn"; then
        "$@"
    else
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
EOF

assert_ok_cmd "help reverse parsing: --help -q" run_script_quiet --help -q

assert_ok_cmd "help reverse parsing: -q --help" run_script_quiet -q --help

section_end

run_timer_period() (
    # shellcheck disable=SC2031
    export DNDISTRESS_TEST_MODE=1
    # shellcheck disable=SC1090
    . "$SCRIPT"
    _TIMER_PERIOD="$1"

    timer_period_seconds

)

test_calendar_alias_seconds() {

    assert_eq "calendar_alias_seconds: minutely" "$(run_in_lib calendar_alias_seconds minutely)" "60"

    assert_eq "calendar_alias_seconds: hourly" "$(run_in_lib calendar_alias_seconds hourly)" "3600"

    assert_eq "calendar_alias_seconds: daily" "$(run_in_lib calendar_alias_seconds daily)" "86400"

    assert_eq "calendar_alias_seconds: weekly" "$(run_in_lib calendar_alias_seconds weekly)" "604800"

    assert_fail_cmd "calendar_alias_seconds rejects unknown alias" run_in_lib calendar_alias_seconds "not-a-thing"

}

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

test_is_absolute_path() {

    assert_fail_cmd "is_absolute_path rejects relative paths" run_in_lib is_absolute_path "./relative"

    assert_ok_cmd "is_absolute_path accepts absolute paths" run_in_lib is_absolute_path "/etc/hosts"

}

test_init_random_rr_pool() {

    assert_ok_cmd "init_random_rr_pool initializes pool" run_in_lib init_random_rr_pool

}

test_rr_type_from_id() {

    assert_eq "rr_type_from_id maps 1 to A" "$(run_in_lib rr_type_from_id 1)" "A"

    assert_eq "rr_type_from_id maps 28 to AAAA" "$(run_in_lib rr_type_from_id 28)" "AAAA"

    assert_fail_cmd "rr_type_from_id rejects invalid ID" run_in_lib rr_type_from_id 99999

}

test_parse_burst_opt() {

    assert_ok_cmd "parse_burst_opt accepts positive integer" run_in_lib parse_burst_opt 32

    assert_fail_cmd "parse_burst_opt rejects zero" run_in_lib parse_burst_opt 0

    assert_fail_cmd "parse_burst_opt rejects negative" run_in_lib parse_burst_opt -5

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
        ok "validate_and_build_dig_options skipped (dig unavailable)"
        return 0
    fi

    assert_fail_cmd "validate_and_build_dig_options rejects invalid mode" \
        run_in_lib eval '_BINARY=dig; _DIG_OPTIONS_SET=1; _DIG_OPTIONS_MODE=wat; _DIG_OPTIONS="+short"; _STRICT_DIG_OPTIONS=0; validate_and_build_dig_options'

    # shellcheck disable=SC2016
    effective="$(run_in_lib eval '
        _BINARY=dig
        _DIG_OPTIONS_SET=1
        _DIG_OPTIONS_MODE=append
        _DIG_OPTIONS="+time=1"
        _STRICT_DIG_OPTIONS=1
        DIG_OPTIONS_EFFECTIVE=""
        validate_and_build_dig_options
        printf "%s\n" "$DIG_OPTIONS_EFFECTIVE"
    ')"

    assert_contains "validate_and_build_dig_options append keeps +short" \
        "$effective" "+short"

    assert_contains "validate_and_build_dig_options append keeps custom token" \
        "$effective" "+time=1"

    assert_fail_cmd "validate_and_build_dig_options strict replace requires +short" \
        run_in_lib eval '_BINARY=dig; _DIG_OPTIONS_SET=1; _DIG_OPTIONS_MODE=replace; _DIG_OPTIONS="+time=1"; _STRICT_DIG_OPTIONS=1; validate_and_build_dig_options'
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

run_if_lib_func is_absolute_path test_is_absolute_path

run_if_lib_func make_tmpdir test_make_tmpdir

section_end

section_begin "resolver"

run_if_lib_func rr_type_from_id test_rr_type_from_id

run_if_lib_func pick_query_type test_pick_query_type

run_if_all_lib_funcs pick_query_type init_random_rr_pool -- test_pick_query_type_pool_override

run_if_lib_func parse_dns_opt test_parse_dns_opt

section_end

section_begin "lib-parsers"

run_if_lib_func parse_burst_opt test_parse_burst_opt

run_if_lib_func timer_period_seconds test_timer_period_seconds

run_if_lib_func calendar_alias_seconds test_calendar_alias_seconds

run_if_lib_func compute_runtime_metrics test_compute_runtime_metrics_behavior

run_if_lib_func validate_and_build_dig_options test_validate_and_build_dig_options

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
random mode conflicts with TYPE MX|--random --type MX
TYPE ANY is denied by default|-T ANY -f /dev/null -F plain -t 1 -q 1 -D 1
TYPE 255 (ANY) is denied by default|-T 255 -f /dev/null -F plain -t 1 -q 1 -D 1
EOF

section_end

section_begin "safety"

run_if_lib_func apply_concurrency_safety_clamps test_apply_concurrency_safety_clamps

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
        "auto-tune disabled; skipping"

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

assert_ok_cmd "burst help shows QPS clamp rule" \
    run_script_quiet --help burst

assert_ok_cmd "burst option -B 50 parses without error" \
    run_script_quiet -B 50 --help burst

assert_ok_cmd "burst option -B 100! parses with force override" \
    run_script_quiet -B 100! --help burst

assert_ok_cmd "force-burst help topic resolves correctly" \
    run_script_quiet --help force-burst

version_out="$("$SCRIPT" --version 2>&1 || true)"

assert_contains "version output contains name/version prefix" "$version_out" "DNdistresS v"

warranty_out="$("$SCRIPT" show w 2>&1)"

assert_contains "show warranty shows warranty" "$warranty_out" "THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY"

conditions_out="$("$SCRIPT" show c 2>&1)"

assert_contains "show conditions shows conditions" "$conditions_out" "You may convey verbatim copies of the Program's source code as you"

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
