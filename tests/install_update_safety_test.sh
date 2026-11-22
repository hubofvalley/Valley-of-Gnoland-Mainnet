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

# v1.8.0 became mandatory after the completed governance halt at 1,651,500.
# Extract only the guard; never invoke the actual launcher, installer, updater,
# RPC, systemd, keyring, or external network.
MAIN="$ROOT/resources/valleyofGnoland.sh"
guard_call=$(line_of 'guard_obsolete_mainnet_helpers "$relative_path" || return 1' "$MAIN")
local_call=$(line_of 'bash "$script_dir/../$relative_path"' "$MAIN")
remote_fetch=$(line_of '/${relative_path}" -o "$script_file"; then' "$MAIN")
[ -n "$guard_call" ] && [ -n "$local_call" ] && [ -n "$remote_fetch" ] ||
    fail "missing obsolete mainnet helper guard or helper execution boundaries"
[ "$guard_call" -lt "$local_call" ] && [ "$guard_call" -lt "$remote_fetch" ] ||
    fail "obsolete mainnet gate must run before local or remote helpers"

run_obsolete_guard() {
    {
        sed -n '/^guard_obsolete_mainnet_helpers() {/,/^}/p' "$MAIN"
        printf '%s\n' 'guard_obsolete_mainnet_helpers "$1"'
    } | bash -s -- "$1"
}

for helper in resources/gnoland_node_install.sh resources/gnoland_update.sh; do
    if output=$(run_obsolete_guard "$helper" 2>&1); then
        fail "$helper must be blocked for the obsolete v1.7.0 runtime"
    fi
    grep -Fq 'requires v1.8.0 after block 1,651,500' <<<"$output" ||
        fail "$helper must explain the completed upgrade requirement"
    grep -Fq 'official upgrade ledger' <<<"$output" ||
        fail "$helper must link the authoritative recovery guidance"
done
run_obsolete_guard resources/gnoland_node_doctor.sh >/dev/null ||
    fail "read-only Node Doctor must remain available"
run_obsolete_guard resources/apply_snapshot.sh >/dev/null ||
    fail "unrelated helper paths must remain unchanged"


# The launcher gate cannot protect someone who invokes an installer/updater
# script directly. Execute only the extracted guard, never the helpers.
for helper in "$INSTALLER" "$UPDATER"; do
    direct_guard=$(line_of 'guard_obsolete_direct_helper || exit 1' "$helper")
    runtime_start=$(line_of 'GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-' "$helper")
    [ -n "$direct_guard" ] && [ -n "$runtime_start" ] &&
        [ "$direct_guard" -lt "$runtime_start" ] ||
        fail "$helper must fail before runtime setup"
    if grep -Fq 'source "$HOME/.bash_profile"' "$helper"; then
        profile_source=$(line_of 'source "$HOME/.bash_profile"' "$helper")
        [ "$direct_guard" -lt "$profile_source" ] ||
            fail "$helper must fail before shell profile execution"
    fi
    if guard_output=$({
        sed -n '/^guard_obsolete_direct_helper() {/,/^}/p' "$helper"
        printf '%s\n' 'guard_obsolete_direct_helper'
    } | bash 2>&1); then
        fail "$helper direct invocation must reject the obsolete release"
    fi
    grep -Fq 'requires Gnoland v1.8.0 after block 1,651,500' <<<"$guard_output" ||
        fail "$helper must explain why direct invocation is blocked"
    grep -Fq 'Official upgrade ledger:' <<<"$guard_output" ||
        fail "$helper must link official recovery guidance"
done

printf '%s\\n' INSTALL_UPDATE_SAFETY_TEST_OK
