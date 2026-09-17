#!/bin/bash

set -u -o pipefail

readonly EXPECTED_CHAIN_ID="gnoland-1"
readonly EXPECTED_SOURCE_BRANCH="chain/mainnet"
readonly EXPECTED_SOURCE_COMMIT="31b6650a100d9baf14e7669f8f0df924f1f841e0"
readonly EXPECTED_RELEASE_TAG="chain/mainnet"
readonly EXPECTED_RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"
readonly EXPECTED_GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"
readonly EXPECTED_GNOLAND_SHA256="aa22a26823924642481fe7fc5e98eb9f42399b337f7afdac635d91403117db28"
readonly EXPECTED_GNOKEY_SHA256="38018492bcaa4de2f146d0566daf6507d9e811ee28547b963a015f51f9b14511"
readonly EXPECTED_PERSISTENT_PEERS="g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656"
readonly EXPECTED_DEPLOYMENT_PATH="misc/deployments/mainnet.gno.land"
readonly ACTIVE_VALIDATOR_REALM="r/sys/validators/v0"
readonly PUBLIC_RPC="https://rpc.gno.land"

if [ -n "${GNOLAND_NODE_DOCTOR_REF:-}" ] && [[ ! "${GNOLAND_NODE_DOCTOR_REF}" =~ ^[0-9a-f]{40}$ ]]; then
    echo "Node Doctor loader failed: GNOLAND_NODE_DOCTOR_REF must be a full 40-character Git commit SHA." >&2
    exit 2
fi

if [ "${1:-}" = "--version" ]; then
    echo "Valley of Gnoland Node Doctor (gnoland-1) 1.2.0"
    exit 0
fi

JSON_MODE=false
STRICT_MODE=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --strict) STRICT_MODE=true ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

profile_value() {
    local name=$1 default=$2 value=""
    if [ -f "$HOME/.bash_profile" ]; then
        value=$(sed -n "s/^export ${name}=\"\(.*\)\"$/\1/p" "$HOME/.bash_profile" | tail -n 1)
    fi
    printf '%s\n' "${value:-$default}"
}

GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$(profile_value GNO_SOURCE_DIR "$HOME/gno")}
GNOLAND_DEPLOYMENT_DIR=${GNOLAND_DEPLOYMENT_DIR:-$(profile_value GNOLAND_DEPLOYMENT_DIR "$GNO_SOURCE_DIR/$EXPECTED_DEPLOYMENT_PATH")}
GNOLAND_MAINNET_HOME=${GNOLAND_MAINNET_HOME:-$(profile_value GNOLAND_MAINNET_HOME "$GNO_SOURCE_DIR/gnoland-data")}
GNOLAND_GENESIS=${GNOLAND_GENESIS:-$(profile_value GNOLAND_GENESIS "$GNOLAND_DEPLOYMENT_DIR/genesis.json")}
GNOLAND_MAINNET_SERVICE_NAME=${GNOLAND_MAINNET_SERVICE_NAME:-$(profile_value GNOLAND_MAINNET_SERVICE_NAME "gnoland")}
GNOLAND_MAINNET_SERVICE_NAME=${GNOLAND_MAINNET_SERVICE_NAME%.service}
GNOLAND_REMOTE=${GNOLAND_REMOTE:-$(profile_value GNOLAND_REMOTE "http://127.0.0.1:26657")}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
CONFIG_FILE="$GNOLAND_MAINNET_HOME/config/config.toml"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
RESULTS=()

record() {
    local level=$1 code=$2 message=$3
    RESULTS+=("$level|$code|$message")
    case "$level" in
        PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    esac
}

check_binary() {
    local label=$1 path=$2 expected=$3 observed
    if [ ! -x "$path" ]; then
        record FAIL "$label" "$path is missing or not executable"
        return
    fi
    observed=$(sha256sum "$path" 2>/dev/null | awk '{print $1}')
    if [ "$observed" = "$expected" ]; then
        record PASS "$label" "$path matches the official Linux amd64 mainnet asset hash"
    else
        record FAIL "$label" "$path hash is ${observed:-unreadable}; expected $expected"
    fi
}

check_binary gnoland_binary "$GNOLAND_BIN" "$EXPECTED_GNOLAND_SHA256"
check_binary gnokey_binary "$GNOKEY_BIN" "$EXPECTED_GNOKEY_SHA256"

