#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MAIN="$ROOT/resources/valleyofGnoland.sh"
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "RUNTIME_SCRIPT_TEST_FAIL: $*" >&2; exit 1; }

runtime_ref=$(sed -n 's/^readonly VALLEY_RUNTIME_REF="\([0-9a-f]\{40\}\)"$/\1/p' "$MAIN")
[ -n "$runtime_ref" ] || fail "VALLEY_RUNTIME_REF must be a full commit SHA"
grep -Fq 'no verified remote pin' "$MAIN" || fail "missing remote-helper safety boundary"
grep -Fq 'script_dir/../$relative_path' "$MAIN" || fail "main menu does not prefer checked-out helpers"
grep -Fq 'Valley-of-Gnoland-Mainnet/cc025ffeff201bfa07791335935558923a9d32d0/${relative_path}' "$MAIN" || fail "main menu remote helper is not pinned"
grep -Fq 'Valley-of-Gnoland-Mainnet/cc025ffeff201bfa07791335935558923a9d32d0/${NODE_DOCTOR_RELATIVE_PATH}' "$MAIN" || fail "doctor remote helper is not pinned"
if grep -Eiq 'faucet\.gno\.land|chain/gnoland1\.0' "$MAIN" "$DOCTOR"; then
    fail "stale endpoint or release wording remains in runtime scripts"
fi

grep -Fq 'GNOLAND_SOURCE_BRANCH="chain/mainnet"' "$MAIN" || fail "main menu source branch missing"
grep -Fq 'GNOLAND_SOURCE_COMMIT="31b6650a100d9baf14e7669f8f0df924f1f841e0"' "$MAIN" || fail "main menu source commit missing"
grep -Fq 'OFFICIAL_GNOLAND_PEERS="g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656"' "$MAIN" || fail "official peers missing"

set +e
GNOLAND_NODE_DOCTOR_REF=main bash "$DOCTOR" --version >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "mutable Node Doctor ref should be rejected"

printf '%s\n' 'RUNTIME_SCRIPT_TEST_OK'
