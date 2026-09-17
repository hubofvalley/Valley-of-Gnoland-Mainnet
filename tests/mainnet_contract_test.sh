#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALLER="$ROOT/resources/gnoland_node_install.sh"
MAIN="$ROOT/resources/valleyofGnoland.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
SNAPSHOT="$ROOT/resources/apply_snapshot.sh"
VERSIONS="$ROOT/VERSIONS.json"
VALLEY="$ROOT/VALLEY.json"

fail() { echo "MAINNET_CONTRACT_TEST_FAIL: $*" >&2; exit 1; }

[ -f "$INSTALLER" ] || fail "mainnet installer missing"
[ -f "$VALLEY" ] || fail "VALLEY.json missing"

# Mainnet runtime state must not consume the generic names shared by other
# Gnoland networks. Construct the legacy names here so this regression test
# can reject them without making them operational references.
legacy_home_var='GNOLAND_'HOME
legacy_service_var='GNOLAND_'SERVICE_NAME
for legacy_var in "$legacy_home_var" "$legacy_service_var"; do
    if grep -R -n -F -- "$legacy_var" "$ROOT/README.md" "$ROOT/VALLEY.json" "$ROOT/VERSIONS.json" "$ROOT/resources" "$ROOT/docs"; then
        fail "legacy environment variable remains in runtime scripts or docs: $legacy_var"
    fi
done
for script in "$MAIN" "$INSTALLER" "$UPDATER" "$DOCTOR"; do
    grep -Fq 'GNOLAND_MAINNET_HOME' "$script" || fail "$script does not cover GNOLAND_MAINNET_HOME"
    grep -Fq 'GNOLAND_MAINNET_SERVICE_NAME' "$script" || fail "$script does not cover GNOLAND_MAINNET_SERVICE_NAME"
done
grep -Fq 'GNOLAND_MAINNET_SERVICE_NAME=${GNOLAND_MAINNET_SERVICE_NAME:-gnoland}' "$UPDATER" ||
    fail "updater default service is not gnoland"
grep -Fq 'GNOLAND_MAINNET_SERVICE_NAME=${INPUT_SVC:-gnoland}' "$MAIN" ||
    fail "main launcher default service is not gnoland"
grep -Fq 'profile_value GNOLAND_MAINNET_SERVICE_NAME "gnoland"' "$DOCTOR" ||
    fail "Node Doctor default service is not gnoland"
[ "$(jq -r '.services | join(",")' "$VALLEY")" = 'gnoland.service' ] ||
    fail "VALLEY service metadata must remain gnoland.service"
[ "$(jq -r '.components[0].service' "$VALLEY")" = 'gnoland.service' ] ||
    fail "VALLEY component service metadata must remain gnoland.service"
if grep -Fq "sed -i '/GNOLAND_/d" "$INSTALLER" "$MAIN"; then
    fail "mainnet profile cleanup still deletes every GNOLAND_* export"
fi
for cleanup_file in "$INSTALLER" "$MAIN"; do
    grep -Fq '^export GNOLAND_MAINNET_HOME=/d' "$cleanup_file" || fail "mainnet cleanup does not explicitly remove GNOLAND_MAINNET_HOME in ${cleanup_file#$ROOT/}"
    grep -Fq '^export GNOLAND_MAINNET_SERVICE_NAME=/d' "$cleanup_file" || fail "mainnet cleanup does not explicitly remove GNOLAND_MAINNET_SERVICE_NAME in ${cleanup_file#$ROOT/}"
    if grep -Fq 'GNOLAND_TESTNET_HOME' "$cleanup_file" || grep -Fq 'GNOLAND_TESTNET_SERVICE_NAME' "$cleanup_file"; then
        fail "mainnet cleanup may delete testnet-scoped exports in ${cleanup_file#$ROOT/}"
    fi
done

