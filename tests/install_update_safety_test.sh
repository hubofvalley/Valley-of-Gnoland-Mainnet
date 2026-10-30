#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
INSTALLER="$ROOT/resources/gnoland_node_install.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
fail(){ echo "INSTALL_UPDATE_SAFETY_TEST_FAIL: $*" >&2; exit 1; }
line_of(){ grep -nF -- "$1" "$2" | head -n1 | cut -d: -f1; }
a=$(line_of 'CURRENT_STAGE="stage all reviewed artifacts before cutover"' "$INSTALLER"); b=$(line_of 'CURRENT_STAGE="atomic install cutover"' "$INSTALLER"); [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] || fail "installer staging boundary"
a=$(line_of 'CURRENT_STAGE="stage and verify v1.7.0 release assets"' "$UPDATER"); b=$(line_of 'CURRENT_STAGE="cut over reviewed runtime"' "$UPDATER"); [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] || fail "updater staging boundary"
grep -Fq 'Create a persistent backup of existing node secrets and operator keyring first? (Y/n): ' "$INSTALLER" || fail "backup prompt"
grep -Fq 'Preserved existing validator/node secrets exactly for safe reinstall.' "$INSTALLER" || fail "identity preservation"
grep -Fq rollback_install "$INSTALLER" || fail "installer rollback"
grep -Fq rollback_update "$UPDATER" || fail "updater rollback"
grep -Fq wait_for_rpc_health "$UPDATER" || fail "health gate"
grep -Fq 'Already up to date.' "$UPDATER" || fail "no-op path"
grep -Fq 'CHECKSUMS_URL=' "$INSTALLER" || fail "installer checksum URL"
grep -Fq 'CHECKSUMS_URL=' "$UPDATER" || fail "updater checksum URL"
if grep -Eiq 'OCI|stage_oci_binary|v1\\.2\\.0|e75fef82|v1\\.5\\.0|v1\\.5\\.1' "$INSTALLER" "$UPDATER"; then fail "stale release logic"; fi
printf '%s\\n' INSTALL_UPDATE_SAFETY_TEST_OK
