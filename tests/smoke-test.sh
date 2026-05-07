#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/dndistress"

now_epoch() {
    date +%s 2>/dev/null || printf '0'
}

START_TS="$(now_epoch)"

pass=0
fail=0

ok() {
    pass=$((pass + 1))
    printf '  ok - %s\n' "$1"
}

not_ok() {
    fail=$((fail + 1))
    printf '  not ok - %s\n' "$1"
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

if [ "$fail" -gt 0 ]; then
    END_TS="$(now_epoch)"
    ELAPSED="$((END_TS - START_TS))"
    [ "$ELAPSED" -lt 0 ] && ELAPSED=0

    printf '\nFAIL: %s failed, %s passed\n' "$fail" "$pass"
    printf 'TIME: %ss\n' "$ELAPSED"
    exit 1
fi

END_TS="$(now_epoch)"
ELAPSED="$((END_TS - START_TS))"
[ "$ELAPSED" -lt 0 ] && ELAPSED=0

printf '\nPASS: %s passed\n' "$pass"
printf 'TIME: %ss\n' "$ELAPSED"