facts=(
    'gnoland-1'
    'chain/mainnet'
    '00417a1be97b9a311d9669ae7aa9585b277ee594'
    '9c8eb132e483d6fd324d92c193e629ad65a98a37'
    'misc/deployments/mainnet.gno.land/'
    'ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0'
    'ef393f4e15f433cf966468fa6a8f65f1a1a69dc854f6fe843a3931a6ec0711d3'
    '86be6aa70bd2c030b50823477e774c75a1f5d63d9387630eb5f39ffa1b62ae14'
    'https://rpc.gno.land'
    'https://gno.land'
    'g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656'
    'r/gnops/valopers'
    'r/sys/validators/v0'
)
for fact in "${facts[@]}"; do
    grep -R -Fq -- "$fact" "$ROOT/README.md" "$ROOT/VERSIONS.json" "$ROOT/VALLEY.json" "$ROOT/docs" "$ROOT/resources" ||
        fail "repository is missing verified fact: $fact"
done

for script in "$INSTALLER" "$UPDATER"; do
    grep -Fq 'SOURCE_BRANCH="chain/mainnet"' "$script" || fail "$script does not pin the mainnet source branch"
    grep -Fq 'SOURCE_COMMIT="00417a1be97b9a311d9669ae7aa9585b277ee594"' "$script" || fail "$script does not pin the mainnet source commit"
    grep -Fq 'RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"' "$script" || fail "$script does not retain release tag metadata"
    grep -Fq 'download_verified_asset' "$script" || fail "$script does not verify downloaded binary assets"
    grep -Fq 'GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"' "$script" || fail "$script does not verify the official mainnet genesis"
done

grep -Fq 'git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "refs/heads/$SOURCE_BRANCH"' "$INSTALLER" || fail "installer does not pin the source branch"
grep -Fq 'git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "refs/heads/$SOURCE_BRANCH"' "$UPDATER" || fail "updater does not pin the source branch"
grep -Fq 'gnoland_linux_amd64' "$INSTALLER" || fail "installer asset name missing"
grep -Fq 'gnokey_linux_amd64' "$INSTALLER" || fail "installer asset name missing"
grep -Fq -- '--skip-genesis-sig-verification' "$INSTALLER" || fail "mainnet startup verification flag missing"
grep -Fq 'INSTALL-GNOLAND-1' "$INSTALLER" || fail "explicit install confirmation missing"
grep -Fq 'Destructive reinstall refused' "$INSTALLER" || fail "unknown existing node guard missing"
grep -Fq 'No verified gnoland-1 snapshot provider' "$SNAPSHOT" || fail "snapshot helper is not fail-closed"
if grep -En 'curl|wget|lz4|tar|systemctl|pkill|rm -rf' "$SNAPSHOT"; then
    fail "snapshot helper contains mutation/download machinery despite closed gate"
fi

