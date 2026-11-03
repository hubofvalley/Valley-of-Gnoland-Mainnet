#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { echo "TMKMS_UDS_GUARD_TEST_FAIL: $*" >&2; exit 1; }

grep -Fq 'check_tmkms_uds_isolation "$CONFIG_FILE"' "$DOCTOR" ||
    fail "Node Doctor must check the active TMKMS listener configuration"
grep -Fq 'record WARN tmkms_uds_isolation' "$DOCTOR" ||
    fail "Unix signer isolation must be an advisory warning"

# Execute the production helpers directly with a stubbed record function.
# Never start a node, inspect keys, or connect to a signer.
run_guard() {
    {
        printf '%s\n' 'record() { printf "%s|%s|%s\n" "$1" "$2" "$3"; }'
        sed -n '/^read_active_tmkms_listener_addr() {/,/^}/p' "$DOCTOR"
        sed -n '/^check_tmkms_uds_isolation() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'check_tmkms_uds_isolation "$1"'
    } | bash -s -- "$1"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
config="$tmp/config.toml"

cat > "$config" <<'EOF_UNIX'
[consensus.priv_validator.tmkms_listener]
listen_addr = "unix:///run/gnoland/privval.sock" # active Unix listener
EOF_UNIX
warning=$(run_guard "$config")
case "$warning" in
    'WARN|tmkms_uds_isolation|v1.7.0 Unix TMKMS listener uses mode 0600 and ignores allowed_kms_pubkeys;'*) ;;
    *) fail "active Unix listener was not flagged: $warning" ;;
esac

cat > "$config" <<'EOF_TCP'
[consensus.priv_validator.tmkms_listener]
listen_addr = "tcp://127.0.0.1:26659"
EOF_TCP
[ -z "$(run_guard "$config")" ] || fail "TCP listener must not trigger a Unix warning"

cat > "$config" <<'EOF_COMMENT'
[consensus.priv_validator.tmkms_listener]
# listen_addr = "unix:///run/gnoland/privval.sock"
listen_addr = ""
[unrelated]
listen_addr = "unix:///tmp/not-the-listener.sock"
EOF_COMMENT
[ -z "$(run_guard "$config")" ] || fail "comments and unrelated sections must be ignored"

cat > "$config" <<'EOF_OTHER'
[consensus.priv_validator.tmkms_listener_other]
listen_addr = "unix:///tmp/not-the-listener.sock"
EOF_OTHER
[ -z "$(run_guard "$config")" ] || fail "other TMKMS-like sections must be ignored"

cat > "$config" <<'EOF_INVALID'
[consensus.priv_validator.tmkms_listener]
listen_addr = "unix:///tmp/invalid.sock" trailing-junk
EOF_INVALID
[ -z "$(run_guard "$config")" ] || fail "invalid trailing syntax must not be treated as active"

cat > "$config" <<'EOF_INDENTED'
  [consensus.priv_validator.tmkms_listener] # signer config
  listen_addr = "unix:///run/gnoland/privval.sock"
EOF_INDENTED
[ -n "$(run_guard "$config")" ] || fail "indented active Unix listener must be detected"

printf '%s\n' 'TMKMS_UDS_GUARD_TEST_OK'
