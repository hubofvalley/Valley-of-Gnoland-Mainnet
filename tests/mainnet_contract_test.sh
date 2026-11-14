#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
INSTALLER="$ROOT/resources/gnoland_node_install.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
MAIN="$ROOT/resources/valleyofGnoland.sh"
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
VERSIONS="$ROOT/VERSIONS.json"
VALLEY="$ROOT/VALLEY.json"
fail(){ echo "MAINNET_CONTRACT_TEST_FAIL: $*" >&2; exit 1; }
for f in "$INSTALLER" "$UPDATER" "$MAIN" "$DOCTOR" "$VERSIONS" "$VALLEY"; do [ -f "$f" ] || fail "missing $f"; done
for legacy in GNOLAND_HOME GNOLAND_SERVICE_NAME GNOLAND_TESTNET_HOME GNOLAND_TESTNET_SERVICE_NAME; do
  if grep -R -n -F -- "$legacy" "$ROOT/README.md" "$ROOT/VALLEY.json" "$ROOT/VERSIONS.json" "$ROOT/resources" "$ROOT/docs"; then fail "legacy variable remains: $legacy"; fi
done
for script in "$MAIN" "$INSTALLER" "$UPDATER" "$DOCTOR"; do
  grep -Fq GNOLAND_MAINNET_HOME "$script" || fail "mainnet home missing"
  grep -Fq GNOLAND_MAINNET_SERVICE_NAME "$script" || fail "mainnet service missing"
done
for fact in gnoland-1 v1.7.1 83431a7f0261882541a8a8dcf1643e6f246bbbe5 9c8eb132e483d6fd324d92c193e629ad65a98a37 0f6c479d898a7fb2b37087a3697c084fd6c2babf1e082cbadc7b8fd9964e5209 dbe89748f42a633a925153b16567a1229db9bd5004583ce64c80982e3e010565 a3fa71fbb0c6e7789157f7d2eb9f1401ba86eb6ca3d237aba98fe0ec8628c674 8028057a68bc7ca87fd1e86f87d1eeb77c1bb69b064896b01ce44b48ee8a1642 https://rpc.gno.land https://gpas.gno.land/ r/gnops/valopers r/sys/validators/v0; do
  grep -R -Fq -- "$fact" "$ROOT/README.md" "$ROOT/VERSIONS.json" "$ROOT/VALLEY.json" "$ROOT/docs" "$ROOT/resources" || fail "missing fact $fact"
done
for script in "$INSTALLER" "$UPDATER"; do
  grep -Fq 'SOURCE_BRANCH="chain/mainnet"' "$script" || fail "source branch"
  grep -Fq 'SOURCE_TAG="v1.7.1"' "$script" || fail "source tag"
  grep -Fq 'SOURCE_COMMIT="83431a7f0261882541a8a8dcf1643e6f246bbbe5"' "$script" || fail "source commit"
  grep -Fq 'RELEASE_TAG="v1.7.1"' "$script" || fail "release tag"
  grep -Fq 'RELEASE_COMMIT="83431a7f0261882541a8a8dcf1643e6f246bbbe5"' "$script" || fail "release commit"
  grep -Fq 'RELEASE_API_URL="https://api.github.com/repos/gnolang/gno/releases/tags/v1.7.1"' "$script" || fail "release API"
  grep -Fq 'CHECKSUMS_SHA256="8028057a68bc7ca87fd1e86f87d1eeb77c1bb69b064896b01ce44b48ee8a1642"' "$script" || fail "checksums"
  grep -Fq 'stage_release_binary gno' "$script" || fail "gno staging"
  grep -Fq 'stage_release_binary gnoland' "$script" || fail "gnoland staging"
  grep -Fq 'stage_release_binary gnokey' "$script" || fail "gnokey staging"
  grep -Fq rollback_ "$script" || fail "rollback"
  if grep -qE 'OCI|stage_oci_binary|GNO_IMAGE|GNOLAND_IMAGE|GNOKEY_IMAGE|v1\\.2\\.0' "$script"; then fail "stale release logic"; fi
done
grep -Fq 'INSTALL-GNOLAND-1' "$INSTALLER" || fail "install confirmation"
grep -Fq 'Type ENABLE-UFW to apply these rules and enable UFW' "$INSTALLER" || fail "UFW confirmation"
grep -Fq 'Already up to date.' "$UPDATER" || fail "no-op update"
grep -Fq 'wait_for_rpc_health()' "$UPDATER" || fail "health gate"
[ "$(jq -r '.versioned_release_tag' "$VERSIONS")" = v1.7.1 ] || fail "VERSIONS runtime tag"
[ "$(jq -r '.versioned_release_commit' "$VERSIONS")" = 83431a7f0261882541a8a8dcf1643e6f246bbbe5 ] || fail "VERSIONS runtime commit"
[ "$(jq -r '.source_commit' "$VERSIONS")" = 83431a7f0261882541a8a8dcf1643e6f246bbbe5 ] || fail "VERSIONS source commit"
[ "$(jq -r '.versioned_binary_assets.checksums_sha256' "$VERSIONS")" = 8028057a68bc7ca87fd1e86f87d1eeb77c1bb69b064896b01ce44b48ee8a1642 ] || fail "VERSIONS checksums"
[ "$(jq -r '.versioned_binary_assets.gno.sha256' "$VERSIONS")" = 0f6c479d898a7fb2b37087a3697c084fd6c2babf1e082cbadc7b8fd9964e5209 ] || fail "VERSIONS gno"
[ "$(jq -r '.install.mode' "$VALLEY")" = verified_release_assets ] || fail "VALLEY mode"
[ "$(jq -r '.install.reported_version' "$VALLEY")" = v1.7.1 ] || fail "VALLEY version"
for option in 1a 1b 1c 1d 1e 1f 1g 2a 2b 2c 3a 3b 3c 3d; do grep -Fq "$option" "$MAIN" || fail "menu option $option"; done
grep -Fq 'official v1.7.1 release assets' "$MAIN" || fail "menu release wording"
printf '%s\\n' MAINNET_CONTRACT_TEST_OK
