#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALLER="$ROOT/resources/gnoland_node_install.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
MAIN="$ROOT/resources/valleyofGnoland.sh"

fail() { echo "INSTALL_UPDATE_SAFETY_TEST_FAIL: $*" >&2; exit 1; }

line_of() {
    local needle=$1 file=$2
    grep -nF -- "$needle" "$file" | head -n 1 | cut -d: -f1
}

install_stage_line=$(line_of 'All source, binary, and genesis artifacts are staged and verified. Live node has not been modified yet.' "$INSTALLER")
install_cutover_line=$(line_of 'CURRENT_STAGE="atomic install cutover"' "$INSTALLER")
if [ -z "$install_stage_line" ] || [ -z "$install_cutover_line" ]; then
    fail "installer staging/cutover markers missing"
fi
[ "$install_stage_line" -lt "$install_cutover_line" ] || fail "installer cutover begins before staging completes"

update_stage_line=$(line_of 'CURRENT_STAGE="stage and verify release assets"' "$UPDATER")
update_cutover_line=$(line_of 'CURRENT_STAGE="cut over reviewed runtime"' "$UPDATER")
if [ -z "$update_stage_line" ] || [ -z "$update_cutover_line" ]; then
    fail "updater staging/cutover markers missing"
fi
[ "$update_stage_line" -lt "$update_cutover_line" ] || fail "updater cutover begins before staging completes"

grep -Fq 'Create a persistent backup of existing node secrets and operator keyring first? (Y/n): ' "$INSTALLER" ||
    fail "installer does not ask whether to create a persistent backup"
grep -Fq 'Persistent backup skipped by operator choice.' "$INSTALLER" ||
    fail "installer does not allow persistent backup to be skipped"
grep -Fq 'Preserved existing validator/node secrets exactly for safe reinstall.' "$INSTALLER" ||
    fail "safe reinstall does not preserve validator/node secrets"
grep -Fq 'Generated fresh node secrets for a fresh installation.' "$INSTALLER" ||
    fail "fresh-install-only secret generation boundary missing"
grep -Fq 'rollback_install()' "$INSTALLER" || fail "installer rollback function missing"
grep -Fq 'rollback_update()' "$UPDATER" || fail "updater rollback function missing"
grep -Fq 'wait_for_rpc_health()' "$UPDATER" || fail "updater health gate missing"
grep -Fq 'Already up to date.' "$UPDATER" || fail "updater no-op path missing"
grep -Fq 'Only gnokey changed; the running gnoland service was not restarted.' "$UPDATER" ||
    fail "updater gnokey-only no-restart path missing"

for script in "$INSTALLER" "$UPDATER"; do
    rel=${script#"$ROOT"/}
    grep -Fq "fetch --depth 1 origin \"\$SOURCE_COMMIT\"" "$script" || fail "exact source-commit fetch missing in $rel"
    if grep -Fq "fetch --depth 1 origin \"refs/heads/\$SOURCE_BRANCH\"" "$script"; then
        fail "branch-tip equality still drives source pinning in $rel"
    fi
    grep -Fq 'RELEASE_API_URL="https://api.github.com/repos/gnolang/gno/releases/tags/chain%2Fmainnet"' "$script" ||
        fail "release-drift metadata check missing in $rel"
    grep -Fq 'GENESIS_GZ_SHA256="32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9"' "$script" ||
        fail "compressed genesis verification missing in $rel"
done

grep -Fq 'Type ENABLE-UFW to apply these rules and enable UFW' "$INSTALLER" || fail "UFW second confirmation missing"
if grep -Fq 'ufw allow 22/tcp' "$INSTALLER"; then
    fail "installer still hard-codes SSH port 22 for UFW"
fi

for profile_file in "$INSTALLER" "$UPDATER" "$MAIN"; do
    rel=${profile_file#"$ROOT"/}
    grep -Fq '# >>> GRAND VALLEY GNOLAND MAINNET >>>' "$profile_file" || fail "managed profile block missing in $rel"
    if grep -Fq 'go\/bin/d' "$profile_file"; then
        fail "profile management can delete unrelated go/bin lines in $rel"
    fi
done

printf '%s\n' 'INSTALL_UPDATE_SAFETY_TEST_OK'
