#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { echo "ACTIVE_P2P_PEERS_TEST_FAIL: $*" >&2; exit 1; }

grep -Fq 'configured_peers=$(read_active_persistent_peers "$CONFIG_FILE")' "$DOCTOR" ||
    fail "Node Doctor must check parsed active peers"
if grep -Fq 'grep -Fq "persistent_peers =' "$DOCTOR"; then
    fail "unscoped text matching can treat comments as active configuration"
fi

# Exercise the actual parser without running Node Doctor, services, or RPC.
read_peers() {
    {
        sed -n '/^read_active_persistent_peers() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'read_active_persistent_peers "$1"'
    } | bash -s -- "$1"
}

expected=$(sed -n 's/^readonly EXPECTED_PERSISTENT_PEERS="\(.*\)"$/\1/p' "$DOCTOR")
[ -n "$expected" ] || fail "could not read reviewed peer list"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
config="$tmp/config.toml"
assert_peers() {
    local label=$1 want=$2 got
    got=$(read_peers "$config")
    [ "$got" = "$want" ] || fail "$label: expected '$want', got '$got'"
}

printf '[p2p]\npersistent_peers = "%s" # reviewed defaults\n' "$expected" > "$config"
assert_peers "active official peers" "$expected"

printf '[p2p]\npersistent_peers = "%s" trailing-junk\n' "$expected" > "$config"
assert_peers "trailing syntax must not pass" ""

printf '[p2p]\n# persistent_peers = "%s"\npersistent_peers = "g1wrong@seed:26656"\n' "$expected" > "$config"
assert_peers "commented official peers must not pass" "g1wrong@seed:26656"

printf '[rpc]\npersistent_peers = "%s"\n[p2p]\npersistent_peers = "g1other@seed:26656"\n' "$expected" > "$config"
assert_peers "unrelated section must not pass" "g1other@seed:26656"

printf '[p2p]\n# persistent_peers = "%s"\n' "$expected" > "$config"
assert_peers "only commented peers" ""

printf '[p2p]\npersistent_peers = ""\n' > "$config"
assert_peers "empty configured peers" ""

printf '  [p2p] # network config\n  persistent_peers = "%s"\n' "$expected" > "$config"
assert_peers "indented active peers" "$expected"

printf '%s\n' ACTIVE_P2P_PEERS_TEST_OK
