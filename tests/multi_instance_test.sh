#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALLER="$ROOT/resources/gnoland_node_install.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
MAIN="$ROOT/resources/valleyofGnoland.sh"

fail() { echo "MULTI_INSTANCE_TEST_FAIL: $*" >&2; exit 1; }

grep -Fq 'service_belongs_to_instance()' "$INSTALLER" || fail "installer service ownership guard missing"
grep -Fq 'belongs to another instance' "$INSTALLER" || fail "installer collision refusal missing"
grep -Fq 'path_is_under_home()' "$INSTALLER" || fail "installer path guard missing"
grep -Fq 'GNOLAND_RPC_PORT="${GNOLAND_PORT}657"' "$INSTALLER" || fail "custom RPC prefix missing"
grep -Fq 'GNOLAND_P2P_PORT="${GNOLAND_PORT}656"' "$INSTALLER" || fail "custom P2P prefix missing"
grep -Fq 'GNOLAND_ABCI_PORT="${GNOLAND_PORT}658"' "$INSTALLER" || fail "custom ABCI prefix missing"
grep -Fq 'service_belongs_to_current_instance()' "$MAIN" || fail "main menu service ownership guard missing"
grep -Fq 'this service is not configured for $CHAIN_ID' "$UPDATER" || fail "updater chain gate missing"

if grep -REn '/usr/local/bin/(gnoland|gnokey)' "$ROOT/resources"; then
    fail "runtime scripts must not manage global Gnoland command links"
fi

printf '%s\n' 'MULTI_INSTANCE_TEST_OK'
