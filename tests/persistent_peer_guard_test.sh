#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { echo "PERSISTENT_PEER_TEST_FAIL: $*" >&2; exit 1; }

grep -Fq 'check_persistent_peer_duplicates "$CONFIG_FILE"' "$DOCTOR" ||
    fail "Node Doctor must call the config-only diagnostic"
grep -Fq 'record WARN peer_id_reuse' "$DOCTOR" ||
    fail "duplicate peer IDs must produce an operator warning"

# Execute the exact helper from Node Doctor, not a copy of its parsing logic.
# This avoids binaries, node RPC requests, and service access.
run_guard() {
    {
        printf '%s\n' 'record() { printf "%s|%s|%s\n" "$1" "$2" "$3"; }'
        sed -n '/^check_persistent_peer_duplicates() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'check_persistent_peer_duplicates "$1"'
    } | bash -s -- "$1"
}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
CONFIG="$TMP_DIR/config.toml"

cat > "$CONFIG" <<'EOF_UNIQUE'
[p2p]
persistent_peers = "g1first@seed-a:26656,g1second@seed-b:26656"
EOF_UNIQUE
[ -z "$(run_guard "$CONFIG")" ] || fail "unique peer IDs must not trigger a warning"

cat > "$CONFIG" <<'EOF_DUPLICATE'
[p2p]
persistent_peers = "g1first@seed-a:26656,g1second@seed-b:26656,g1first@seed-c:26656"
EOF_DUPLICATE
warning=$(run_guard "$CONFIG")
case "$warning" in
    'WARN|peer_id_reuse|persistent_peers repeats peer ID g1first; gnoland v1.5.1 dials only its last configured address') ;;
    *) fail "duplicate peer ID was not diagnosed correctly: $warning" ;;
esac

cat > "$CONFIG" <<'EOF_OTHER_SECTION'
[other]
persistent_peers = "g1first@seed-a:26656,g1first@seed-b:26656"
[p2p]
# persistent_peers = "g1second@seed-a:26656,g1second@seed-b:26656"
persistent_peers = "g1first@seed-a:26656,g1second@seed-b:26656"
EOF_OTHER_SECTION
[ -z "$(run_guard "$CONFIG")" ] || fail "unrelated sections/comments must be ignored"

cat > "$CONFIG" <<'EOF_UNSET'
[p2p]
persistent_peers = ""
EOF_UNSET
[ -z "$(run_guard "$CONFIG")" ] || fail "empty peer list must not invent duplicates"

printf '%s\n' 'PERSISTENT_PEER_TEST_OK'
