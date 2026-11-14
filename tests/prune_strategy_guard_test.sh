#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { echo "PRUNE_STRATEGY_GUARD_TEST_FAIL: $*" >&2; exit 1; }

grep -Fq 'configured_pruning=$(read_active_prune_strategy "$CONFIG_FILE")' "$DOCTOR" ||
    fail "Node Doctor does not inspect the active application setting"
grep -Fq 'record PASS prune_strategy' "$DOCTOR" ||
    fail "matching pruning strategy must be reported"
grep -Fq 'record WARN prune_strategy' "$DOCTOR" ||
    fail "missing or mismatched pruning strategy must warn"

# Exercise the real config reader in isolation: no node, RPC, or service access.
read_strategy() {
    {
        sed -n '/^read_active_prune_strategy() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'read_active_prune_strategy "$1"'
    } | bash -s -- "$1"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
config="$tmp/config.toml"
assert_strategy() {
    local label=$1 expected=$2 observed
    observed=$(read_strategy "$config")
    [ "$observed" = "$expected" ] ||
        fail "$label: expected '$expected', got '$observed'"
}

printf '[application]\nprune_strategy = "syncable"\n' > "$config"
assert_strategy "reviewed required setting" "syncable"

printf '  [application] # effective app settings\n  prune_strategy = "syncable" # reviewed\n' > "$config"
assert_strategy "whitespace and trailing comment" "syncable"

printf '[application]\nprune_strategy = "nothing"\n' > "$config"
assert_strategy "different strategy" "nothing"

printf '[application]\n# prune_strategy = "syncable"\n' > "$config"
assert_strategy "comment is not active" ""

printf '[rpc]\nprune_strategy = "syncable"\n[application]\nprune_strategy = "nothing"\n' > "$config"
assert_strategy "unrelated section does not count" "nothing"

printf '[application]\nprune_strategy = "syncable" invalid\n' > "$config"
assert_strategy "trailing syntax must not pass" ""

printf '[application]\nprune_strategy = syncable\n' > "$config"
assert_strategy "unsupported unquoted value" ""

printf '[application]\nprune_strategy = "syncable"\nprune_strategy = "syncable"\n' > "$config"
assert_strategy "duplicate keys must not pass" ""

printf '[application]\nprune_strategy = "syncable"\n[application.extra]\nprune_strategy = "nothing"\n' > "$config"
assert_strategy "nested section is isolated" "syncable"

printf '%s\n' PRUNE_STRATEGY_GUARD_TEST_OK