if [ -d "$GNO_SOURCE_DIR/.git" ]; then
    source_commit=$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD 2>/dev/null || true)
    if [ "$source_commit" = "$EXPECTED_SOURCE_COMMIT" ]; then
        record PASS source_commit "source checkout matches $EXPECTED_SOURCE_BRANCH@$EXPECTED_SOURCE_COMMIT"
    else
        record FAIL source_commit "source checkout is ${source_commit:-unreadable}; expected $EXPECTED_SOURCE_COMMIT"
    fi
    if [ -d "$GNOLAND_DEPLOYMENT_DIR" ] && [[ "$GNOLAND_DEPLOYMENT_DIR" == *"/$EXPECTED_DEPLOYMENT_PATH" ]]; then
        record PASS deployment_path "mainnet deployment path is $GNOLAND_DEPLOYMENT_DIR"
    else
        record FAIL deployment_path "mainnet deployment path is missing or unexpected: $GNOLAND_DEPLOYMENT_DIR"
    fi
else
    record FAIL source_commit "Gno source checkout is missing at $GNO_SOURCE_DIR"
    record FAIL deployment_path "mainnet deployment path is unavailable because the source checkout is missing"
fi

if [ -f "$GNOLAND_GENESIS" ]; then
    genesis_sha=$(sha256sum "$GNOLAND_GENESIS" 2>/dev/null | awk '{print $1}')
    if [ "$genesis_sha" = "$EXPECTED_GENESIS_SHA256" ]; then
        record PASS genesis "mainnet genesis checksum matches the official release"
    else
        record FAIL genesis "genesis checksum is ${genesis_sha:-unreadable}; expected $EXPECTED_GENESIS_SHA256"
    fi
else
    record FAIL genesis "mainnet genesis is missing at $GNOLAND_GENESIS"
fi

if [ -f "$CONFIG_FILE" ]; then
    if grep -Fq "persistent_peers = \"$EXPECTED_PERSISTENT_PEERS\"" "$CONFIG_FILE"; then
        record PASS peers "both official mainnet persistent peers are configured"
    else
        record WARN peers "persistent peers differ from the official mainnet seed list"
    fi
else
    record FAIL config "config.toml is missing at $CONFIG_FILE"
fi

service_file=$(systemctl show "$GNOLAND_MAINNET_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
if [ -n "$service_file" ] && [ -f "$service_file" ]; then
    if grep -Fq -- "--chainid $EXPECTED_CHAIN_ID" "$service_file" && \
        grep -Fq -- "--genesis $GNOLAND_GENESIS" "$service_file" && \
        grep -Fq -- "--skip-genesis-sig-verification" "$service_file"; then
        record PASS service_chain "systemd starts $EXPECTED_CHAIN_ID with the verified mainnet genesis"
    else
        record FAIL service_chain "systemd unit does not contain the expected mainnet startup flags"
    fi
else
    record FAIL service "systemd unit for ${GNOLAND_MAINNET_SERVICE_NAME}.service was not found"
fi

local_status=$(curl -m 5 -fsS "${GNOLAND_REMOTE%/}/status" 2>/dev/null || true)
local_network=$(printf '%s' "$local_status" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
local_height=$(printf '%s' "$local_status" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null || true)
local_catching_up=$(printf '%s' "$local_status" | jq -r '.result.sync_info.catching_up // empty' 2>/dev/null || true)
if [ "$local_network" = "$EXPECTED_CHAIN_ID" ]; then
    record PASS local_rpc "local RPC reports $EXPECTED_CHAIN_ID"
elif [ -n "$local_network" ]; then
    record FAIL local_rpc "local RPC reports $local_network, expected $EXPECTED_CHAIN_ID"
else
    record WARN local_rpc "local RPC is not reachable at $GNOLAND_REMOTE"
fi

if [ "$local_network" = "$EXPECTED_CHAIN_ID" ]; then
    case "$local_catching_up" in
        false)
            record PASS local_sync "local RPC reports catching_up=false at height ${local_height:-unknown}"
            ;;
        true)
            record WARN local_sync "local RPC reports catching_up=true at height ${local_height:-unknown}"
            ;;
        *)
            record WARN local_sync "local RPC did not expose a valid catching_up state"
            ;;
    esac
fi

