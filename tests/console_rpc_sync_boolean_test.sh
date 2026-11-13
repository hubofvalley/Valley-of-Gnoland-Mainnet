#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONSOLE="$ROOT/resources/valleyofGnoland.sh"

fail() { echo "MAINNET_CONSOLE_RPC_BOOLEAN_TEST_FAIL: $*" >&2; exit 1; }

# Extract only the pure parser. Do not run the interactive console, which
# would source the user's profile and offer node-management actions.
# shellcheck disable=SC1090
source <(sed -n '/^function parse_rpc_catching_up() {/,/^}/p' "$CONSOLE")
type -t parse_rpc_catching_up >/dev/null || fail "parser function missing"

check() {
    local label=$1 payload=$2 expected=$3 actual
    actual=$(printf '%s\n' "$payload" | parse_rpc_catching_up)
    [ "$actual" = "$expected" ] || fail "$label: got '$actual', wanted '$expected'"
}

check false '{"result":{"sync_info":{"catching_up":false}}}' false
check true '{"result":{"sync_info":{"catching_up":true}}}' true
check null '{"result":{"sync_info":{"catching_up":null}}}' ''
check missing '{"result":{"sync_info":{}}}' ''
check string-false '{"result":{"sync_info":{"catching_up":"false"}}}' ''
check number '{"result":{"sync_info":{"catching_up":0}}}' ''
check missing-result '{}' ''
check invalid-json 'not-json' ''

# Both console status surfaces must use the typed parser.
uses=$(grep -Fc '| parse_rpc_catching_up)' "$CONSOLE")
[ "$uses" -eq 2 ] || fail "expected two console call sites, got $uses"
if grep -Fq '.result.sync_info.catching_up // empty' "$CONSOLE"; then
    fail "false-dropping jq fallback remains"
fi

echo "MAINNET_CONSOLE_RPC_BOOLEAN_TEST_OK"
