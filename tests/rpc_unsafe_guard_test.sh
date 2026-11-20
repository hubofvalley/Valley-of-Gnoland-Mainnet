#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { echo "RPC_UNSAFE_GUARD_FAIL: $*" >&2; exit 1; }

grep -Fq 'check_rpc_unsafe "$CONFIG_FILE"' "$DOCTOR" ||
    fail "Node Doctor must invoke the read-only RPC diagnostic"

# Run the exact helpers from the Node Doctor with mock reporting; no service,
# secrets, network requests, binaries or live configuration are accessed.
run_guard() {
    {
        printf '%s\n' 'record() { printf "%s|%s|%s\n" "$1" "$2" "$3"; }'
        sed -n '/^read_active_rpc_unsafe() {/,/^}/p' "$DOCTOR"
        sed -n '/^check_rpc_unsafe() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'check_rpc_unsafe "$1"'
    } | bash -s -- "$1"
}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
CONFIG="$TMP_DIR/config.toml"
count=0

assert_level() {
    local name=$1 expected=$2 got
    got=$(run_guard "$CONFIG")
    case "$got" in
        "$expected|rpc_unsafe|"*) ;;
        *) fail "$name: expected $expected rpc_unsafe, got: $got" ;;
    esac
    count=$((count + 1))
}

cat > "$CONFIG" <<'EOF'
[rpc]
unsafe = false
EOF
assert_level "explicit false" PASS

cat > "$CONFIG" <<'EOF'
[rpc]
unsafe = true
EOF
assert_level "explicit true" WARN

cat > "$CONFIG" <<'EOF'
# unsafe = true
[rpc] # active RPC
unsafe = false # safe route selection
EOF
assert_level "comment handling" PASS

cat > "$CONFIG" <<'EOF'
[rpc]
# unsafe = false
unsafe = true # do not overlook this
EOF
assert_level "commented decoy false" WARN

cat > "$CONFIG" <<'EOF'
[other]
unsafe = true
[rpc]
unsafe = false
EOF
assert_level "other section ignored" PASS

cat > "$CONFIG" <<'EOF'
[rpc]
unsafe = false
unsafe = true
EOF
assert_level "duplicate keys" WARN

cat > "$CONFIG" <<'EOF'
[rpc]
unsafe = false
[rpc]
unsafe = false
EOF
assert_level "duplicate sections" WARN

cat > "$CONFIG" <<'EOF'
[rpc]
# unsafe = false
EOF
assert_level "missing key" WARN

cat > "$CONFIG" <<'EOF'
[rpc]
unsafe = "false"
EOF
assert_level "unsupported quoted boolean" WARN

cat > "$CONFIG" <<'EOF'
[rpc]
unsafe = trueish
EOF
assert_level "malformed boolean" WARN

cat > "$CONFIG" <<'EOF'
[rpc.extra]
unsafe = false
EOF
assert_level "nested section is not RPC" WARN

cat > "$CONFIG" <<'EOF'
unsafe = false
[other]
unsafe = true
EOF
assert_level "top-level key not RPC" WARN

cat > "$CONFIG" <<'EOF'
[rpc]
unsafe = false ; unexpected syntax
EOF
assert_level "invalid trailing syntax" WARN

cat > "$CONFIG" <<'EOF'
[rpc]
unsafe = false
[other]
unsafe = true
EOF
assert_level "subsequent section cannot override RPC" PASS

printf 'RPC_UNSAFE_GUARD_OK (%d offline fixtures)\n' "$count"
