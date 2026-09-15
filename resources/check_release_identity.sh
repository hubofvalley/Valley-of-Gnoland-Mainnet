#!/bin/bash
set -euo pipefail

BINARY=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
EXPECTED_VERSION=""
JSON_MODE=false

usage() {
    cat <<'EOF'
Baconvalley Gnoland release identity preflight

Usage:
  check_release_identity.sh [--binary PATH] [--expect VERSION] [--json]

This check is read-only. It verifies that a Gnoland binary exposes an explicit
release identity before that artifact is considered for a coordinated upgrade.
It does not prove consensus compatibility or replace the network's reviewed
halt/restart procedure.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --binary)
            [ "$#" -ge 2 ] || { echo "--binary requires a path" >&2; exit 2; }
            BINARY=$2
            shift 2
            ;;
        --expect)
            [ "$#" -ge 2 ] || { echo "--expect requires a version" >&2; exit 2; }
            EXPECTED_VERSION=$2
            shift 2
            ;;
        --json)
            JSON_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

emit() {
    local status=$1 version=$2 reason=$3
    if $JSON_MODE; then
        jq -cn \
            --arg status "$status" \
            --arg binary "$BINARY" \
            --arg version "$version" \
            --arg expected_version "$EXPECTED_VERSION" \
            --arg reason "$reason" \
            '{status:$status,binary:$binary,version:$version,expected_version:$expected_version,reason:$reason}'
    else
        printf 'Release identity: %s\n' "$status"
        printf 'Binary: %s\n' "$BINARY"
        printf 'Reported version: %s\n' "${version:-unavailable}"
        [ -z "$EXPECTED_VERSION" ] || printf 'Expected version: %s\n' "$EXPECTED_VERSION"
        printf 'Reason: %s\n' "$reason"
    fi
}

if [ ! -x "$BINARY" ]; then
    emit "ERROR" "" "binary is missing or not executable"
    exit 2
fi

set +e
version_output=$("$BINARY" version 2>&1)
version_rc=$?
set -e
if [ "$version_rc" -ne 0 ]; then
    emit "ERROR" "" "binary version command failed"
    exit 2
fi

version=$(printf '%s\n' "$version_output" | awk '$1 == "gnoland" && $2 == "version:" {print $3; exit}')
if [ -z "$version" ]; then
    emit "ERROR" "" "could not parse 'gnoland version: <value>' from the binary"
    exit 2
fi

if [ "$version" = "develop" ]; then
    emit "BLOCKED" "$version" "the binary reports 'develop'; that identity is not suitable evidence for a version-gated coordinated upgrade"
    exit 1
fi

if [ -n "$EXPECTED_VERSION" ] && [ "$version" != "$EXPECTED_VERSION" ]; then
    emit "BLOCKED" "$version" "the binary does not report the exact reviewed release version"
    exit 1
fi

emit "IDENTIFIED" "$version" "the binary exposes an explicit release identity; consensus compatibility and halt/version-gate semantics still require separate review"
exit 0
