#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "RPC_SYNC_BOOLEAN_TEST_FAIL: $*" >&2; exit 1; }

grep -Fq 'read_rpc_catching_up() {' "$DOCTOR" || fail "typed parser missing"
grep -Fq '| read_rpc_catching_up' "$DOCTOR" || fail "parser not wired to local RPC"
grep -Fq 'if [[ "$local_height" =~ ^0*[1-9][0-9]*$ ]]; then' "$DOCTOR" ||
    fail "positive-height guard missing when catching_up=false"
grep -Fq 'record WARN local_sync "local RPC reports catching_up=false but latest block height is missing, zero, or invalid"' "$DOCTOR" ||
    fail "missing or zero height must not PASS"
if grep -Fq '.result.sync_info.catching_up // empty' "$DOCTOR"; then
    fail "old jq default still discards JSON false"
fi

# Run the production parser without executing systemd, RPC, or other doctor probes.
# shellcheck source=/dev/null
source <(sed -n '/^read_rpc_catching_up() {/,/^}/p' "$DOCTOR")

assert_state() {
    local label=$1 payload=$2 expected=$3 actual
    actual=$(printf '%s' "$payload" | read_rpc_catching_up 2>/dev/null || true)
    if [ "$actual" != "$expected" ]; then
        fail "$label: expected '${expected}', got '${actual}'"
    fi
}

assert_state "JSON false preserved" '{"result":{"sync_info":{"catching_up":false}}}' 'false'
assert_state "JSON true preserved" '{"result":{"sync_info":{"catching_up":true}}}' 'true'
assert_state "string false rejected" '{"result":{"sync_info":{"catching_up":"false"}}}' ''
assert_state "string true rejected" '{"result":{"sync_info":{"catching_up":"true"}}}' ''
assert_state "integer rejected" '{"result":{"sync_info":{"catching_up":0}}}' ''
assert_state "null rejected" '{"result":{"sync_info":{"catching_up":null}}}' ''
assert_state "missing field rejected" '{"result":{"sync_info":{}}}' ''
assert_state "missing result rejected" '{}' ''
assert_state "malformed JSON rejected" '{"result":' ''

printf '%s\n' 'RPC_SYNC_BOOLEAN_TEST_OK'
