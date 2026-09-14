#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SNAPSHOT_SCRIPT="$ROOT_DIR/resources/apply_snapshot.sh"
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT

fail() { echo "SNAPSHOT_TEST_FAIL: $*" >&2; exit 1; }
assert_contains() {
    local haystack=$1 needle=$2
    [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

[ -f "$SNAPSHOT_SCRIPT" ] || fail "snapshot script missing"
grep -Fq 'EXPECTED_CHAIN_ID="gnoland-1"' "$SNAPSHOT_SCRIPT" || fail "chain guard missing"
grep -Fq 'SNAPSHOT_STATUS="disabled"' "$SNAPSHOT_SCRIPT" || fail "closed status missing"
grep -Fq 'No verified gnoland-1 snapshot provider' "$SNAPSHOT_SCRIPT" || fail "provider gate missing"
if grep -Eiq 'faucet\.gno\.land|chain/gnoland1\.0' "$SNAPSHOT_SCRIPT"; then
    fail "stale endpoint or release reference remains"
fi

menu_output=$(bash -c 'source "$1"; show_menu' _ "$SNAPSHOT_SCRIPT")
assert_contains "$menu_output" 'Snapshot application is disabled for gnoland-1.'
assert_contains "$menu_output" 'No verified gnoland-1 provider is configured.'
assert_contains "$menu_output" '1. Exit'

mkdir -p "$TEST_TMP/gno/gnoland-data/db" "$TEST_TMP/gno/gnoland-data/wal"
printf 'old-db\n' >"$TEST_TMP/gno/gnoland-data/db/marker"
printf 'old-wal\n' >"$TEST_TMP/gno/gnoland-data/wal/marker"
if HOME="$TEST_TMP" GNO_SOURCE_DIR="$TEST_TMP/gno" GNOLAND_MAINNET_HOME="$TEST_TMP/gno/gnoland-data" \
    bash -c 'source "$1"; apply_snapshot' _ "$SNAPSHOT_SCRIPT" >/dev/null 2>&1; then
    fail "disabled snapshot path unexpectedly succeeded"
fi
[ "$(cat "$TEST_TMP/gno/gnoland-data/db/marker")" = 'old-db' ] || fail "db changed on closed path"
[ "$(cat "$TEST_TMP/gno/gnoland-data/wal/marker")" = 'old-wal' ] || fail "wal changed on closed path"

printf '%s\n' 'SNAPSHOT_FAIL_CLOSED_TEST_OK'
