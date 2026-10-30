#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHECK="$ROOT/resources/check_release_identity.sh"
VERSIONS="$ROOT/VERSIONS.json"
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

file_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        fail "test host has no SHA-256 utility"
    fi
}

make_fake "$TMP/develop" develop
make_fake "$TMP/release" v1.3.0
release_sha=$(file_sha256 "$TMP/release")

set +e
develop_output=$(bash "$CHECK" --binary "$TMP/develop" 2>&1)
develop_rc=$?
set -e
[ "$develop_rc" -eq 1 ] || fail "develop identity must block coordinated-upgrade use"
printf '%s\n' "$develop_output" | grep -Fq 'Release identity: BLOCKED' || fail "develop result is not BLOCKED"
printf '%s\n' "$develop_output" | grep -Fq 'Reported version: develop' || fail "develop version is not surfaced"

release_output=$(bash "$CHECK" --binary "$TMP/release" --expect v1.3.0 --expect-sha256 "$release_sha")
printf '%s\n' "$release_output" | grep -Fq 'Release identity: IDENTIFIED' || fail "explicit release identity was not accepted"
printf '%s\n' "$release_output" | grep -Fq 'Expected version: v1.3.0' || fail "expected version is not surfaced"
printf '%s\n' "$release_output" | grep -Fq "SHA-256: $release_sha" || fail "actual digest is not surfaced"
printf '%s\n' "$release_output" | grep -Fq "Expected SHA-256: $release_sha" || fail "expected digest is not surfaced"

set +e
mismatch_output=$(bash "$CHECK" --binary "$TMP/release" --expect v1.4.0 2>&1)
mismatch_rc=$?
set -e
[ "$mismatch_rc" -eq 1 ] || fail "version mismatch must block"
printf '%s\n' "$mismatch_output" | grep -Fq 'exact reviewed release version' || fail "version mismatch reason missing"

wrong_sha=$(printf '0%.0s' {1..64})
[ "$wrong_sha" != "$release_sha" ] || wrong_sha=$(printf 'f%.0s' {1..64})
set +e
sha_mismatch_output=$(bash "$CHECK" --binary "$TMP/release" --expect v1.3.0 --expect-sha256 "$wrong_sha" 2>&1)
sha_mismatch_rc=$?
set -e
[ "$sha_mismatch_rc" -eq 1 ] || fail "digest mismatch must block"
printf '%s\n' "$sha_mismatch_output" | grep -Fq 'exact reviewed artifact digest' || fail "digest mismatch reason missing"

set +e
bash "$CHECK" --binary "$TMP/release" --expect-sha256 not-a-digest >/dev/null 2>&1
invalid_sha_rc=$?
set -e
[ "$invalid_sha_rc" -eq 2 ] || fail "malformed expected digest must return usage/runtime error status"

json_output=$(bash "$CHECK" --binary "$TMP/release" --expect v1.3.0 --expect-sha256 "$release_sha" --json)
[ "$(printf '%s' "$json_output" | jq -r '.status')" = 'IDENTIFIED' ] || fail "JSON status is wrong"
[ "$(printf '%s' "$json_output" | jq -r '.version')" = 'v1.3.0' ] || fail "JSON version is wrong"
[ "$(printf '%s' "$json_output" | jq -r '.sha256')" = "$release_sha" ] || fail "JSON digest is wrong"
[ "$(printf '%s' "$json_output" | jq -r '.expected_sha256')" = "$release_sha" ] || fail "JSON expected digest is wrong"

set +e
bash "$CHECK" --binary "$TMP/missing" >/dev/null 2>&1
missing_rc=$?
set -e
[ "$missing_rc" -eq 2 ] || fail "missing binary must return usage/runtime error status"

[ "$(jq -r '.versioned_release_tag' "$VERSIONS")" = 'v1.7.0' ] || fail "versioned release tag is not pinned"
[ "$(jq -r '.versioned_binary_assets.platform' "$VERSIONS")" = 'linux_amd64' ] || fail "versioned asset platform is not pinned"
[ "$(jq -r '.versioned_binary_assets.checksums_sha256' "$VERSIONS")" = '912eb2bdc23e715ba3b581ee418f4e572c52407f391c7282bb839ec151a129b3' ] || fail "v1.7.0 CHECKSUMS.txt digest is not pinned"
[ "$(jq -r '.versioned_binary_assets.gnoland.sha256' "$VERSIONS")" = '5e5525d53eabe65e6016d0669f5c7569a029c3ff6099105e0e5b7b7e0e461b51' ] || fail "v1.7.0 gnoland digest is not pinned"
[ "$(jq -r '.versioned_binary_assets.gnoland.reported_version' "$VERSIONS")" = 'v1.7.0' ] || fail "v1.7.0 gnoland identity is not pinned"
[ "$(jq -r '.versioned_binary_assets.gnokey.sha256' "$VERSIONS")" = '8cfe6bc58cbd010c8077e48a6eb18d0045e8f56289fe2b38eb699957a9bb9a0e' ] || fail "v1.7.0 gnokey digest is not pinned"
[ "$(jq -r '.versioned_binary_assets.gnokey.reported_version' "$VERSIONS")" = 'v1.7.0' ] || fail "v1.7.0 gnokey identity is not pinned"

grep -Fq -- '--expect-sha256' "$CHECK" || fail "release identity helper does not expose digest verification"
grep -Fq "version = \"develop\"" "$CHECK" && fail "check must inspect the binary rather than hard-code the launch version"

printf '%s\n' 'RELEASE_IDENTITY_TEST_OK'
