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
for fact in gnoland-1 v1.7.0 e4c2e7d9fe0f6f7aeeda54885ca1fe5cea991319 9c8eb132e483d6fd324d92c193e629ad65a98a37 7d7771d899f8d6a266cf3c1fb2a9a997f2ad5791f3082dc0ee54711d9e5b5a79 5e5525d53eabe65e6016d0669f5c7569a029c3ff6099105e0e5b7b7e0e461b51 8cfe6bc58cbd010c8077e48a6eb18d0045e8f56289fe2b38eb699957a9bb9a0e 912eb2bdc23e715ba3b581ee418f4e572c52407f391c7282bb839ec151a129b3 https://rpc.gno.land r/gnops/valopers r/sys/validators/v0; do
  grep -R -Fq -- "$fact" "$ROOT/README.md" "$ROOT/VERSIONS.json" "$ROOT/VALLEY.json" "$ROOT/docs" "$ROOT/resources" || fail "missing fact $fact"
done
for script in "$INSTALLER" "$UPDATER"; do
  grep -Fq 'SOURCE_BRANCH="chain/mainnet"' "$script" || fail "source branch"
  grep -Fq 'SOURCE_TAG="v1.7.0"' "$script" || fail "source tag"
  grep -Fq 'SOURCE_COMMIT="e4c2e7d9fe0f6f7aeeda54885ca1fe5cea991319"' "$script" || fail "source commit"
  grep -Fq 'RELEASE_TAG="v1.7.0"' "$script" || fail "release tag"
  grep -Fq 'RELEASE_COMMIT="e4c2e7d9fe0f6f7aeeda54885ca1fe5cea991319"' "$script" || fail "release commit"
  grep -Fq 'RELEASE_API_URL="https://api.github.com/repos/gnolang/gno/releases/tags/v1.7.0"' "$script" || fail "release API"
  grep -Fq 'CHECKSUMS_SHA256="912eb2bdc23e715ba3b581ee418f4e572c52407f391c7282bb839ec151a129b3"' "$script" || fail "checksums"
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
[ "$(jq -r '.versioned_release_tag' "$VERSIONS")" = v1.7.0 ] || fail "VERSIONS runtime tag"
[ "$(jq -r '.versioned_release_commit' "$VERSIONS")" = e4c2e7d9fe0f6f7aeeda54885ca1fe5cea991319 ] || fail "VERSIONS runtime commit"
[ "$(jq -r '.source_commit' "$VERSIONS")" = e4c2e7d9fe0f6f7aeeda54885ca1fe5cea991319 ] || fail "VERSIONS source commit"
[ "$(jq -r '.versioned_binary_assets.checksums_sha256' "$VERSIONS")" = 912eb2bdc23e715ba3b581ee418f4e572c52407f391c7282bb839ec151a129b3 ] || fail "VERSIONS checksums"
[ "$(jq -r '.versioned_binary_assets.gno.sha256' "$VERSIONS")" = 7d7771d899f8d6a266cf3c1fb2a9a997f2ad5791f3082dc0ee54711d9e5b5a79 ] || fail "VERSIONS gno"
[ "$(jq -r '.install.mode' "$VALLEY")" = verified_release_assets ] || fail "VALLEY mode"
[ "$(jq -r '.install.reported_version' "$VALLEY")" = v1.7.0 ] || fail "VALLEY version"
for option in 1a 1b 1c 1d 1e 1f 1g 2a 2b 2c 3a 3b 3c 3d; do grep -Fq "$option" "$MAIN" || fail "menu option $option"; done
grep -Fq 'official v1.7.0 release assets' "$MAIN" || fail "menu release wording"
printf '%s\\n' MAINNET_CONTRACT_TEST_OK