[ "$(jq -r '.chain_id' "$VERSIONS")" = 'gnoland-1' ] || fail "VERSIONS chain_id is wrong"
[ "$(jq -r '.release_tag' "$VERSIONS")" = 'chain/mainnet' ] || fail "VERSIONS release tag is wrong"
[ "$(jq -r '.release_commit' "$VERSIONS")" = '9c8eb132e483d6fd324d92c193e629ad65a98a37' ] || fail "VERSIONS release commit is wrong"
[ "$(jq -r '.versioned_release_tag' "$VERSIONS")" = 'v1.2.0' ] || fail "VERSIONS versioned release tag is wrong"
[ "$(jq -r '.versioned_release_commit' "$VERSIONS")" = '9c8eb132e483d6fd324d92c193e629ad65a98a37' ] || fail "VERSIONS versioned release commit is wrong"
[ "$(jq -r '.source_branch' "$VERSIONS")" = 'chain/mainnet' ] || fail "VERSIONS source branch is wrong"
[ "$(jq -r '.source_commit' "$VERSIONS")" = '00417a1be97b9a311d9669ae7aa9585b277ee594' ] || fail "VERSIONS source commit is wrong"
[ "$(jq -r '.deployment_path' "$VERSIONS")" = 'misc/deployments/mainnet.gno.land/' ] || fail "VERSIONS deployment path is wrong"
[ "$(jq -r '.binary_assets.gnoland.sha256' "$VERSIONS")" = 'ef393f4e15f433cf966468fa6a8f65f1a1a69dc854f6fe843a3931a6ec0711d3' ] || fail "VERSIONS gnoland hash is wrong"
[ "$(jq -r '.binary_assets.gnokey.sha256' "$VERSIONS")" = '86be6aa70bd2c030b50823477e774c75a1f5d63d9387630eb5f39ffa1b62ae14' ] || fail "VERSIONS gnokey hash is wrong"
[ "$(jq -r '.binary_assets.gnoland.reported_version' "$VERSIONS")" = 'chain/mainnet.3435+139a63fe6' ] || fail "VERSIONS gnoland reported version is wrong"
[ "$(jq -r '.binary_assets.gnokey.reported_version' "$VERSIONS")" = 'chain/mainnet.3435+139a63fe6' ] || fail "VERSIONS gnokey reported version is wrong"
[ "$(jq -r '.genesis.sha256' "$VERSIONS")" = 'ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0' ] || fail "VERSIONS genesis hash is wrong"
[ "$(jq -r '.endpoints.faucet' "$VERSIONS")" = 'null' ] || fail "VERSIONS must state that no faucet exists"
[ "$(jq -r '.candidate_registration.status' "$VERSIONS")" = 'enabled' ] || fail "candidate registration is not enabled"
[ "$(jq -r '.candidate_registration.candidate_realm' "$VERSIONS")" = 'r/gnops/valopers' ] || fail "candidate realm is wrong"
[ "$(jq -r '.candidate_registration.function' "$VERSIONS")" = 'Register' ] || fail "candidate registration function is wrong"
[ "$(jq -r '.candidate_registration.gas_fee' "$VERSIONS")" = '1000000ugnot' ] || fail "candidate registration gas fee is wrong"
[ "$(jq -r '.candidate_registration.gas_wanted' "$VERSIONS")" = '50000000' ] || fail "candidate registration gas wanted is wrong"
[ "$(jq -r '.candidate_registration.active_validator_realm' "$VERSIONS")" = 'r/sys/validators/v0' ] || fail "candidate active validator realm is wrong"
[ "$(jq -r '.candidate_registration.requires_govdao_approval' "$VERSIONS")" = 'true' ] || fail "candidate registration must require GovDAO approval"
[ "$(jq -r '.candidate_registration.runtime_register_fee_guard' "$VERSIONS")" = 'GetValoperRegisterFee()==0' ] || fail "candidate registration runtime fee guard is missing"
[ "$(jq -r '.snapshot.status' "$VERSIONS")" = 'disabled' ] || fail "snapshot status is not disabled"
[ "$(jq -r '.architecture' "$VALLEY")" = 'v1' ] || fail "VALLEY topology is not v1"
[ "$(jq -r '.public_launcher' "$VALLEY")" = 'direct' ] || fail "public launcher must be direct"
[ "$(jq -r '.release.versioned_tag' "$VALLEY")" = 'v1.2.0' ] || fail "VALLEY versioned release tag is wrong"
[ "$(jq -r '.install.reported_version' "$VALLEY")" = 'chain/mainnet.3435+139a63fe6' ] || fail "VALLEY asset reported version is wrong"
[ "$(jq -r '.endpoints.faucet' "$VALLEY")" = 'null' ] || fail "VALLEY must state that no faucet exists"

active_files=("$ROOT/README.md" "$ROOT/VERSIONS.json" "$ROOT/VALLEY.json")
while IFS= read -r file; do active_files+=("$file"); done < <(find "$ROOT/docs" "$ROOT/resources" -type f -print)
if grep -Einh 'faucet\.gno\.land|chain/gnoland1\.0|gnoland1\.moul' "${active_files[@]}"; then
    fail "stale endpoint or release wording remains"
fi

