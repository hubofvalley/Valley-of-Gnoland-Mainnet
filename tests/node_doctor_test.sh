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
grep -Fq 'EXPECTED_SOURCE_COMMIT="00417a1be97b9a311d9669ae7aa9585b277ee594"' "$DOCTOR" || fail "source commit guard missing"
grep -Fq 'EXPECTED_RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"' "$DOCTOR" || fail "release tag guard missing"
grep -Fq 'EXPECTED_GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"' "$DOCTOR" || fail "genesis guard missing"
grep -Fq 'EXPECTED_GNOLAND_SHA256="ef393f4e15f433cf966468fa6a8f65f1a1a69dc854f6fe843a3931a6ec0711d3"' "$DOCTOR" || fail "gnoland hash guard missing"
grep -Fq 'EXPECTED_GNOKEY_SHA256="86be6aa70bd2c030b50823477e774c75a1f5d63d9387630eb5f39ffa1b62ae14"' "$DOCTOR" || fail "gnokey hash guard missing"
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

printf '%s\n' 'NODE_DOCTOR_TEST_OK'
