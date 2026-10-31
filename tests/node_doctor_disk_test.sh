#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "NODE_DOCTOR_DISK_TEST_FAIL: $*" >&2; exit 1; }

mkdir -p "$TMP/bin" "$TMP/data"
cat > "$TMP/bin/df" <<'EOF'
#!/bin/sh
case "${MOCK_DF_MODE:-}" in
    error) exit 1 ;;
    invalid) printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\nmock 40000000 0 unknown 0%% /mock\n' ;;
    low) printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\nmock 40000000 0 10485760 75%% /mock\n' ;;
    enough) printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\nmock 40000000 0 31457280 25%% /mock\n' ;;
    *) exit 2 ;;
esac
EOF
for command in curl systemctl timedatectl; do
    printf '#!/bin/sh\nexit 1\n' > "$TMP/bin/$command"
done
chmod +x "$TMP/bin/"*

assert_disk() {
    local mode=$1 expected=$2 output result message
    output=$(env \
        MOCK_DF_MODE="$mode" \
        PATH="$TMP/bin:$PATH" \
        GNO_SOURCE_DIR="$TMP/missing-source" \
        GNOLAND_MAINNET_HOME="$TMP/data" \
        GNOLAND_DEPLOYMENT_DIR="$TMP/missing-deployment" \
        GNOLAND_GENESIS="$TMP/missing-genesis" \
        GNO_BIN="$TMP/missing-gno" \
        GNOLAND_BIN="$TMP/missing-gnoland" \
        GNOKEY_BIN="$TMP/missing-gnokey" \
        bash "$DOCTOR" --json) || true
    result=$(printf '%s\n' "$output" | jq -r '[.results[] | select(.code == "disk")][0].level // empty')
    message=$(printf '%s\n' "$output" | jq -r '[.results[] | select(.code == "disk")][0].message // empty')
    [ "$result" = "$expected" ] || fail "$mode returned ${result:-no disk result}; expected $expected"
    if [ "$mode" = error ] || [ "$mode" = invalid ]; then
        [[ "$message" == *"could not be determined"* ]] || fail "$mode did not explain the unknown capacity"
    fi
}

assert_disk error WARN
assert_disk invalid WARN
assert_disk low WARN
assert_disk enough PASS

printf '%s\n' 'NODE_DOCTOR_DISK_TEST_OK'
