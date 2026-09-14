#!/bin/bash

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'
CURRENT_STAGE="startup"

on_error() {
    local exit_code=$?
    local line_number=${1:-unknown}
    local failed_command=${2:-unknown}
    trap - ERR
    echo -e "${RED}Gno.land gnoland-1 installation failed.${RESET}" >&2
    echo "Stage: $CURRENT_STAGE" >&2
    echo "Line: $line_number" >&2
    echo "Command: $failed_command" >&2
    echo "Exit code: $exit_code" >&2
    echo "No success status was reported. Review the error above before retrying." >&2
    exit "$exit_code"
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

readonly CHAIN_ID="gnoland-1"
readonly SOURCE_BRANCH="chain/mainnet"
readonly SOURCE_COMMIT="31b6650a100d9baf14e7669f8f0df924f1f841e0"
readonly RELEASE_TAG="chain/mainnet"
readonly RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"
readonly RELEASE_ASSET_BASE_URL="https://github.com/gnolang/gno/releases/download/chain/mainnet"
readonly GENESIS_URL="https://github.com/gnolang/gno/releases/download/chain/mainnet/genesis.json"
readonly GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"
readonly GNOLAND_ASSET="gnoland_linux_amd64"
readonly GNOLAND_ASSET_SHA256="aa22a26823924642481fe7fc5e98eb9f42399b337f7afdac635d91403117db28"
readonly GNOKEY_ASSET="gnokey_linux_amd64"
readonly GNOKEY_ASSET_SHA256="38018492bcaa4de2f146d0566daf6507d9e811ee28547b963a015f51f9b14511"
readonly OFFICIAL_GNOLAND_PEERS="g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656"
readonly PUBLIC_RPC="https://rpc.gno.land"

GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOLAND_DEPLOYMENT_DIR=${GNOLAND_DEPLOYMENT_DIR:-$GNO_SOURCE_DIR/misc/deployments/mainnet.gno.land}
GNOLAND_HOME=${GNOLAND_HOME:-$GNO_SOURCE_DIR/gnoland-data}
GNOKEY_HOME=${GNOKEY_HOME:-$HOME/.config/gno}
GENESIS_FILE=${GNOLAND_GENESIS:-$GNOLAND_DEPLOYMENT_DIR/genesis.json}
if [ "$(realpath -m "$GENESIS_FILE")" != "$(realpath -m "$GNOLAND_DEPLOYMENT_DIR/genesis.json")" ]; then
    echo -e "${RED}Mainnet genesis must be stored under $GNOLAND_DEPLOYMENT_DIR.${RESET}" >&2
    false
fi
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
OS_USER=$(id -un)

if [ -n "${SUDO_USER:-}" ]; then
    echo -e "${RED}Run Valley of Gnoland as the node OS user, not with sudo.${RESET}" >&2
    echo "The installer requests sudo only for packages, firewall, and systemd." >&2
    false
fi

path_is_under_home() {
    local canonical_home canonical_path
    canonical_home=$(realpath -m "$HOME")
    canonical_path=$(realpath -m "$1")
    case "$canonical_path" in
        "$canonical_home"/*) return 0 ;;
        *) return 1 ;;
    esac
}

for instance_path in "$GNO_SOURCE_DIR" "$GNOLAND_DEPLOYMENT_DIR" "$GNOLAND_HOME" "$GNOKEY_HOME" "$GNOLAND_BIN" "$GNOKEY_BIN" "$GENESIS_FILE"; do
    if ! path_is_under_home "$instance_path"; then
        echo -e "${RED}Unsafe instance path outside $HOME: $instance_path${RESET}" >&2
        false
    fi
done

echo -e "\n--- Gno.land gnoland-1 Node Setup ---"
echo -e "${YELLOW}Installation and updates use the pinned ${SOURCE_BRANCH} source and verified release assets.${RESET}"
echo "Linux amd64 gnoland and gnokey assets are checked against their official SHA-256 values."
echo "  Source / GNOROOT: $GNO_SOURCE_DIR"
echo "  Mainnet deployment: $GNOLAND_DEPLOYMENT_DIR"
echo "  Node data:        $GNOLAND_HOME"
echo "  Operator keyring: $GNOKEY_HOME"
echo "  Network:          $CHAIN_ID"
echo "  Source commit:    $SOURCE_COMMIT"
echo "  Release tag:      $RELEASE_TAG ($RELEASE_COMMIT)"
echo "  Service:          gnoland.service (default)"

after_prompt() {
    :
}

while :; do
    read -r -p "Enter your GNOLAND_MONIKER: " GNOLAND_MONIKER
    [ -n "$GNOLAND_MONIKER" ] && break
    echo -e "${RED}Moniker is required. Please try again.${RESET}"
done

while :; do
    read -r -p "Enter preferred port prefix (leave empty for default 26): " GNOLAND_PORT
    GNOLAND_PORT=${GNOLAND_PORT:-26}
    if [[ "$GNOLAND_PORT" =~ ^[0-9]{2}$ ]] && [ "$((10#$GNOLAND_PORT))" -ge 1 ] && [ "$((10#$GNOLAND_PORT))" -le 64 ]; then
        break
    fi
    echo -e "${RED}Port prefix must be two digits from 01 through 64, for example 26 or 36.${RESET}"
done

read -r -p "Enter public external address host/IP for P2P (optional): " GNOLAND_EXTERNAL_HOST
read -r -p "Configure UFW firewall rules for Gnoland? (y/n, default n): " SETUP_UFW
SETUP_UFW=${SETUP_UFW:-n}

while :; do
    if [ -z "${GNOLAND_SERVICE_NAME:-}" ]; then
        read -r -p "Enter service name (default 'gnoland'): " GNOLAND_SERVICE_NAME
        GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-gnoland}
    fi
    GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME%.service}
    if [[ "$GNOLAND_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then break; fi
    echo -e "${RED}Service name must start with a letter or number and may contain _, ., @, and -.${RESET}"
    GNOLAND_SERVICE_NAME=""
done

SERVICE_FILE="/etc/systemd/system/${GNOLAND_SERVICE_NAME}.service"
GNOLAND_RPC_PORT="${GNOLAND_PORT}657"
GNOLAND_P2P_PORT="${GNOLAND_PORT}656"
GNOLAND_ABCI_PORT="${GNOLAND_PORT}658"
BACKUP_ROOT="$HOME/gnoland-backups"
BACKUP_STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_STAMP"

service_belongs_to_instance() {
    local unit_user unit_workdir resolved_service_file
    resolved_service_file=$(systemctl show "$GNOLAND_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
    [ -n "$resolved_service_file" ] || return 0
    if [ ! -f "$resolved_service_file" ]; then
        echo -e "${RED}Cannot inspect existing service: $resolved_service_file${RESET}" >&2
        return 1
    fi
    unit_user=$(sed -n 's/^User=//p' "$resolved_service_file" | tail -n 1)
    unit_workdir=$(sed -n 's/^WorkingDirectory=//p' "$resolved_service_file" | tail -n 1)
    if [ "$unit_user" != "$OS_USER" ] || [ "$unit_workdir" != "$GNO_SOURCE_DIR" ]; then
        echo -e "${RED}${GNOLAND_SERVICE_NAME}.service belongs to another instance.${RESET}" >&2
        echo "Existing User=${unit_user:-unknown}, WorkingDirectory=${unit_workdir:-unknown}" >&2
        echo "Requested User=$OS_USER, WorkingDirectory=$GNO_SOURCE_DIR" >&2
        return 1
    fi
}

port_is_free() {
    local port=$1
    ! ss -H -ltn "sport = :$port" 2>/dev/null | grep -q .
}

if ! command -v ss >/dev/null 2>&1; then
    echo -e "${RED}Required port-inspection command 'ss' is unavailable.${RESET}" >&2
    false
fi
service_belongs_to_instance

if [ -z "$(systemctl show "$GNOLAND_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)" ]; then
    while ! port_is_free "$GNOLAND_P2P_PORT" || ! port_is_free "$GNOLAND_RPC_PORT" || ! port_is_free "$GNOLAND_ABCI_PORT"; do
        echo -e "${RED}Port prefix $GNOLAND_PORT conflicts with a running listener.${RESET}"
        read -r -p "Enter another two-digit port prefix: " GNOLAND_PORT
        if [[ ! "$GNOLAND_PORT" =~ ^[0-9]{2}$ ]] || [ "$((10#$GNOLAND_PORT))" -lt 1 ] || [ "$((10#$GNOLAND_PORT))" -gt 64 ]; then
            echo -e "${RED}Port prefix must be two digits from 01 through 64, for example 26 or 36.${RESET}"
            continue
        fi
        GNOLAND_RPC_PORT="${GNOLAND_PORT}657"
        GNOLAND_P2P_PORT="${GNOLAND_PORT}656"
        GNOLAND_ABCI_PORT="${GNOLAND_PORT}658"
    done
fi

echo
echo -e "${YELLOW}Operator key choice:${RESET}"
echo "1. Reuse an existing local operator key"
echo "2. Recover an operator key from its mnemonic"
echo "3. Create a new operator key"
while :; do
    read -r -p "Choose 1, 2, or 3: " OPERATOR_KEY_ACTION
    [[ "$OPERATOR_KEY_ACTION" =~ ^[123]$ ]] && break
    echo -e "${RED}Invalid operator key choice. Please try again.${RESET}"
done

echo
echo -e "${YELLOW}Installation preview:${RESET}"
echo "  Network:          $CHAIN_ID"
echo "  Release:          $RELEASE_TAG ($RELEASE_COMMIT)"
echo "  OS user:          $OS_USER"
echo "  Service:          ${GNOLAND_SERVICE_NAME}.service"
echo "  Binary directory: $HOME/go/bin"
echo "  Source / GNOROOT: $GNO_SOURCE_DIR"
echo "  Node data:        $GNOLAND_HOME"
echo "  Operator keyring: $GNOKEY_HOME"
echo "  P2P/RPC/ABCI:     $GNOLAND_P2P_PORT / $GNOLAND_RPC_PORT / $GNOLAND_ABCI_PORT"
echo
echo -e "${YELLOW}This replaces Valley node data under $GNOLAND_HOME after the backup step.${RESET}"
echo "The local keyring at $GNOKEY_HOME is preserved."
read -r -p "Type INSTALL-GNOLAND-1 to continue: " CONFIRM
if [ "$CONFIRM" != "INSTALL-GNOLAND-1" ]; then
    echo "Installation cancelled."
    exit 0
fi

# A reinstall is destructive. Never replace an unknown existing node: only an
# explicitly configured gnoland-1 service may be replaced by this path.
EXISTING_SERVICE_FILE=$(systemctl show "$GNOLAND_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
EXISTING_NODE_STATE=""
if [ -d "$GNOLAND_HOME" ]; then
    EXISTING_NODE_STATE=$(find "$GNOLAND_HOME" -mindepth 1 -print -quit 2>/dev/null || true)
fi
if [ -n "$EXISTING_NODE_STATE" ] || [ -f "$GENESIS_FILE" ]; then
    if [ -z "$EXISTING_SERVICE_FILE" ] || [ ! -f "$EXISTING_SERVICE_FILE" ] || \
        ! grep -Fq -- "--chainid $CHAIN_ID" "$EXISTING_SERVICE_FILE"; then
        echo -e "${RED}Destructive reinstall refused: existing node identity is not explicitly configured for $CHAIN_ID.${RESET}" >&2
        echo "Remove or review the existing instance manually, then rerun with the correct service configuration." >&2
        false
    fi
fi

mkdir -p "$BACKUP_DIR"
CURRENT_STAGE="backup existing node secrets and keyring"
if [ -d "$GNOLAND_HOME/secrets" ]; then
    tar -czf "$BACKUP_DIR/node-secrets.tar.gz" -C "$GNOLAND_HOME" secrets
    chmod 600 "$BACKUP_DIR/node-secrets.tar.gz"
    echo -e "${GREEN}Backed up node secrets to $BACKUP_DIR/node-secrets.tar.gz${RESET}"
fi
if [ -d "$GNOKEY_HOME" ] && [ -n "$(find "$GNOKEY_HOME" -mindepth 1 -print -quit 2>/dev/null)" ]; then
    tar -czf "$BACKUP_DIR/operator-keyring.tar.gz" -C "$(dirname "$GNOKEY_HOME")" "$(basename "$GNOKEY_HOME")"
    chmod 600 "$BACKUP_DIR/operator-keyring.tar.gz"
    echo -e "${GREEN}Backed up operator keyring to $BACKUP_DIR/operator-keyring.tar.gz${RESET}"
fi

sudo systemctl stop "$GNOLAND_SERVICE_NAME" 2>/dev/null || true
if ! port_is_free "$GNOLAND_P2P_PORT" || ! port_is_free "$GNOLAND_RPC_PORT" || ! port_is_free "$GNOLAND_ABCI_PORT"; then
    echo -e "${RED}Selected ports remain occupied after stopping ${GNOLAND_SERVICE_NAME}.service.${RESET}" >&2
    false
fi
sudo systemctl disable "$GNOLAND_SERVICE_NAME" 2>/dev/null || true
sudo rm -f "$SERVICE_FILE"
rm -rf "$GNOLAND_HOME"
rm -f "$GENESIS_FILE"
sed -i '/GNOLAND_/d;/GNOKEY_/d;/GNO_SOURCE_DIR/d;/GNOROOT/d;/go\/bin/d' "$HOME/.bash_profile" 2>/dev/null || true

CURRENT_STAGE="install release prerequisites"
sudo apt update -y
sudo apt install -y curl git jq ca-certificates
if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo -e "${RED}The published mainnet assets are only verified for Linux amd64.${RESET}" >&2
    false
fi
mkdir -p "$HOME/go/bin"

CURRENT_STAGE="prepare pinned Gno source"
echo -e "${CYAN}Preparing pinned ${SOURCE_BRANCH} source at ${SOURCE_COMMIT}.${RESET}"
if [ ! -d "$GNO_SOURCE_DIR/.git" ]; then
    rm -rf "$GNO_SOURCE_DIR"
    mkdir -p "$GNO_SOURCE_DIR"
    git -C "$GNO_SOURCE_DIR" init
fi
if git -C "$GNO_SOURCE_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$GNO_SOURCE_DIR" remote set-url origin https://github.com/gnolang/gno.git
else
    git -C "$GNO_SOURCE_DIR" remote add origin https://github.com/gnolang/gno.git
fi
release_tag_commit=$(git -C "$GNO_SOURCE_DIR" ls-remote --refs origin "refs/tags/$RELEASE_TAG" | awk 'NR == 1 {print $1}' || true)
if [ "$release_tag_commit" != "$RELEASE_COMMIT" ]; then
    echo -e "${RED}The $RELEASE_TAG tag does not match the pinned release commit.${RESET}" >&2
    echo "Expected: $RELEASE_COMMIT" >&2
    echo "Observed: ${release_tag_commit:-unavailable}" >&2
    false
fi
git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "refs/heads/$SOURCE_BRANCH"
if [ "$(git -C "$GNO_SOURCE_DIR" rev-parse FETCH_HEAD)" != "$SOURCE_COMMIT" ]; then
    echo -e "${RED}The $SOURCE_BRANCH tip is not the pinned mainnet source commit.${RESET}" >&2
    echo "Expected: $SOURCE_COMMIT" >&2
    echo "Observed: $(git -C "$GNO_SOURCE_DIR" rev-parse FETCH_HEAD 2>/dev/null || echo unavailable)" >&2
    false
fi
git -C "$GNO_SOURCE_DIR" checkout --detach --force "$SOURCE_COMMIT"
if [ "$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD)" != "$SOURCE_COMMIT" ]; then
    echo -e "${RED}Unexpected Gno source commit at $GNO_SOURCE_DIR.${RESET}" >&2
    false
fi

if [ ! -d "$GNOLAND_DEPLOYMENT_DIR" ]; then
    echo -e "${RED}Mainnet deployment path is missing from the pinned source: $GNOLAND_DEPLOYMENT_DIR${RESET}" >&2
    false
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

download_verified_asset() {
    local url=$1 expected_sha=$2 output=$3 label=$4
    curl -fsSL "$url" -o "$output"
    printf '%s  %s\n' "$expected_sha" "$output" | sha256sum --check - >/dev/null
    chmod 0755 "$output"
    echo -e "${GREEN}Verified $label SHA-256: $expected_sha${RESET}"
}

CURRENT_STAGE="download and verify mainnet release assets"
download_verified_asset "$RELEASE_ASSET_BASE_URL/$GNOLAND_ASSET" "$GNOLAND_ASSET_SHA256" "$TMP_DIR/gnoland" "$GNOLAND_ASSET"
download_verified_asset "$RELEASE_ASSET_BASE_URL/$GNOKEY_ASSET" "$GNOKEY_ASSET_SHA256" "$TMP_DIR/gnokey" "$GNOKEY_ASSET"

CURRENT_STAGE="install verified mainnet binaries"
mkdir -p "$(dirname "$GNOLAND_BIN")" "$(dirname "$GNOKEY_BIN")"
install -m 0755 "$TMP_DIR/gnoland" "$GNOLAND_BIN"
install -m 0755 "$TMP_DIR/gnokey" "$GNOKEY_BIN"
if [ ! -x "$GNOLAND_BIN" ] || [ ! -x "$GNOKEY_BIN" ]; then
    echo -e "${RED}Verified mainnet assets were not installed as executable commands.${RESET}" >&2
    false
fi
printf '%s  %s\n' "$GNOLAND_ASSET_SHA256" "$GNOLAND_BIN" | sha256sum --check - >/dev/null
printf '%s  %s\n' "$GNOKEY_ASSET_SHA256" "$GNOKEY_BIN" | sha256sum --check - >/dev/null
export GNOROOT
export PATH="$HOME/go/bin:$PATH"
hash -r
if [ "$(command -v gnoland)" != "$GNOLAND_BIN" ] || [ "$(command -v gnokey)" != "$GNOKEY_BIN" ]; then
    echo -e "${RED}Per-user commands do not resolve to $HOME/go/bin.${RESET}" >&2
    false
fi
mkdir -p "$GNOKEY_HOME"

operator_key_exists() {
    "$GNOKEY_BIN" -home "$GNOKEY_HOME" list 2>/dev/null | awk -v key="$1" '$2 == key { found=1 } END { exit !found }'
}

CURRENT_STAGE="select or recover operator key"
case "$OPERATOR_KEY_ACTION" in
    1)
        echo -e "${CYAN}Existing local operator keys:${RESET}"
        LOCAL_KEYS=$("$GNOKEY_BIN" -home "$GNOKEY_HOME" list || true)
        if [ -z "$LOCAL_KEYS" ]; then
            echo -e "${RED}No readable local key found. Choose recovery or new-key installation.${RESET}"
            while :; do
                read -r -p "Choose 2 to recover or 3 for a new key: " OPERATOR_KEY_ACTION
                [[ "$OPERATOR_KEY_ACTION" =~ ^[23]$ ]] && break
                echo -e "${RED}Invalid choice. Please enter 2 or 3.${RESET}"
            done
        else
            echo "$LOCAL_KEYS"
            while :; do
                read -r -p "Type the existing key name to reuse: " OPERATOR_KEY_NAME
                if [ -n "$OPERATOR_KEY_NAME" ] && operator_key_exists "$OPERATOR_KEY_NAME"; then break; fi
                echo -e "${RED}That key was not found. Please enter an existing key name.${RESET}"
            done
        fi
        ;;
esac

case "$OPERATOR_KEY_ACTION" in
    2)
        read -r -p "Enter key name for the recovered operator (default 'operator'): " OPERATOR_KEY_NAME
        OPERATOR_KEY_NAME=${OPERATOR_KEY_NAME:-operator}
        if operator_key_exists "$OPERATOR_KEY_NAME"; then
            echo -e "${YELLOW}Key '$OPERATOR_KEY_NAME' already exists; reusing it without overwrite.${RESET}"
        else
            "$GNOKEY_BIN" -home "$GNOKEY_HOME" add -recover "$OPERATOR_KEY_NAME"
        fi
        ;;
    3)
        read -r -p "Enter new key name (default 'operator'): " OPERATOR_KEY_NAME
        OPERATOR_KEY_NAME=${OPERATOR_KEY_NAME:-operator}
        if operator_key_exists "$OPERATOR_KEY_NAME"; then
            echo -e "${YELLOW}Key '$OPERATOR_KEY_NAME' already exists; reusing it without overwrite.${RESET}"
        else
            "$GNOKEY_BIN" -home "$GNOKEY_HOME" add "$OPERATOR_KEY_NAME"
            echo -e "${RED}Store the new mnemonic offline. It will not be shown again.${RESET}"
        fi
        ;;
esac

if [ -z "${OPERATOR_KEY_NAME:-}" ]; then
    echo -e "${RED}No operator key was selected.${RESET}" >&2
    false
fi
echo -e "${GREEN}Operator key selected: $OPERATOR_KEY_NAME${RESET}"
"$GNOKEY_BIN" -home "$GNOKEY_HOME" list

cd "$GNO_SOURCE_DIR"
CURRENT_STAGE="initialise gnoland config and node secrets"
CONFIG_FILE="$GNOLAND_HOME/config/config.toml"
"$GNOLAND_BIN" config init -force --config-path "$CONFIG_FILE"
"$GNOLAND_BIN" secrets init -force --data-dir "$GNOLAND_HOME/secrets"

CURRENT_STAGE="download and verify release genesis"
mkdir -p "$GNOLAND_DEPLOYMENT_DIR"
curl -fsSL "$GENESIS_URL" -o "$GENESIS_FILE"
printf '%s  %s\n' "$GENESIS_SHA256" "$GENESIS_FILE" | sha256sum --check -
echo -e "${GREEN}Verified mainnet genesis SHA-256: $GENESIS_SHA256${RESET}"

CURRENT_STAGE="apply gnoland-1 configuration"
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" moniker "$GNOLAND_MONIKER"
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" proxy_app "tcp://127.0.0.1:${GNOLAND_ABCI_PORT}"
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" p2p.laddr "tcp://0.0.0.0:${GNOLAND_P2P_PORT}"
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" rpc.laddr "tcp://127.0.0.1:${GNOLAND_RPC_PORT}"
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" p2p.seeds ""
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" p2p.persistent_peers "$OFFICIAL_GNOLAND_PEERS"
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" p2p.pex true
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" application.prune_strategy syncable
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" consensus.timeout_commit 3s
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" consensus.peer_gossip_sleep_duration 10ms
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" p2p.flush_throttle_timeout 10ms
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" mempool.size 10000
"$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" p2p.max_num_outbound_peers 40
if [ -n "$GNOLAND_EXTERNAL_HOST" ]; then
    "$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" p2p.external_address "${GNOLAND_EXTERNAL_HOST}:${GNOLAND_P2P_PORT}"
fi

if [[ "$SETUP_UFW" =~ ^[Yy]$ ]]; then
    sudo apt install -y ufw
    sudo ufw allow 22/tcp comment "SSH Access"
    sudo ufw allow "${GNOLAND_P2P_PORT}/tcp" comment "Gno.land gnoland-1 P2P"
    sudo ufw --force enable
    sudo ufw status verbose
fi

sudo tee "$SERVICE_FILE" >/dev/null <<EOF_SERVICE
[Unit]
Description=Gno.land gnoland-1 Node (${GNOLAND_SERVICE_NAME})
After=network-online.target

[Service]
User=$OS_USER
WorkingDirectory=$GNO_SOURCE_DIR
Environment=GNOROOT=$GNOROOT
Environment=PATH=$HOME/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$GNOLAND_BIN start --chainid $CHAIN_ID --genesis $GENESIS_FILE --data-dir $GNOLAND_HOME --gnoroot-dir $GNOROOT --skip-genesis-sig-verification --log-level info
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
LimitNPROC=65536

[Install]
WantedBy=multi-user.target
EOF_SERVICE

{
    echo "export GNOLAND_MONIKER=\"$GNOLAND_MONIKER\""
    echo "export GNOLAND_CHAIN_ID=\"$CHAIN_ID\""
    echo "export GNOLAND_PORT=\"$GNOLAND_PORT\""
    echo "export GNOLAND_HOME=\"$GNOLAND_HOME\""
    echo "export GNOLAND_DEPLOYMENT_DIR=\"$GNOLAND_DEPLOYMENT_DIR\""
    echo "export GNOLAND_GENESIS=\"$GENESIS_FILE\""
    echo "export GNOKEY_HOME=\"$GNOKEY_HOME\""
    echo "export GNOLAND_OPERATOR_KEY=\"$OPERATOR_KEY_NAME\""
    echo "export GNO_SOURCE_DIR=\"$GNO_SOURCE_DIR\""
    echo "export GNOROOT=\"$GNOROOT\""
    echo 'export PATH="$HOME/go/bin:$PATH"'
    echo "export GNOLAND_SERVICE_NAME=\"$GNOLAND_SERVICE_NAME\""
    echo "export GNOLAND_REMOTE=\"http://127.0.0.1:${GNOLAND_RPC_PORT}\""
    echo "export GNOLAND_PUBLIC_REMOTE=\"$PUBLIC_RPC\""
} >> "$HOME/.bash_profile"

sudo systemctl daemon-reload
CURRENT_STAGE="start gnoland-1 service"
sudo systemctl enable "$GNOLAND_SERVICE_NAME"
sudo systemctl restart "$GNOLAND_SERVICE_NAME"

echo -e "${CYAN}Waiting for the gnoland-1 RPC startup check (up to 90 seconds).${RESET}"
RPC_STATUS=""
for _ in $(seq 1 90); do
    if ! systemctl is-active --quiet "$GNOLAND_SERVICE_NAME"; then break; fi
    RPC_STATUS=$(curl -fsS "http://127.0.0.1:${GNOLAND_RPC_PORT}/status" 2>/dev/null || true)
    if [ -n "$RPC_STATUS" ]; then break; fi
    sleep 1
done

RPC_NETWORK=$(printf '%s' "$RPC_STATUS" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
CONFIG_FILE="$GNOLAND_HOME/config/config.toml"
CONFIG_ABCI_PORT=$(sed -n 's/^proxy_app = "tcp:\/\/127\.0\.0\.1:\([0-9][0-9]*\)"$/\1/p' "$CONFIG_FILE")
CONFIG_P2P_PORT=$(awk -F: '/^[[:space:]]*\[p2p\][[:space:]]*$/ {in_p2p=1; next} /^[[:space:]]*\[/ {in_p2p=0} in_p2p && /^[[:space:]]*laddr = "tcp:\/\// {gsub(/".*/, "", $NF); print $NF; exit}' "$CONFIG_FILE")
CONFIG_RPC_PORT=$(awk -F: '/^[[:space:]]*\[rpc\][[:space:]]*$/ {in_rpc=1; next} /^[[:space:]]*\[/ {in_rpc=0} in_rpc && /^[[:space:]]*laddr = "tcp:\/\// {gsub(/".*/, "", $NF); print $NF; exit}' "$CONFIG_FILE")