for option in '1a' '1b' '1c' '1d' '1e' '1f' '1g' '2a' '2b' '2c' '2d' '3a' '3b' '3c' '3d'; do
    grep -Fq "$option" "$MAIN" || fail "menu option $option is missing"
done
grep -Fq 'readonly GNOLAND_ASSET_VERSION="chain/mainnet.3435+139a63fe6"' "$MAIN" ||
    fail "main launcher asset version pin is missing"
grep -Fq "1b. Update Gnoland/Gnokey from Pinned Mainnet Assets (\${GNOLAND_ASSET_VERSION})" "$MAIN" ||
    fail "1b menu entry does not surface the pinned asset version"
grep -Fq "Target source commit: \${GNOLAND_SOURCE_COMMIT}" "$MAIN" ||
    fail "update confirmation does not surface the source commit"
grep -Fq "Target asset version: \${GNOLAND_ASSET_VERSION}" "$MAIN" ||
    fail "update confirmation does not surface the asset version"
grep -Fq 'readonly GNOLAND_VALOPER_REALM="r/gnops/valopers"' "$MAIN" || fail "mainnet valoper realm pin is missing"
grep -Fq 'readonly VALOPER_GAS_FEE="1000000ugnot"' "$MAIN" || fail "mainnet valoper gas fee pin is missing"
grep -Fq 'readonly VALOPER_GAS_WANTED=50000000' "$MAIN" || fail "mainnet valoper gas wanted pin is missing"
grep -Fq '2c. Mainnet Validator Registration' "$MAIN" || fail "2c mainnet registration menu entry is missing"
if grep -Fq '2c. Mainnet Validator Registration (disabled)' "$MAIN"; then
    fail "2c mainnet registration menu is still marked disabled"
fi
grep -Fq -- '-pkgpath gno.land/r/gnops/valopers' "$MAIN" || fail "2c does not call the verified valoper realm"
grep -Fq -- '-func Register' "$MAIN" || fail "2c does not call Register"
grep -Fq -- '-gas-fee "$VALOPER_GAS_FEE"' "$MAIN" || fail "2c does not use the verified gas fee"
grep -Fq -- '-gas-wanted "$VALOPER_GAS_WANTED"' "$MAIN" || fail "2c does not use the verified gas wanted"
grep -Fq 'GetValoperRegisterFee()' "$MAIN" || fail "2c does not verify the current on-chain registration fee"
grep -Fq 'Registration blocked: the current on-chain valoper registration fee is' "$MAIN" || fail "2c does not fail closed on a nonzero registration fee"
grep -Fq 'read -r -p "Enter operator g1... address: " OPERATOR_ADDR' "$MAIN" || fail "2c does not preserve the Testnet operator-address prompt"
grep -Fq 'derived_operator_addr=$(operator_key_address "$KEY_NAME")' "$MAIN" || fail "2c does not verify the entered operator address against the selected signer"
if grep -Fq 'Registration blocked: local node must be synced on' "$MAIN"; then
    fail "2c must not hard-block candidate registration on local RPC sync state"
fi
grep -Fq 'candidate registration itself is signed with gnokey and broadcast through' "$MAIN" || fail "2c does not document local sync as advisory"
grep -Fq 'GovDAO' "$MAIN" || fail "2c does not surface the GovDAO admission gate"

# Keep the normal 2c interaction sequence aligned with Valley of Gnoland Testnet.
for prompt in \
    "Enter operator key name (default 'operator'): " \
    "Enter validator moniker: " \
    "Enter short validator description: " \
    "Enter infrastructure type (cloud/on-prem/data-center): " \
    "Enter operator g1... address: " \
    "Enter consensus gpub1... public key: " \
    "Transaction preview:" \
    "Broadcast registration transaction? (yes/no): " \
    "Candidate registration submitted if broadcast succeeded."; do
    grep -Fq -- "$prompt" "$MAIN" || fail "2c Testnet-aligned UX prompt missing: $prompt"
done

printf '%s\n' 'MAINNET_CONTRACT_TEST_OK'
