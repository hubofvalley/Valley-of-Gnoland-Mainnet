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
for profile_file in "$INSTALLER" "$UPDATER" "$MAIN"; do
    grep -Fq '# >>> GRAND VALLEY GNOLAND MAINNET >>>' "$profile_file" || fail "managed profile block start missing in ${profile_file#$ROOT/}"
    grep -Fq '# <<< GRAND VALLEY GNOLAND MAINNET <<<' "$profile_file" || fail "managed profile block end missing in ${profile_file#$ROOT/}"
    if grep -Fq "go\\/bin/d" "$profile_file"; then
        fail "profile management still deletes arbitrary go/bin lines in ${profile_file#$ROOT/}"
    fi
    if grep -Fq 'GNOLAND_TESTNET_HOME' "$profile_file" || grep -Fq 'GNOLAND_TESTNET_SERVICE_NAME' "$profile_file"; then
        fail "mainnet profile management may touch testnet-scoped exports in ${profile_file#$ROOT/}"
    fi
done

facts=(
    'gnoland-1'
    'chain/mainnet'
    'e75fef82c02876a4df92ad6e325c5479b9532168'
    '9c8eb132e483d6fd324d92c193e629ad65a98a37'
    'misc/deployments/mainnet.gno.land/'
    'ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0'
    '32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9'
    '5f568a5c96f9a0f9f20f5b0adbc72cc0d5c640e82bd3c7b129bb629758f029bc'
    '2d9f3019107403879e7b9f398deb15107945f33b91bc4ee85b938ff7f60b03cd'
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
    grep -Fq 'SOURCE_COMMIT="e75fef82c02876a4df92ad6e325c5479b9532168"' "$script" || fail "$script does not pin the mainnet source commit"
    grep -Fq 'RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"' "$script" || fail "$script does not retain release tag metadata"
    grep -Fq 'RELEASE_API_URL="https://api.github.com/repos/gnolang/gno/releases/tags/chain%2Fmainnet"' "$script" || fail "$script does not check upstream release metadata"
    grep -Fq 'ASSET_VERSION="heads/chain/mainnet.3444+e75fef82c"' "$script" || fail "$script does not verify the reviewed asset identity"
    grep -Fq 'GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"' "$script" || fail "$script does not verify the official mainnet genesis"
    grep -Fq 'GENESIS_GZ_SHA256="32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9"' "$script" || fail "$script does not verify the compressed official mainnet genesis"
    grep -Fq 'fetch --depth 1 origin "$SOURCE_COMMIT"' "$script" || fail "$script does not fetch the exact reviewed source commit"
    if grep -Fq 'fetch --depth 1 origin "refs/heads/$SOURCE_BRANCH"' "$script"; then
        fail "$script still makes branch-tip equality part of the runtime pin"
    fi
done

grep -Fq 'GNO_IMAGE_REPOSITORY=' "$INSTALLER" || fail "gno OCI repository pin missing"
grep -Fq 'GNO_IMAGE_MANIFEST_DIGEST=' "$INSTALLER" || fail "gno OCI manifest pin missing"
grep -Fq 'GNOLAND_IMAGE_REPOSITORY=' "$INSTALLER" || fail "gnoland OCI repository pin missing"
grep -Fq 'GNOLAND_IMAGE_MANIFEST_DIGEST=' "$INSTALLER" || fail "gnoland OCI manifest pin missing"
grep -Fq 'GNOKEY_IMAGE_REPOSITORY=' "$INSTALLER" || fail "gnokey OCI repository pin missing"
grep -Fq 'GNOKEY_IMAGE_MANIFEST_DIGEST=' "$INSTALLER" || fail "gnokey OCI manifest pin missing"
grep -Fq 'stage_oci_binary gno' "$INSTALLER" || fail "gno OCI extraction missing"
grep -Fq 'stage_oci_binary gnoland' "$INSTALLER" || fail "gnoland OCI extraction missing"
grep -Fq 'stage_oci_binary gnokey' "$INSTALLER" || fail "gnokey OCI extraction missing"
grep -Fq -- '--skip-genesis-sig-verification' "$INSTALLER" || fail "mainnet startup verification flag missing"
grep -Fq 'INSTALL-GNOLAND-1' "$INSTALLER" || fail "explicit install confirmation missing"
grep -Fq 'Destructive reinstall refused' "$INSTALLER" || fail "unknown existing node guard missing"
grep -Fq 'Create a persistent backup of existing node secrets and operator keyring first? (Y/n): ' "$INSTALLER" || fail "optional persistent-backup prompt missing"
grep -Fq 'Preserved existing validator/node secrets exactly for safe reinstall.' "$INSTALLER" || fail "safe reinstall identity preservation missing"
grep -Fq 'All source, binary, and genesis artifacts are staged and verified. Live node has not been modified yet.' "$INSTALLER" || fail "stage-first install boundary missing"
grep -Fq 'Type ENABLE-UFW to apply these rules and enable UFW' "$INSTALLER" || fail "explicit UFW confirmation missing"
grep -Fq 'rollback_install()' "$INSTALLER" || fail "install rollback missing"
grep -Fq 'rollback_update()' "$UPDATER" || fail "update rollback missing"
grep -Fq 'Already up to date.' "$UPDATER" || fail "update no-op detection missing"
grep -Fq 'wait_for_rpc_health()' "$UPDATER" || fail "post-update RPC health gate missing"
grep -Fq 'Only gnokey changed; the running gnoland service was not restarted.' "$UPDATER" || fail "gnokey-only no-restart path missing"
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
[ "$(jq -r '.source_commit' "$VERSIONS")" = 'e75fef82c02876a4df92ad6e325c5479b9532168' ] || fail "VERSIONS source commit is wrong"
[ "$(jq -r '.deployment_path' "$VERSIONS")" = 'misc/deployments/mainnet.gno.land/' ] || fail "VERSIONS deployment path is wrong"
[ "$(jq -r '.oci_images.gno.binary_sha256' "$VERSIONS")" = '423a64b605400882ac6ae016ef517b2465d64c49e71fd8d45d6d3a6ecfe0e87d' ] || fail "VERSIONS gno hash is wrong"
[ "$(jq -r '.oci_images.gnoland.binary_sha256' "$VERSIONS")" = '5f568a5c96f9a0f9f20f5b0adbc72cc0d5c640e82bd3c7b129bb629758f029bc' ] || fail "VERSIONS gnoland hash is wrong"
[ "$(jq -r '.oci_images.gnokey.binary_sha256' "$VERSIONS")" = '2d9f3019107403879e7b9f398deb15107945f33b91bc4ee85b938ff7f60b03cd' ] || fail "VERSIONS gnokey hash is wrong"
[ "$(jq -r '.oci_images.reported_version' "$VERSIONS")" = 'heads/chain/mainnet.3444+e75fef82c' ] || fail "VERSIONS OCI reported version is wrong"
[ "$(jq -r '.genesis.sha256' "$VERSIONS")" = 'ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0' ] || fail "VERSIONS genesis hash is wrong"
[ "$(jq -r '.genesis.compressed_sha256' "$VERSIONS")" = '32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9' ] || fail "VERSIONS compressed genesis hash is wrong"
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
[ "$(jq -r '.install.reported_version' "$VALLEY")" = 'heads/chain/mainnet.3444+e75fef82c' ] || fail "VALLEY asset reported version is wrong"
[ "$(jq -r '.install.persistent_backup' "$VALLEY")" = 'optional_prompt' ] || fail "VALLEY backup policy is wrong"
[ "$(jq -r '.install.preserve_existing_node_secrets' "$VALLEY")" = 'true' ] || fail "VALLEY identity-preservation policy is missing"
[ "$(jq -r '.endpoints.faucet' "$VALLEY")" = 'null' ] || fail "VALLEY must state that no faucet exists"

active_files=("$ROOT/README.md" "$ROOT/VERSIONS.json" "$ROOT/VALLEY.json")
while IFS= read -r file; do active_files+=("$file"); done < <(find "$ROOT/docs" "$ROOT/resources" -type f -print)
if grep -Einh 'faucet\.gno\.land|chain/gnoland1\.0|gnoland1\.moul' "${active_files[@]}"; then
    fail "stale endpoint or release wording remains"
fi

for option in '1a' '1b' '1c' '1d' '1e' '1f' '1g' '2a' '2b' '2c' '2d' '3a' '3b' '3c' '3d'; do
    grep -Fq "$option" "$MAIN" || fail "menu option $option is missing"
done
grep -Fq 'readonly GNOLAND_ASSET_VERSION="heads/chain/mainnet.3444+e75fef82c"' "$MAIN" ||
    fail "main launcher asset version pin is missing"
grep -Fq "1b. Update Gno/Gnoland/Gnokey from Pinned Mainnet OCI Assets (\${GNOLAND_ASSET_VERSION})" "$MAIN" ||
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
grep -Fq -- '-pkgpath "gno.land/$GNOLAND_VALOPER_REALM"' "$MAIN" || fail "2c does not call the verified valoper realm pin"
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
grep -Fq 'local RPC sync is not a transaction blocker' "$MAIN" || fail "2c does not document local sync as advisory"
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
    "Candidate registration transaction broadcast succeeded."; do
    grep -Fq -- "$prompt" "$MAIN" || fail "2c Testnet-aligned UX prompt missing: $prompt"
done

printf '%s\n' 'MAINNET_CONTRACT_TEST_OK'