if systemctl is-active --quiet "$GNOLAND_SERVICE_NAME" && [ "$RPC_NETWORK" = "$CHAIN_ID" ] && [ "$CONFIG_ABCI_PORT" = "$GNOLAND_ABCI_PORT" ] && [ "$CONFIG_P2P_PORT" = "$GNOLAND_P2P_PORT" ] && [ "$CONFIG_RPC_PORT" = "$GNOLAND_RPC_PORT" ]; then
    echo -e "${GREEN}Gnoland service started successfully.${RESET}"
    echo "Verified RPC network: $RPC_NETWORK"
    echo "Verified local ports: ABCI $CONFIG_ABCI_PORT, P2P $CONFIG_P2P_PORT, RPC $CONFIG_RPC_PORT"
    echo "Local status: curl -fsSL http://127.0.0.1:${GNOLAND_RPC_PORT}/status | jq '.result.sync_info'"
    echo "Backups created under: $BACKUP_DIR"
else
    echo -e "${RED}Gnoland failed the gnoland-1 RPC startup check.${RESET}"
    echo "Expected RPC network: $CHAIN_ID"
    echo "Observed RPC network: ${RPC_NETWORK:-unavailable}"
    echo "Expected local ports: ABCI $GNOLAND_ABCI_PORT, P2P $GNOLAND_P2P_PORT, RPC $GNOLAND_RPC_PORT"
    echo "Observed local ports: ABCI ${CONFIG_ABCI_PORT:-unavailable}, P2P ${CONFIG_P2P_PORT:-unavailable}, RPC ${CONFIG_RPC_PORT:-unavailable}"
    sudo systemctl status "$GNOLAND_SERVICE_NAME" --no-pager -l || true
    sudo journalctl -u "$GNOLAND_SERVICE_NAME" -n 100 --no-pager || true
    false
fi

CURRENT_STAGE="complete"
echo "Let's Buidl Gnoland Together"
