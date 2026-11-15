#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { echo "P2P_BUFFER_GUARD_TEST_FAIL: $*" >&2; exit 1; }

# Exercise the real parser without running Node Doctor, RPC, or system services.
probe() {
    {
        sed -n '/^check_p2p_buffer_limits() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'record() { printf "%s|%s|%s\n" "$1" "$2" "$3"; }'
        printf '%s\n' 'check_p2p_buffer_limits "$1"'
    } | bash -s -- "$config"
}

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
config="$scratch/config.toml"
assert_result() {
    local label=$1 expected=$2 output
    output=$(probe)
    printf '%s\n' "$output" | grep -Fq "$expected" || fail "$label: expected '$expected'; got '$output'"
}

printf '[p2p]\n' > "$config"
assert_result 'old config defaults receive' 'PASS|p2p_max_recv_buffer_bytes|'
assert_result 'old config defaults send' 'PASS|p2p_max_send_buffer_bytes|'

printf '[p2p]\nmax_recv_buffer_bytes = 8454144\nmax_send_buffer_bytes = 20971520 # standard default\n' > "$config"
assert_result 'receive boundary' 'PASS|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes=8454144'
assert_result 'send above minimum' 'PASS|p2p_max_send_buffer_bytes|max_send_buffer_bytes=20971520'

printf '[p2p]\nmax_recv_buffer_bytes = 8454143\nmax_send_buffer_bytes = 1\n' > "$config"
assert_result 'receive below minimum' 'WARN|p2p_max_recv_buffer_bytes|v1.7.1 rejects max_recv_buffer_bytes=8454143'
assert_result 'send below minimum' 'WARN|p2p_max_send_buffer_bytes|v1.7.1 rejects max_send_buffer_bytes=1'

printf '[p2p]\nmax_recv_buffer_bytes = 0\nmax_send_buffer_bytes = 0\n' > "$config"
assert_result 'zero allowed but unbounded receive' 'WARN|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes=0 is accepted'
assert_result 'zero allowed but unbounded send' 'WARN|p2p_max_send_buffer_bytes|max_send_buffer_bytes=0 is accepted'

printf '[rpc]\nmax_recv_buffer_bytes = 2\n[p2p]\n# max_send_buffer_bytes = 1\n' > "$config"
assert_result 'ignore wrong section' 'PASS|p2p_max_recv_buffer_bytes|'
assert_result 'ignore comment' 'PASS|p2p_max_send_buffer_bytes|'

printf '[p2p]\nmax_recv_buffer_bytes = "8454144"\nmax_send_buffer_bytes = 3 # unsafe\n' > "$config"
assert_result 'quoted string unverified' 'WARN|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes cannot be verified'
assert_result 'inline comment low send' 'WARN|p2p_max_send_buffer_bytes|v1.7.1 rejects max_send_buffer_bytes=3'

printf '[p2p]\nmax_recv_buffer_bytes = 20971520\nmax_recv_buffer_bytes = 20971520\n' > "$config"
assert_result 'duplicate key unverified' 'WARN|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes cannot be verified'

printf '[p2p]\nmax_send_buffer_bytes = 20971520\n[p2p]\n' > "$config"
assert_result 'duplicate section unverified' 'WARN|p2p_max_send_buffer_bytes|max_send_buffer_bytes cannot be verified'

printf '[rpc]\nmax_send_buffer_bytes = 20971520\n' > "$config"
assert_result 'no p2p section unverified' 'WARN|p2p_max_send_buffer_bytes|max_send_buffer_bytes cannot be verified'

printf '[p2p]\nmax_send_buffer_bytes = 9223372036854775808\nmax_recv_buffer_bytes = -1\n' > "$config"
assert_result 'too large to verify' 'WARN|p2p_max_send_buffer_bytes|max_send_buffer_bytes cannot be verified'
assert_result 'negative rejected' 'WARN|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes cannot be verified'

printf '[p2p]\nmax_send_buffer_bytes = 08454144\nmax_recv_buffer_bytes = 8454144 junk\n' > "$config"
assert_result 'leading zero unverified' 'WARN|p2p_max_send_buffer_bytes|max_send_buffer_bytes cannot be verified'
assert_result 'junk unverified' 'WARN|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes cannot be verified'

printf '%s\n' 'P2P_BUFFER_GUARD_TEST_OK'
