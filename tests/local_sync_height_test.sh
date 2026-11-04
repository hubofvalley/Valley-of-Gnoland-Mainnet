#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { echo "LOCAL_SYNC_HEIGHT_TEST_FAIL: $*" >&2; exit 1; }

grep -Fq 'report_local_sync "$local_catching_up" "$local_height"' "$DOCTOR" ||
    fail "local /status must use the tested sync-height guard"

# Exercise the actual diagnostic function with a stub record collector.
# No services, live RPCs, binaries, or node data are accessed.
run_sync() {
    {
        cat <<'BASH'
record() { printf '%s|%s|%s\n' "$1" "$2" "$3"; }
BASH
        sed -n '/^report_local_sync() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'report_local_sync "$1" "$2"'
    } | bash -s -- "$1" "$2"
}

assert_sync() {
    local label=$1 state=$2 height=$3 expected=$4 observed
    observed=$(run_sync "$state" "$height")
    [ "$observed" = "$expected" ] ||
        fail "$label: expected '$expected', got '$observed'"
}

warn_unknown='WARN|local_sync|local RPC reports catching_up=false but latest block height is missing, zero, or invalid'
assert_sync "observed positive height" false 1183001 'PASS|local_sync|local RPC reports catching_up=false at height 1183001'
assert_sync "numeric height with leading zeros" false 0007 'PASS|local_sync|local RPC reports catching_up=false at height 0007'
assert_sync "zero height" false 0 "$warn_unknown"
assert_sync "zero padded height" false 000 "$warn_unknown"
assert_sync "missing height" false '' "$warn_unknown"
assert_sync "invalid height" false 'not-a-number' "$warn_unknown"
assert_sync "fast sync in progress" true 100 'WARN|local_sync|local RPC reports catching_up=true at height 100'
assert_sync "unknown sync state" unknown 100 'WARN|local_sync|local RPC did not expose a valid catching_up state'

printf '%s\n' LOCAL_SYNC_HEIGHT_TEST_OK