local_net_info=$(curl -m 5 -fsS "${GNOLAND_REMOTE%/}/net_info" 2>/dev/null || true)
local_peer_count=$(printf '%s' "$local_net_info" | jq -r '.result.n_peers // empty' 2>/dev/null || true)
if [[ "$local_peer_count" =~ ^[0-9]+$ ]]; then
    if [ "$local_peer_count" -gt 0 ]; then
        record PASS live_peers "local node reports $local_peer_count live peer(s)"
    else
        record WARN live_peers "local node reports zero live peers"
    fi
else
    record WARN live_peers "local live peer count is unavailable from $GNOLAND_REMOTE/net_info"
fi

public_status=$(curl -m 5 -fsS "$PUBLIC_RPC/status" 2>/dev/null || true)
public_network=$(printf '%s' "$public_status" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
public_height=$(printf '%s' "$public_status" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null || true)
if [ "$public_network" = "$EXPECTED_CHAIN_ID" ]; then
    record PASS public_rpc "official comparison RPC reports $EXPECTED_CHAIN_ID"
elif [ -n "$public_network" ]; then
    record WARN public_rpc "official comparison RPC reports $public_network"
else
    record WARN public_rpc "official comparison RPC was unavailable"
fi

if [ "$local_network" = "$EXPECTED_CHAIN_ID" ] && [ "$public_network" = "$EXPECTED_CHAIN_ID" ]; then
    if [[ "$local_height" =~ ^[0-9]+$ ]] && [[ "$public_height" =~ ^[0-9]+$ ]]; then
        local_height_num=$((10#$local_height))
        public_height_num=$((10#$public_height))
        if [ "$public_height_num" -ge "$local_height_num" ]; then
            height_gap=$((public_height_num - local_height_num))
            record PASS height_gap "comparison RPC is $height_gap block(s) ahead of local node (local $local_height, comparison $public_height); observation only, no healthy-gap threshold is asserted"
        else
            height_gap=$((local_height_num - public_height_num))
            record PASS height_gap "local node is $height_gap block(s) ahead of comparison RPC (local $local_height, comparison $public_height); observation only, no healthy-gap threshold is asserted"
        fi
    else
        record WARN height_gap "local/comparison heights could not be compared; no healthy-gap threshold is asserted"
    fi
fi

if command -v timedatectl >/dev/null 2>&1; then
    ntp_state=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)
    [ "$ntp_state" = "yes" ] && record PASS time_sync "system clock reports NTP synchronized" || record WARN time_sync "NTP synchronization could not be confirmed"
fi

if [ -d "$GNOLAND_MAINNET_HOME" ]; then
    free_kb=$(df -Pk "$GNOLAND_MAINNET_HOME" 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ "$free_kb" =~ ^[0-9]+$ ]] && [ "$free_kb" -lt 20971520 ]; then
        record WARN disk "less than 20 GiB free on the node filesystem"
    else
        record PASS disk "node filesystem has at least 20 GiB free or capacity was not constrained"
    fi
fi

if $JSON_MODE; then
    printf '{"network":"%s","source_branch":"%s","source_commit":"%s","release_tag":"%s","release_commit":"%s","active_validator_realm":"%s","pass":%d,"warn":%d,"fail":%d,"results":[' \
        "$EXPECTED_CHAIN_ID" "$EXPECTED_SOURCE_BRANCH" "$EXPECTED_SOURCE_COMMIT" "$EXPECTED_RELEASE_TAG" "$EXPECTED_RELEASE_COMMIT" "$ACTIVE_VALIDATOR_REALM" "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
    first=true
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r level code message <<<"$row"
        $first || printf ','
        first=false
        jq -cn --arg level "$level" --arg code "$code" --arg message "$message" '{level:$level,code:$code,message:$message}'
    done
    printf ']}\n'
else
    echo "Valley of Gnoland Node Doctor - gnoland-1"
    echo "Expected chain: $EXPECTED_CHAIN_ID"
    echo "Pinned source: $EXPECTED_SOURCE_BRANCH@$EXPECTED_SOURCE_COMMIT"
    echo "Release tag: $EXPECTED_RELEASE_TAG ($EXPECTED_RELEASE_COMMIT)"
    echo "Active validator realm: $ACTIVE_VALIDATOR_REALM"
    echo
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r level code message <<<"$row"
        printf '[%s] %-16s %s\n' "$level" "$code" "$message"
    done
    echo
    echo "Summary: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"
fi

if [ "$FAIL_COUNT" -gt 0 ]; then exit 1; fi
if $STRICT_MODE && [ "$WARN_COUNT" -gt 0 ]; then exit 1; fi
exit 0
