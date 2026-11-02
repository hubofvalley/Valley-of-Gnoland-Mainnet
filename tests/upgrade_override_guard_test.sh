#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { echo "UPGRADE_OVERRIDE_GUARD_FAIL: $*" >&2; exit 1; }

grep -Fq 'check_local_upgrade_overrides "$CONFIG_FILE"' "$DOCTOR" ||
    fail "Node Doctor must invoke the override diagnostic for an existing config"

# Execute only the extracted config-reader helper; no RPC, systemd or node access.
check_config() {
    {
        printf '%s\n' 'record() { printf "%s|%s|%s\n" "$1" "$2" "$3"; }'
        sed -n '/^check_local_upgrade_overrides() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'check_local_upgrade_overrides "$1"'
    } | bash -s -- "$1"
}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
CFG="$TMP_DIR/config.toml"

cat > "$CFG" <<'EOF_DEFAULTS'
# halt_height = 1183000
halt_height = 0  # no forced local halt
skip_upgrade_height = 0
[p2p]
persistent_peers = ""
EOF_DEFAULTS
[ -z "$(check_config "$CFG")" ] || fail "zero defaults and comments must not warn"

cat > "$CFG" <<'EOF_OVERRIDES'
halt_height = 1183000
skip_upgrade_height = 1183000
[p2p]
pex = true
EOF_OVERRIDES
result=$(check_config "$CFG")
printf '%s\n' "$result" | grep -Fq 'WARN|local_halt_override|' ||
    fail "nonzero local halt must warn"
printf '%s\n' "$result" | grep -Fq 'WARN|upgrade_gate_bypass|' ||
    fail "nonzero upgrade bypass must warn"

cat > "$CFG" <<'EOF_SECTIONS'
halt_height = 0
skip_upgrade_height = 0
[p2p]
halt_height = 123
skip_upgrade_height = 456
EOF_SECTIONS
[ -z "$(check_config "$CFG")" ] || fail "same-named keys in other sections must be ignored"

cat > "$CFG" <<'EOF_MALFORMED'
skip_upgrade_height = "unknown"
halt_height = 
EOF_MALFORMED
result=$(check_config "$CFG")
printf '%s\n' "$result" | grep -Fq 'WARN|upgrade_gate_bypass|' ||
    fail "unrecognized bypass must warn"
printf '%s\n' "$result" | grep -Fq 'WARN|local_halt_override|' ||
    fail "empty local halt must warn"

echo "UPGRADE_OVERRIDE_GUARD_OK"
