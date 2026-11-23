#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home" "$TEST_ROOT/data"
cat > "$TEST_ROOT/bin/systemctl" <<'MOCK'
#!/bin/bash
case "$*" in
    *" -p FragmentPath "*) printf '%s\n' "$TEST_SERVICE_FILE" ;;
    *" -p ExecStart "*) printf '%s\n' "$TEST_EFFECTIVE_EXEC" ;;
    *) exit 1 ;;
esac
MOCK
cat > "$TEST_ROOT/bin/curl" <<'MOCK'
#!/bin/bash
exit 1
MOCK
cat > "$TEST_ROOT/bin/timedatectl" <<'MOCK'
#!/bin/bash
exit 1
MOCK
chmod +x "$TEST_ROOT/bin/systemctl" "$TEST_ROOT/bin/curl" "$TEST_ROOT/bin/timedatectl"

export TEST_SERVICE_FILE="$TEST_ROOT/gnoland.service"
export GNOLAND_GENESIS="$TEST_ROOT/genesis.json"
export GNOLAND_MAINNET_HOME="$TEST_ROOT/data"
export GNO_SOURCE_DIR="$TEST_ROOT/source"
cat > "$TEST_SERVICE_FILE" <<UNIT
[Service]
ExecStart=/usr/local/bin/gnoland start --chainid gnoland-1 --genesis $GNOLAND_GENESIS --skip-genesis-sig-verification --log-level info
UNIT

check_case() {
    local label=$1 flags=$2 expected=$3 output
    export TEST_EFFECTIVE_EXEC="{ path=/usr/local/bin/gnoland ; argv[]=/usr/local/bin/gnoland start $flags ; ignore_errors=no ; }"
    output=$(HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" bash "$DOCTOR" 2>&1) || true
    if ! printf '%s\n' "$output" | grep -Eq "^\\[$expected\\][[:space:]]+service_log_level[[:space:]]"; then
        echo "LOG_LEVEL_GUARD_TEST_FAIL: $label (expected $expected)" >&2
        printf '%s\n' "$output" | grep -F service_log_level >&2 || true
        exit 1
    fi
}

check_case explicit_info '--log-level info' PASS
check_case equals_info '-log-level=info' PASS
check_case explicit_warn '--log-level warn' PASS
check_case explicit_error '-log-level error' PASS
check_case debug '--log-level debug' WARN
check_case missing '' WARN
check_case unsupported '--log-level trace' WARN
check_case duplicate '--log-level info --log-level debug' WARN

printf '%s\n' 'SERVICE_LOG_LEVEL_GUARD_TEST_OK'
