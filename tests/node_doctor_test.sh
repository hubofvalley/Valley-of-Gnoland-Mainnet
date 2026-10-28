#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "NODE_DOCTOR_TEST_FAIL: $*" >&2; exit 1; }

version=$(bash "$DOCTOR" --version)
[ "$version" = 'Valley of Gnoland Node Doctor (gnoland-1) 1.2.0' ] || fail "unexpected version output"

set +e
GNOLAND_NODE_DOCTOR_REF=main bash "$DOCTOR" --version >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "mutable runtime ref should be rejected"

grep -Fq 'EXPECTED_CHAIN_ID="gnoland-1"' "$DOCTOR" || fail "mainnet chain guard missing"
grep -Fq 'EXPECTED_SOURCE_BRANCH="chain/mainnet"' "$DOCTOR" || fail "source branch guard missing"
grep -Fq 'EXPECTED_SOURCE_COMMIT="e75fef82c02876a4df92ad6e325c5479b9532168"' "$DOCTOR" || fail "source commit guard missing"
grep -Fq 'EXPECTED_RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"' "$DOCTOR" || fail "release tag guard missing"
grep -Fq 'EXPECTED_GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"' "$DOCTOR" || fail "genesis guard missing"
grep -Fq 'EXPECTED_GNO_SHA256="423a64b605400882ac6ae016ef517b2465d64c49e71fd8d45d6d3a6ecfe0e87d"' "$DOCTOR" || fail "gno hash guard missing"
grep -Fq 'EXPECTED_GNOLAND_SHA256="5f568a5c96f9a0f9f20f5b0adbc72cc0d5c640e82bd3c7b129bb629758f029bc"' "$DOCTOR" || fail "gnoland hash guard missing"
grep -Fq 'EXPECTED_GNOKEY_SHA256="2d9f3019107403879e7b9f398deb15107945f33b91bc4ee85b938ff7f60b03cd"' "$DOCTOR" || fail "gnokey hash guard missing"
grep -Fq 'EXPECTED_PERSISTENT_PEERS="g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656"' "$DOCTOR" || fail "official peer guard missing"
grep -Fq 'ACTIVE_VALIDATOR_REALM="r/sys/validators/v0"' "$DOCTOR" || fail "active realm guard missing"
grep -Fq 'PUBLIC_RPC="https://rpc.gno.land"' "$DOCTOR" || fail "public RPC guard missing"
grep -Fq '.result.sync_info.latest_block_height // empty' "$DOCTOR" || fail "latest block height visibility missing"
grep -Fq '.result.sync_info.catching_up // empty' "$DOCTOR" || fail "catching_up visibility missing"
grep -Fq 'local RPC reports catching_up=false at height' "$DOCTOR" || fail "catching_up=false report missing"
grep -Fq 'local RPC reports catching_up=true at height' "$DOCTOR" || fail "catching_up=true report missing"
if grep -Fq 'local node is caught up' "$DOCTOR"; then
    fail "catching_up=false must not be presented as proof of network-head sync"
fi
grep -Fq '"${GNOLAND_REMOTE%/}/net_info"' "$DOCTOR" || fail "live peer RPC probe missing"
grep -Fq '.result.n_peers // empty' "$DOCTOR" || fail "live peer count parsing missing"
grep -Fq 'local node reports zero live peers' "$DOCTOR" || fail "zero-peer warning missing"
grep -Fq 'public_height=$(printf' "$DOCTOR" || fail "comparison RPC height parsing missing"
grep -Fq 'record PASS height_gap "comparison RPC is $height_gap block(s) ahead of local node' "$DOCTOR" || fail "comparison-ahead height-gap report missing"
grep -Fq 'record PASS height_gap "local node is $height_gap block(s) ahead of comparison RPC' "$DOCTOR" || fail "local-ahead height-gap report missing"
grep -Fq 'observation only, no healthy-gap threshold is asserted' "$DOCTOR" || fail "height-gap observation boundary missing"
if grep -Eq 'HEAD_GAP_LIMIT|MAX_HEIGHT_GAP|HEALTHY_GAP' "$DOCTOR"; then
    fail "Node Doctor must not invent a mainnet healthy height-gap threshold"
