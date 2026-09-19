#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MAIN="$ROOT/resources/valleyofGnoland.sh"
fail() { echo "VALIDATOR_INTERACTIONS_TEST_FAIL: $*" >&2; exit 1; }

for text in \
    '2b. Validator Identity & Status' \
    '2d. Account & Balance Dashboard' \
    '2e. Manage Valoper Profile' \
    '2f. Advanced Validator Operations' \
    '2g. Advanced Query / Realm Inspector' \
    'bank/balances/$operator_addr' \
    'auth/accounts/$operator_addr' \
    'query auth/gasprice' \
    'GetValoperRegisterFee()' \
    'GetValoperRotationFee()' \
    'GetValoperRotationPeriodBlocks()' \
    'UpdateMoniker' \
    'UpdateDescription' \
    'UpdateServerType' \
    'UpdateKeepRunning' \
    'UpdateSigningKey' \
    'vm/qrender' \
    'vm/qfuncs' \
    'vm/qdoc' \
    'vm/qeval' \
    'vm/qstorage' \
    'vm/qpaths?limit=100'; do
    grep -Fq "$text" "$MAIN" || fail "missing operator-console contract: $text"
done

if grep -Fq 'Registration blocked: local node must be synced on' "$MAIN"; then
    fail "registration sync hard-block must not return"
fi
grep -Fq 'operator address does not match key' "$MAIN" || fail "signer/address guard missing"
grep -Fq 'broadcast_valoper_call "$key_name" UpdateSigningKey ROTATE' "$MAIN" || fail "rotation confirmation guard missing"
grep -Fq 'Registration blocked: candidate profile status could not be verified' "$MAIN" ||
    fail "registration does not fail closed when candidate status is UNKNOWN"
grep -Fq 'Valley will not treat an RPC or realm query failure as Candidate exists: NO.' "$MAIN" ||
    fail "registration does not document the false-negative guard"
if grep -Fq 'profile=$(valoper_profile_output "$operator_addr" || true)' "$MAIN"; then
    fail "read-only profile query failures must not be collapsed into a missing-profile result"
fi

extract_function() {
    sed -n "/^function $1() {$/,/^}$/p" "$MAIN"
}

for fn in \
    valoper_profile_output \
    active_valset_output \
    profile_signing_pubkey \
    query_valoper_profile_status \
    query_active_validator_status; do
    definition=$(extract_function "$fn")
    [ -n "$definition" ] || fail "unable to extract helper for mocked status test: $fn"
    eval "$definition"
done

export GNOLAND_VALOPER_REALM="r/gnops/valopers"
export GNOLAND_ACTIVE_REALM="r/sys/validators/v0"
MOCK_MODE="failure"

gnokey_cmd() {
    case "$MOCK_MODE" in
        failure)
            return 1
            ;;
        profile_none)
            printf '%s\n' 'height: 0' 'data: unknown address g1test'
            ;;
        profile_yes)
            printf '%s\n' \
                'height: 0' \
                "data: Valoper's details:" \
                '- Signing Address: g1sign' \
                '- Signing PubKey: gpub1abc'
            ;;
        active_none)
            printf '%s\n' 'height: 0' 'data: ## Valset at height 100'
            ;;
        active_yes)
            printf '%s\n' 'height: 0' 'data: ## Valset at height 100' '- #0: g1sign (1)'
            ;;
        malformed)
            printf '%s\n' 'height: 0' 'data: unexpected response'
            ;;
        *)
            return 1
            ;;
    esac
}

MOCK_MODE="failure"
if query_valoper_profile_status g1test; then
    fail "profile RPC failure must not resolve as YES/NO"
fi
[ "$VALOPER_PROFILE_QUERY_STATUS" = "UNKNOWN" ] ||
    fail "profile RPC failure must remain UNKNOWN"

MOCK_MODE="malformed"
if query_valoper_profile_status g1test; then
    fail "malformed profile response must not resolve as YES/NO"
fi
[ "$VALOPER_PROFILE_QUERY_STATUS" = "UNKNOWN" ] ||
    fail "malformed profile response must remain UNKNOWN"

MOCK_MODE="profile_none"
query_valoper_profile_status g1test || fail "verified missing profile query should succeed"
[ "$VALOPER_PROFILE_QUERY_STATUS" = "NO" ] ||
    fail "verified unknown-address response must resolve as NO"

MOCK_MODE="profile_yes"
query_valoper_profile_status g1test || fail "verified profile query should succeed"
[ "$VALOPER_PROFILE_QUERY_STATUS" = "YES" ] ||
    fail "verified profile response must resolve as YES"

MOCK_MODE="failure"
if query_active_validator_status g1sign; then
    fail "active-set RPC failure must not resolve as YES/NO"
fi
[ "$ACTIVE_VALIDATOR_QUERY_STATUS" = "UNKNOWN" ] ||
    fail "active-set RPC failure must remain UNKNOWN"

MOCK_MODE="malformed"
if query_active_validator_status g1sign; then
    fail "malformed active-set response must not resolve as YES/NO"
fi
[ "$ACTIVE_VALIDATOR_QUERY_STATUS" = "UNKNOWN" ] ||
    fail "malformed active-set response must remain UNKNOWN"

MOCK_MODE="active_none"
query_active_validator_status g1sign || fail "verified active-set query should succeed"
[ "$ACTIVE_VALIDATOR_QUERY_STATUS" = "NO" ] ||
    fail "verified absence from active set must resolve as NO"

MOCK_MODE="active_yes"
query_active_validator_status g1sign || fail "verified active-set membership query should succeed"
[ "$ACTIVE_VALIDATOR_QUERY_STATUS" = "YES" ] ||
    fail "verified active-set membership must resolve as YES"

printf '%s\n' 'VALIDATOR_INTERACTIONS_TEST_OK'
