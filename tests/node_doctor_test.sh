#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "NODE_DOCTOR_TEST_FAIL: $*" >&2; exit 1; }

version=$(bash "$DOCTOR" --version)
[ "$version" = 'Valley of Gnoland Node Doctor (gnoland-1) 1.0.0' ] || fail "unexpected version output"

set +e
GNOLAND_NODE_DOCTOR_REF=main bash "$DOCTOR" --version >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "mutable runtime ref should be rejected"

grep -Fq 'EXPECTED_CHAIN_ID="gnoland-1"' "$DOCTOR" || fail "mainnet chain guard missing"
grep -Fq 'EXPECTED_SOURCE_BRANCH="chain/mainnet"' "$DOCTOR" || fail "source branch guard missing"
grep -Fq 'EXPECTED_SOURCE_COMMIT="31b6650a100d9baf14e7669f8f0df924f1f841e0"' "$DOCTOR" || fail "source commit guard missing"
grep -Fq 'EXPECTED_RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"' "$DOCTOR" || fail "release tag guard missing"
grep -Fq 'EXPECTED_GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"' "$DOCTOR" || fail "genesis guard missing"
grep -Fq 'EXPECTED_GNOLAND_SHA256="aa22a26823924642481fe7fc5e98eb9f42399b337f7afdac635d91403117db28"' "$DOCTOR" || fail "gnoland hash guard missing"
grep -Fq 'EXPECTED_GNOKEY_SHA256="38018492bcaa4de2f146d0566daf6507d9e811ee28547b963a015f51f9b14511"' "$DOCTOR" || fail "gnokey hash guard missing"
grep -Fq 'EXPECTED_PERSISTENT_PEERS="g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656"' "$DOCTOR" || fail "official peer guard missing"
grep -Fq 'ACTIVE_VALIDATOR_REALM="r/sys/validators/v0"' "$DOCTOR" || fail "active realm guard missing"
grep -Fq 'PUBLIC_RPC="https://rpc.gno.land"' "$DOCTOR" || fail "public RPC guard missing"
if grep -Eiq 'faucet\.gno\.land|chain/gnoland1\.0' "$DOCTOR"; then
    fail "stale endpoint or release wording remains in Node Doctor"
fi

printf '%s\n' 'NODE_DOCTOR_TEST_OK'
