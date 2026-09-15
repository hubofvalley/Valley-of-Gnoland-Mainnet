#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHECK="$ROOT/resources/check_release_identity.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "RELEASE_IDENTITY_TEST_FAIL: $*" >&2; exit 1; }

make_fake() {
    local path=$1 version=$2
    cat > "$path" <<EOF
#!/bin/bash
if [ "\${1:-}" = "version" ]; then
    echo "gnoland version: $version"
    exit 0
fi
exit 2
EOF
    chmod +x "$path"
}

make_fake "$TMP/develop" develop
make_fake "$TMP/release" v1.3.0

set +e
develop_output=$(bash "$CHECK" --binary "$TMP/develop" 2>&1)
develop_rc=$?
set -e
[ "$develop_rc" -eq 1 ] || fail "develop identity must block coordinated-upgrade use"
printf '%s\n' "$develop_output" | grep -Fq 'Release identity: BLOCKED' || fail "develop result is not BLOCKED"
printf '%s\n' "$develop_output" | grep -Fq 'Reported version: develop' || fail "develop version is not surfaced"

release_output=$(bash "$CHECK" --binary "$TMP/release" --expect v1.3.0)
printf '%s\n' "$release_output" | grep -Fq 'Release identity: IDENTIFIED' || fail "explicit release identity was not accepted"
printf '%s\n' "$release_output" | grep -Fq 'Expected version: v1.3.0' || fail "expected version is not surfaced"

set +e
mismatch_output=$(bash "$CHECK" --binary "$TMP/release" --expect v1.4.0 2>&1)
mismatch_rc=$?
set -e
[ "$mismatch_rc" -eq 1 ] || fail "version mismatch must block"
printf '%s\n' "$mismatch_output" | grep -Fq 'exact reviewed release version' || fail "version mismatch reason missing"

json_output=$(bash "$CHECK" --binary "$TMP/release" --expect v1.3.0 --json)
[ "$(printf '%s' "$json_output" | jq -r '.status')" = 'IDENTIFIED' ] || fail "JSON status is wrong"
[ "$(printf '%s' "$json_output" | jq -r '.version')" = 'v1.3.0' ] || fail "JSON version is wrong"

set +e
bash "$CHECK" --binary "$TMP/missing" >/dev/null 2>&1
missing_rc=$?
set -e
[ "$missing_rc" -eq 2 ] || fail "missing binary must return usage/runtime error status"

grep -Fq "version = \"develop\"" "$CHECK" && fail "check must inspect the binary rather than hard-code the launch version"

printf '%s\n' 'RELEASE_IDENTITY_TEST_OK'