fi
if grep -Eiq 'faucet\.gno\.land|chain/gnoland1\.0' "$DOCTOR"; then
    fail "stale endpoint or release wording remains in Node Doctor"
fi


# Offline release-classification fixtures: never contact RPC or inspect a live node.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/source/.git" "$TMP/source/misc/deployments/mainnet.gno.land" "$TMP/node/config" "$TMP/bin"
: > "$TMP/genesis.json"
for binary in gno gnoland gnokey; do
    printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/$binary"
    chmod +x "$TMP/bin/$binary"
done
printf 'persistent_peers = "g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656"\n' > "$TMP/node/config/config.toml"

sha256sum() {
    local hash=""
    case "${1##*/}" in
        gno) hash=$CASE_GNO_SHA ;;
        gnoland) hash=$CASE_GNOLAND_SHA ;;
        gnokey) hash=$CASE_GNOKEY_SHA ;;
        genesis.json) hash=ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0 ;;
        *) return 1 ;;
    esac
    printf '%s  %s\n' "$hash" "$1"
}
git() { printf '%s\n' "$CASE_SOURCE_COMMIT"; }
curl() { printf '{}'; }
systemctl() { return 1; }
timedatectl() { return 1; }
export -f sha256sum git curl systemctl timedatectl

assert_release_case() {
    local expected_level=$1 source=$2 gno_sha=$3 gnoland_sha=$4 gnokey_sha=$5 output code
    output=$(
        CASE_SOURCE_COMMIT="$source" CASE_GNO_SHA="$gno_sha" \
        CASE_GNOLAND_SHA="$gnoland_sha" CASE_GNOKEY_SHA="$gnokey_sha" \
        GNO_SOURCE_DIR="$TMP/source" GNOLAND_MAINNET_HOME="$TMP/node" \
        GNOLAND_DEPLOYMENT_DIR="$TMP/source/misc/deployments/mainnet.gno.land" \
        GNOLAND_GENESIS="$TMP/genesis.json" GNOLAND_REMOTE="http://127.0.0.1:1" \
        GNOLAND_MAINNET_SERVICE_NAME="mock-gnoland" \
        GNO_BIN="$TMP/bin/gno" GNOLAND_BIN="$TMP/bin/gnoland" GNOKEY_BIN="$TMP/bin/gnokey" \
        bash "$DOCTOR" --json || true
    )
    printf '%s\n' "$output" | jq -e . >/dev/null || fail "Node Doctor did not return valid JSON"
    for code in gno_binary gnoland_binary gnokey_binary source_commit; do
        printf '%s\n' "$output" | jq -e --arg code "$code" --arg level "$expected_level" \
            '.results[] | select(.code == $code and .level == $level)' >/dev/null ||
            fail "expected $expected_level for $code; got $output"
    done
}

assert_release_case PASS \
    07e44776c26187830b7dcbd2454991b5a1960378 \
    fd70e8173b98dd7ac73b45d8d1cdcb446dbf11ab1f7e3f34e29336066f8e1485 \
    ca2319a1a7ebf07fed9268403b0a6ac5e474eee8d0da4babe9b4fb2f8eff2241 \
    73a4cc744fc02a0e8aa05ab77be730d7bb96192f5a6ae6a63d5f01e1a6713477
assert_release_case WARN \
    e75fef82c02876a4df92ad6e325c5479b9532168 \
    423a64b605400882ac6ae016ef517b2465d64c49e71fd8d45d6d3a6ecfe0e87d \
    5f568a5c96f9a0f9f20f5b0adbc72cc0d5c640e82bd3c7b129bb629758f029bc \
    2d9f3019107403879e7b9f398deb15107945f33b91bc4ee85b938ff7f60b03cd
assert_release_case FAIL \
    0000000000000000000000000000000000000000 \
    0000000000000000000000000000000000000000000000000000000000000000 \
    0000000000000000000000000000000000000000000000000000000000000000 \
    0000000000000000000000000000000000000000000000000000000000000000

printf '%s\n' 'NODE_DOCTOR_TEST_OK'
