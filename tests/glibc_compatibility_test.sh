#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
INSTALLER="$ROOT/resources/gnoland_node_install.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
fail() { echo "GLIBC_COMPATIBILITY_TEST_FAIL: $*" >&2; exit 1; }
line_of() { grep -nF -- "$1" "$2" | head -n 1 | cut -d: -f1; }

for script in "$INSTALLER" "$UPDATER"; do
    [ "$(grep -c '^check_host_glibc() {' "$script")" -eq 1 ] || fail "missing or duplicated glibc preflight: $script"
    call_line=$(grep -n '^check_host_glibc$' "$script" | cut -d: -f1)
    [ -n "$call_line" ] || fail "missing glibc invocation: $script"
    if [ "$script" = "$INSTALLER" ]; then
        first_write=$(line_of 'sudo apt update -y' "$script")
    else
        first_write=$(line_of 'git -C "$GNO_SOURCE_DIR" remote set-url origin' "$script")
    fi
    [ -n "$first_write" ] && [ "$call_line" -lt "$first_write" ] || fail "glibc preflight must precede host writes: $script"

    function_source=$(sed -n '/^check_host_glibc() {/,/^}/p' "$script")
    (
        eval "$function_source"
        getconf() {
            [ "$MOCK_GLIBC" != "unavailable" ] || return 1
            printf '%s\n' "$MOCK_GLIBC"
        }
        check_case() {
            local expected=$1 sample=$2 actual
            MOCK_GLIBC=$sample
            if check_host_glibc >/dev/null 2>&1; then actual=pass; else actual=fail; fi
            [ "$actual" = "$expected" ] || fail "$script: '$sample' expected $expected but got $actual"
        }
        check_case pass "glibc 2.38"
        check_case pass "glibc 2.39"
        check_case pass "glibc 3.0"
        check_case fail "glibc 2.35"
        check_case fail "glibc 2.36"
        check_case fail "glibc 2.37"
        check_case fail "glibc 2.08"
        check_case fail "glibc 2.38-extra"
        check_case fail "musl 1.2.5"
        check_case fail "unavailable"
    )
done

printf '%s\n' GLIBC_COMPATIBILITY_TEST_OK
