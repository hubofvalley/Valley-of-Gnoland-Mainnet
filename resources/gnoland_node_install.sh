#!/bin/bash

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'
CURRENT_STAGE="startup"
CUTOVER_STARTED=false
ROLLBACK_COMPLETE=false
SERVICE_WAS_ACTIVE=false
TMP_DIR=""
ROLLBACK_ROOT=""
OLD_SOURCE_PRESENT=false
OLD_EXTERNAL_NODE_PRESENT=false
OLD_SERVICE_PRESENT=false
OLD_PROFILE_PRESENT=false
OLD_GNO_PRESENT=false
OLD_GNOLAND_PRESENT=false
OLD_GNOKEY_PRESENT=false
NODE_HOME_INSIDE_SOURCE=false
SOURCE_CUTOVER_ATTEMPTED=false
EXTERNAL_NODE_RUNTIME_STARTED=false

readonly CHAIN_ID="gnoland-1"
readonly SOURCE_BRANCH="chain/mainnet"
readonly SOURCE_COMMIT="e75fef82c02876a4df92ad6e325c5479b9532168"
readonly RELEASE_TAG="chain/mainnet"
readonly RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"
readonly RELEASE_API_URL="https://api.github.com/repos/gnolang/gno/releases/tags/chain%2Fmainnet"
readonly GENESIS_GZ_URL="https://github.com/gnolang/gno/releases/download/chain/mainnet/genesis.json.gz"
readonly GENESIS_GZ_SHA256="32a0fef8db3c71fa8360dee39a0149ee961be115ba81363a15f854e4aad446c9"
readonly GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"
readonly OCI_REGISTRY="ghcr.io"
readonly GNO_IMAGE_REPOSITORY="gnolang/gno/gno"
readonly GNO_IMAGE_MANIFEST_DIGEST="sha256:307b3143ab53c025e9e51a0221fbed3c531517140654c91744e8de2b612fc2bc"
readonly GNO_BINARY_LAYER_DIGEST="sha256:676c5d4e100062b2caf1c629411581c6858fedd7b632c2248ca50b1c3204b5ff"
readonly GNO_BINARY_PATH="/usr/bin/gno"
readonly GNO_BIN_SHA256="423a64b605400882ac6ae016ef517b2465d64c49e71fd8d45d6d3a6ecfe0e87d"
readonly GNOLAND_IMAGE_REPOSITORY="gnolang/gno/gnoland"
readonly GNOLAND_IMAGE_MANIFEST_DIGEST="sha256:ef516db1c3de66c93d502fbcb28978d8560ec64e33b7e6a1ae6bf9fdc446f0b0"
readonly GNOLAND_BINARY_LAYER_DIGEST="sha256:b31ea46c33fd7cdb08f43975e079f5339e5f4ba672e121750a4ca6bce266ab63"
readonly GNOLAND_BINARY_PATH="/usr/bin/gnoland"
readonly GNOLAND_BIN_SHA256="5f568a5c96f9a0f9f20f5b0adbc72cc0d5c640e82bd3c7b129bb629758f029bc"
readonly GNOKEY_IMAGE_REPOSITORY="gnolang/gno/gnokey"
readonly GNOKEY_IMAGE_MANIFEST_DIGEST="sha256:6fee82874a9d0506d7cc31e86bb2c2a1fb396d5933cf7bfbb05513589de67e71"
readonly GNOKEY_BINARY_LAYER_DIGEST="sha256:fe63ba3901c28e13a488fe20efc6e3c8b3524b61f52645f5c89084a448955352"
readonly GNOKEY_BINARY_PATH="/usr/bin/gnokey"
readonly GNOKEY_BIN_SHA256="2d9f3019107403879e7b9f398deb15107945f33b91bc4ee85b938ff7f60b03cd"
readonly ASSET_VERSION="heads/chain/mainnet.3444+e75fef82c"
readonly OFFICIAL_GNOLAND_PEERS="g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656"
readonly PUBLIC_RPC="https://rpc.gno.land"
readonly PROFILE_BEGIN="# >>> GRAND VALLEY GNOLAND MAINNET >>>"
readonly PROFILE_END="# <<< GRAND VALLEY GNOLAND MAINNET <<<"

GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOLAND_DEPLOYMENT_DIR=${GNOLAND_DEPLOYMENT_DIR:-$GNO_SOURCE_DIR/misc/deployments/mainnet.gno.land}
GNOLAND_MAINNET_HOME=${GNOLAND_MAINNET_HOME:-$GNO_SOURCE_DIR/gnoland-data}
GNOKEY_HOME=${GNOKEY_HOME:-$HOME/.config/gno}
GENESIS_FILE=${GNOLAND_GENESIS:-$GNOLAND_DEPLOYMENT_DIR/genesis.json}
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNO_BIN=${GNO_BIN:-$HOME/go/bin/gno}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
OS_USER=$(id -un)

cleanup() {
    [ -z "$TMP_DIR" ] || rm -rf "$TMP_DIR"
    if ! $CUTOVER_STARTED && [ -n "$ROLLBACK_ROOT" ] && [ -d "$ROLLBACK_ROOT" ]; then
        rm -rf "$ROLLBACK_ROOT"
    fi
}
trap cleanup EXIT

rollback_install() {
    $CUTOVER_STARTED || return 0
    $ROLLBACK_COMPLETE && return 0
    ROLLBACK_COMPLETE=true
    set +e
    echo -e "${YELLOW}Installation did not pass the startup gate. Restoring the previous runtime.${RESET}" >&2
    sudo systemctl stop "$GNOLAND_MAINNET_SERVICE_NAME" >/dev/null 2>&1 || true
    sudo rm -f "$SERVICE_FILE"

    if $OLD_SOURCE_PRESENT; then
        if $SOURCE_CUTOVER_ATTEMPTED && [ -d "$GNO_SOURCE_DIR" ]; then rm -rf "$GNO_SOURCE_DIR"; fi
        if [ -d "$ROLLBACK_ROOT/source" ]; then mv "$ROLLBACK_ROOT/source" "$GNO_SOURCE_DIR" || true; fi
    elif $SOURCE_CUTOVER_ATTEMPTED && [ -d "$GNO_SOURCE_DIR" ]; then
        rm -rf "$GNO_SOURCE_DIR"
    fi
    if $OLD_EXTERNAL_NODE_PRESENT && [ -d "$ROLLBACK_ROOT/node-data" ]; then
        if $EXTERNAL_NODE_RUNTIME_STARTED; then rm -rf "$GNOLAND_MAINNET_HOME"; fi
        mv "$ROLLBACK_ROOT/node-data" "$GNOLAND_MAINNET_HOME" || true
    elif $EXTERNAL_NODE_RUNTIME_STARTED; then
        rm -rf "$GNOLAND_MAINNET_HOME"
    fi

    if $OLD_GNO_PRESENT && [ -f "$ROLLBACK_ROOT/gno" ]; then
        install -m 0755 "$ROLLBACK_ROOT/gno" "$GNO_BIN" || true
    elif ! $OLD_GNO_PRESENT; then
        rm -f "$GNO_BIN"
    fi
    if $OLD_GNOLAND_PRESENT && [ -f "$ROLLBACK_ROOT/gnoland" ]; then
        install -m 0755 "$ROLLBACK_ROOT/gnoland" "$GNOLAND_BIN" || true
    elif ! $OLD_GNOLAND_PRESENT; then
        rm -f "$GNOLAND_BIN"
    fi
    if $OLD_GNOKEY_PRESENT && [ -f "$ROLLBACK_ROOT/gnokey" ]; then
        install -m 0755 "$ROLLBACK_ROOT/gnokey" "$GNOKEY_BIN" || true
    elif ! $OLD_GNOKEY_PRESENT; then
        rm -f "$GNOKEY_BIN"
    fi
    if $OLD_SERVICE_PRESENT && [ -f "$ROLLBACK_ROOT/service" ]; then
        sudo cp "$ROLLBACK_ROOT/service" "$SERVICE_FILE" || true
    fi
    if $OLD_PROFILE_PRESENT && [ -f "$ROLLBACK_ROOT/bash_profile" ]; then
        cp -p "$ROLLBACK_ROOT/bash_profile" "$HOME/.bash_profile" || true
    elif ! $OLD_PROFILE_PRESENT; then
        rm -f "$HOME/.bash_profile"
    fi
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
    if $SERVICE_WAS_ACTIVE && $OLD_SERVICE_PRESENT; then
        sudo systemctl enable "$GNOLAND_MAINNET_SERVICE_NAME" >/dev/null 2>&1 || true
        sudo systemctl restart "$GNOLAND_MAINNET_SERVICE_NAME" >/dev/null 2>&1 || true
    fi
    CUTOVER_STARTED=false
    echo -e "${YELLOW}Rollback attempted. Review service status and journal before retrying.${RESET}" >&2
    set -e
}

on_error() {
    local exit_code=$?
    local line_number=${1:-unknown}
    local failed_command=${2:-unknown}
    trap - ERR
    rollback_install
    echo -e "${RED}Gno.land gnoland-1 installation failed.${RESET}" >&2
    echo "Stage: $CURRENT_STAGE" >&2
    echo "Line: $line_number" >&2
    echo "Command: $failed_command" >&2
    echo "Exit code: $exit_code" >&2
    exit "$exit_code"
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

path_is_under_home() {
    local canonical_home canonical_path
    canonical_home=$(realpath -m "$HOME")
    canonical_path=$(realpath -m "$1")
    case "$canonical_path" in "$canonical_home"/*) return 0 ;; *) return 1 ;; esac
}

write_profile_block() {
    local profile="$HOME/.bash_profile" tmp
    tmp=$(mktemp)
    if [ -f "$profile" ]; then
        awk -v begin="$PROFILE_BEGIN" -v end="$PROFILE_END" '
            $0 == begin {skip=1; next}
            $0 == end {skip=0; next}
            skip {next}
            /^export GNOLAND_CHAIN_ID=/ {next}
            /^export GNOLAND_MAINNET_HOME=/ {next}
            /^export GNOLAND_MAINNET_SERVICE_NAME=/ {next}
            /^export GNOLAND_DEPLOYMENT_DIR=/ {next}
            /^export GNOLAND_GENESIS=/ {next}
            /^export GNOLAND_MONIKER=/ {next}
            /^export GNOLAND_PORT=/ {next}
            /^export GNOLAND_OPERATOR_KEY=/ {next}
            /^export GNOLAND_REMOTE=/ {next}
            /^export GNOLAND_PUBLIC_REMOTE=/ {next}
            /^export GNOKEY_HOME=/ {next}
            /^export GNO_BIN=/ {next}
            /^export GNO_SOURCE_DIR=/ {next}
            /^export GNOROOT=/ {next}
            {print}
        ' "$profile" > "$tmp"
    fi
    cat >> "$tmp" <<EOF_PROFILE
$PROFILE_BEGIN
export GNOLAND_MONIKER="$GNOLAND_MONIKER"
export GNOLAND_CHAIN_ID="$CHAIN_ID"
export GNOLAND_PORT="$GNOLAND_PORT"
export GNOLAND_MAINNET_HOME="$GNOLAND_MAINNET_HOME"
export GNOLAND_MAINNET_SERVICE_NAME="$GNOLAND_MAINNET_SERVICE_NAME"
export GNOLAND_DEPLOYMENT_DIR="$GNOLAND_DEPLOYMENT_DIR"
export GNOLAND_GENESIS="$GENESIS_FILE"
export GNOKEY_HOME="$GNOKEY_HOME"
export GNO_BIN="$GNO_BIN"
export GNOLAND_OPERATOR_KEY="$OPERATOR_KEY_NAME"
export GNO_SOURCE_DIR="$GNO_SOURCE_DIR"
export GNOROOT="$GNOROOT"
export GNOLAND_REMOTE="http://127.0.0.1:${GNOLAND_RPC_PORT}"
export GNOLAND_PUBLIC_REMOTE="$PUBLIC_RPC"
export PATH="\$HOME/go/bin:\$PATH"
$PROFILE_END
EOF_PROFILE
    mv "$tmp" "$profile"
}

verify_reported_version() {
    local binary=$1 label=$2 expected_label=$3 output version
    output=$("$binary" version 2>&1)
    version=$(printf '%s\n' "$output" | awk -v label="$expected_label" '$1 == label && $2 == "version:" {print $3; exit}')
    [ "$version" = "$ASSET_VERSION" ] || { echo "$label reports '${version:-unavailable}', expected '$ASSET_VERSION'." >&2; return 1; }
    echo -e "${GREEN}Verified $label reported version: $version${RESET}"
}

stage_oci_binary() {
    local label=$1 repository=$2 manifest_digest=$3 layer_digest=$4 binary_path=$5 expected_sha=$6 output=$7
    local token manifest_file layer_file binary_file tar_path
    manifest_file="$TMP_DIR/oci-${label}.manifest.json"
    layer_file="$TMP_DIR/oci-${label}.layer.tar.gz"
    binary_file="$TMP_DIR/oci-${label}.binary"
    tar_path=${binary_path#/}

    token=$(curl -m 30 -fsSL "https://${OCI_REGISTRY}/token?scope=repository:${repository}:pull" | jq -er '.token')
    curl -m 120 -fsSL \
        -H "Authorization: Bearer $token" \
        -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
        "https://${OCI_REGISTRY}/v2/${repository}/manifests/${manifest_digest}" -o "$manifest_file"
    printf '%s  %s\n' "${manifest_digest#sha256:}" "$manifest_file" | sha256sum --check - >/dev/null
    jq -e --arg digest "$layer_digest" \
        '(.schemaVersion == 2) and any(.layers[]?; .digest == $digest and .mediaType == "application/vnd.oci.image.layer.v1.tar+gzip")' \
        "$manifest_file" >/dev/null

    curl -m 120 -fsSL -H "Authorization: Bearer $token" \
        "https://${OCI_REGISTRY}/v2/${repository}/blobs/${layer_digest}" -o "$layer_file"
    printf '%s  %s\n' "${layer_digest#sha256:}" "$layer_file" | sha256sum --check - >/dev/null
    tar -tzf "$layer_file" | grep -Fxq "$tar_path" || {
        echo "${label} OCI layer does not contain ${binary_path}." >&2
        return 1
    }
    tar -xOzf "$layer_file" "$tar_path" > "$binary_file"
    printf '%s  %s\n' "$expected_sha" "$binary_file" | sha256sum --check - >/dev/null
    chmod 0755 "$binary_file"
    install -m 0755 "$binary_file" "$output"
    printf '%s  %s\n' "$expected_sha" "$output" | sha256sum --check - >/dev/null
}

check_upstream_release_drift() {
    local json observed_target observed_genesis
    json=$(curl -m 15 -fsSL "$RELEASE_API_URL" 2>/dev/null || true)
    if [ -z "$json" ]; then
        echo -e "${YELLOW}Upstream release metadata is unavailable; pinned SHA-256 verification remains enforced.${RESET}"
        return 0
    fi
    observed_target=$(printf '%s' "$json" | jq -r '.target_commitish // empty')
    observed_genesis=$(printf '%s' "$json" | jq -r '.assets[]? | select(.name=="genesis.json") | .digest' | head -n 1)
    if [ "$observed_target" != "$RELEASE_COMMIT" ] || \
       [ "$observed_genesis" != "sha256:$GENESIS_SHA256" ]; then
        echo -e "${RED}Upstream chain/mainnet release metadata differs from Valley's reviewed pins.${RESET}" >&2
        echo "Nothing has been stopped or deleted. Review Valley pins before installing." >&2
        return 1
    fi
    echo -e "${GREEN}Upstream release digests still match Valley's reviewed pins.${RESET}"
}

service_belongs_to_instance() {
    local resolved_service_file unit_user unit_workdir
    resolved_service_file=$(systemctl show "$GNOLAND_MAINNET_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
    [ -n "$resolved_service_file" ] || return 0
    [ -f "$resolved_service_file" ] || { echo -e "${RED}Cannot inspect existing service: $resolved_service_file${RESET}" >&2; return 1; }
    unit_user=$(sed -n 's/^User=//p' "$resolved_service_file" | tail -n 1)
    unit_workdir=$(sed -n 's/^WorkingDirectory=//p' "$resolved_service_file" | tail -n 1)
    if [ "$unit_user" != "$OS_USER" ] || [ "$unit_workdir" != "$GNO_SOURCE_DIR" ]; then
        echo -e "${RED}${GNOLAND_MAINNET_SERVICE_NAME}.service belongs to another instance.${RESET}" >&2
        return 1
    fi
}

port_is_free() {
    local port=$1
    ! ss -H -ltn "sport = :$port" 2>/dev/null | grep -q .
}

create_optional_backup() {
    local answer backup_root backup_dir
    read -r -p "Create a persistent backup of existing node secrets and operator keyring first? (Y/n): " answer
    answer=${answer:-Y}
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Persistent backup skipped by operator choice."; return 0; }
    backup_root="$HOME/gnoland-backups"
    backup_dir="$backup_root/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    if [ -d "$GNOLAND_MAINNET_HOME/secrets" ]; then
        tar -czf "$backup_dir/node-secrets.tar.gz" -C "$GNOLAND_MAINNET_HOME" secrets
        chmod 600 "$backup_dir/node-secrets.tar.gz"
    fi
    if [ -d "$GNOKEY_HOME" ] && [ -n "$(find "$GNOKEY_HOME" -mindepth 1 -print -quit 2>/dev/null)" ]; then
        tar -czf "$backup_dir/operator-keyring.tar.gz" -C "$(dirname "$GNOKEY_HOME")" "$(basename "$GNOKEY_HOME")"
        chmod 600 "$backup_dir/operator-keyring.tar.gz"
    fi
    echo -e "${GREEN}Persistent backup created under $backup_dir${RESET}"
}

configure_ufw_safely() {
    local ssh_port="" confirm
    [[ "$SETUP_UFW" =~ ^[Yy]$ ]] || return 0
    if [[ "${SSH_CONNECTION:-}" =~ ^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+([0-9]+)$ ]]; then
        ssh_port=${BASH_REMATCH[1]}
    fi
    if [ -z "$ssh_port" ] && command -v sshd >/dev/null 2>&1; then
        ssh_port=$(sudo sshd -T 2>/dev/null | awk '$1=="port" {print $2; exit}' || true)
    fi
    while [[ ! "$ssh_port" =~ ^[0-9]+$ ]] || [ "$ssh_port" -lt 1 ] || [ "$ssh_port" -gt 65535 ]; do
        read -r -p "Enter the SSH port that must remain reachable before enabling UFW: " ssh_port
    done
    echo -e "${YELLOW}UFW preview:${RESET} allow SSH ${ssh_port}/tcp and Gnoland P2P ${GNOLAND_P2P_PORT}/tcp; RPC/ABCI remain loopback."
    read -r -p "Type ENABLE-UFW to apply these rules and enable UFW, or press Enter to skip: " confirm
    [ "$confirm" = "ENABLE-UFW" ] || { echo "UFW setup skipped."; return 0; }
    sudo apt install -y ufw
    sudo ufw allow "${ssh_port}/tcp" comment "SSH Access"
    sudo ufw allow "${GNOLAND_P2P_PORT}/tcp" comment "Gno.land gnoland-1 P2P"
    sudo ufw --force enable
    sudo ufw status verbose
}

if [ -n "${SUDO_USER:-}" ]; then
    echo -e "${RED}Run Valley of Gnoland as the node OS user, not with sudo.${RESET}" >&2
    false
fi
if [ "$(realpath -m "$GENESIS_FILE")" != "$(realpath -m "$GNOLAND_DEPLOYMENT_DIR/genesis.json")" ]; then
    echo -e "${RED}Mainnet genesis must be stored under $GNOLAND_DEPLOYMENT_DIR.${RESET}" >&2
    false
fi
for instance_path in "$GNO_SOURCE_DIR" "$GNOLAND_DEPLOYMENT_DIR" "$GNOLAND_MAINNET_HOME" "$GNOKEY_HOME" "$GNO_BIN" "$GNOLAND_BIN" "$GNOKEY_BIN" "$GENESIS_FILE"; do
    path_is_under_home "$instance_path" || { echo -e "${RED}Unsafe instance path outside $HOME: $instance_path${RESET}" >&2; false; }
done

case "$(realpath -m "$GNOLAND_MAINNET_HOME")" in
    "$(realpath -m "$GNO_SOURCE_DIR")"/*) NODE_HOME_INSIDE_SOURCE=true ;;
esac

echo -e "\n--- Gno.land gnoland-1 Node Setup ---"
echo "  Network:          $CHAIN_ID"
echo "  Source commit:    $SOURCE_COMMIT"
echo "  Asset version:    $ASSET_VERSION"
echo "  Source / GNOROOT: $GNO_SOURCE_DIR"
echo "  Node data:        $GNOLAND_MAINNET_HOME"
echo "  Operator keyring: $GNOKEY_HOME"

while :; do
    read -r -p "Enter your GNOLAND_MONIKER: " GNOLAND_MONIKER
    [ -n "$GNOLAND_MONIKER" ] && break
    echo -e "${RED}Moniker is required.${RESET}"
done
while :; do
    read -r -p "Enter preferred port prefix (leave empty for default 26): " GNOLAND_PORT
    GNOLAND_PORT=${GNOLAND_PORT:-26}
    if [[ "$GNOLAND_PORT" =~ ^[0-9]{2}$ ]] && [ "$((10#$GNOLAND_PORT))" -ge 1 ] && [ "$((10#$GNOLAND_PORT))" -le 64 ]; then break; fi
    echo -e "${RED}Port prefix must be two digits from 01 through 64.${RESET}"
done
read -r -p "Enter public external address host/IP for P2P (optional): " GNOLAND_EXTERNAL_HOST
read -r -p "Configure UFW firewall rules for Gnoland? (y/n, default n): " SETUP_UFW
SETUP_UFW=${SETUP_UFW:-n}
while :; do
    if [ -z "${GNOLAND_MAINNET_SERVICE_NAME:-}" ]; then
        read -r -p "Enter service name (default 'gnoland'): " GNOLAND_MAINNET_SERVICE_NAME
        GNOLAND_MAINNET_SERVICE_NAME=${GNOLAND_MAINNET_SERVICE_NAME:-gnoland}
    fi
    GNOLAND_MAINNET_SERVICE_NAME=${GNOLAND_MAINNET_SERVICE_NAME%.service}
    [[ "$GNOLAND_MAINNET_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]] && break
    GNOLAND_MAINNET_SERVICE_NAME=""
done

SERVICE_FILE="/etc/systemd/system/${GNOLAND_MAINNET_SERVICE_NAME}.service"
GNOLAND_RPC_PORT="${GNOLAND_PORT}657"
GNOLAND_P2P_PORT="${GNOLAND_PORT}656"
GNOLAND_ABCI_PORT="${GNOLAND_PORT}658"
service_belongs_to_instance
EXISTING_SERVICE_FILE=$(systemctl show "$GNOLAND_MAINNET_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
if [ -n "$EXISTING_SERVICE_FILE" ] && systemctl is-active --quiet "$GNOLAND_MAINNET_SERVICE_NAME"; then SERVICE_WAS_ACTIVE=true; fi
EXISTING_NODE_STATE=""
if [ -d "$GNOLAND_MAINNET_HOME" ]; then EXISTING_NODE_STATE=$(find "$GNOLAND_MAINNET_HOME" -mindepth 1 -print -quit 2>/dev/null || true); fi
if [ -n "$EXISTING_NODE_STATE" ] || [ -f "$GENESIS_FILE" ]; then
    if [ -z "$EXISTING_SERVICE_FILE" ] || [ ! -f "$EXISTING_SERVICE_FILE" ] || ! grep -Fq -- "--chainid $CHAIN_ID" "$EXISTING_SERVICE_FILE"; then
        echo -e "${RED}Destructive reinstall refused: existing node identity is not explicitly configured for $CHAIN_ID.${RESET}" >&2
        false
    fi
fi

echo
echo -e "${YELLOW}Operator key choice:${RESET}"
echo "1. Reuse an existing local operator key"
echo "2. Recover an operator key from its mnemonic"
echo "3. Create a new operator key"
while :; do read -r -p "Choose 1, 2, or 3: " OPERATOR_KEY_ACTION; [[ "$OPERATOR_KEY_ACTION" =~ ^[123]$ ]] && break; done

echo
echo -e "${YELLOW}Installation preview:${RESET}"
echo "  Network:          $CHAIN_ID"
echo "  Asset version:    $ASSET_VERSION"
echo "  OS user:          $OS_USER"
echo "  Service:          ${GNOLAND_MAINNET_SERVICE_NAME}.service"
echo "  Source / GNOROOT: $GNO_SOURCE_DIR"
echo "  Node data:        $GNOLAND_MAINNET_HOME"
echo "  P2P/RPC/ABCI:     $GNOLAND_P2P_PORT / $GNOLAND_RPC_PORT / $GNOLAND_ABCI_PORT"
if [ -n "$EXISTING_NODE_STATE" ]; then
    echo -e "${YELLOW}Safe reinstall: existing validator/node secrets will be preserved exactly. Node database/config will be rebuilt.${RESET}"
else
    echo "Fresh install: new node secrets will be generated."
fi
read -r -p "Type INSTALL-GNOLAND-1 to continue: " CONFIRM
[ "$CONFIRM" = "INSTALL-GNOLAND-1" ] || { echo "Installation cancelled."; exit 0; }

CURRENT_STAGE="install prerequisites before cutover"
sudo apt update -y
sudo apt install -y curl git jq ca-certificates gzip iproute2
if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo -e "${RED}Only Linux amd64 is verified for these assets.${RESET}" >&2
    false
fi

if [ -z "$EXISTING_SERVICE_FILE" ]; then
    while ! port_is_free "$GNOLAND_P2P_PORT" || ! port_is_free "$GNOLAND_RPC_PORT" || ! port_is_free "$GNOLAND_ABCI_PORT"; do
        echo -e "${RED}Port prefix $GNOLAND_PORT conflicts with a running listener.${RESET}"
        read -r -p "Enter another two-digit port prefix: " GNOLAND_PORT
        if [[ "$GNOLAND_PORT" =~ ^[0-9]{2}$ ]] && [ "$((10#$GNOLAND_PORT))" -ge 1 ] && [ "$((10#$GNOLAND_PORT))" -le 64 ]; then
            GNOLAND_RPC_PORT="${GNOLAND_PORT}657"; GNOLAND_P2P_PORT="${GNOLAND_PORT}656"; GNOLAND_ABCI_PORT="${GNOLAND_PORT}658"
        fi
    done
fi

CURRENT_STAGE="stage all reviewed artifacts before cutover"
check_upstream_release_drift
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/stage-source"
git -C "$TMP_DIR/stage-source" init -q
git -C "$TMP_DIR/stage-source" remote add origin https://github.com/gnolang/gno.git
release_tag_commit=$(git -C "$TMP_DIR/stage-source" ls-remote --refs origin "refs/tags/$RELEASE_TAG" | awk 'NR==1 {print $1}' || true)
[ "$release_tag_commit" = "$RELEASE_COMMIT" ] || { echo "The $RELEASE_TAG tag moved from the reviewed commit." >&2; false; }
branch_tip=$(git -C "$TMP_DIR/stage-source" ls-remote --refs origin "refs/heads/$SOURCE_BRANCH" | awk 'NR==1 {print $1}' || true)
if [ -n "$branch_tip" ] && [ "$branch_tip" != "$SOURCE_COMMIT" ]; then
    echo -e "${YELLOW}Upstream $SOURCE_BRANCH tip is $branch_tip; installing reviewed pin $SOURCE_COMMIT.${RESET}"
fi
git -C "$TMP_DIR/stage-source" fetch --depth 1 origin "$SOURCE_COMMIT" >/dev/null
git -C "$TMP_DIR/stage-source" checkout --detach --force "$SOURCE_COMMIT" >/dev/null
[ "$(git -C "$TMP_DIR/stage-source" rev-parse HEAD)" = "$SOURCE_COMMIT" ]
[ -d "$TMP_DIR/stage-source/misc/deployments/mainnet.gno.land" ] || { echo "Pinned source lacks mainnet deployment files." >&2; false; }

stage_oci_binary gno "$GNO_IMAGE_REPOSITORY" "$GNO_IMAGE_MANIFEST_DIGEST" "$GNO_BINARY_LAYER_DIGEST" "$GNO_BINARY_PATH" "$GNO_BIN_SHA256" "$TMP_DIR/gno"
verify_reported_version "$TMP_DIR/gno" "gno" gno
stage_oci_binary gnoland "$GNOLAND_IMAGE_REPOSITORY" "$GNOLAND_IMAGE_MANIFEST_DIGEST" "$GNOLAND_BINARY_LAYER_DIGEST" "$GNOLAND_BINARY_PATH" "$GNOLAND_BIN_SHA256" "$TMP_DIR/gnoland"
verify_reported_version "$TMP_DIR/gnoland" "gnoland" gnoland
stage_oci_binary gnokey "$GNOKEY_IMAGE_REPOSITORY" "$GNOKEY_IMAGE_MANIFEST_DIGEST" "$GNOKEY_BINARY_LAYER_DIGEST" "$GNOKEY_BINARY_PATH" "$GNOKEY_BIN_SHA256" "$TMP_DIR/gnokey"
verify_reported_version "$TMP_DIR/gnokey" "gnokey" gnokey
curl -fsSL "$GENESIS_GZ_URL" -o "$TMP_DIR/genesis.json.gz"
printf '%s  %s\n' "$GENESIS_GZ_SHA256" "$TMP_DIR/genesis.json.gz" | sha256sum --check - >/dev/null
gzip -dc "$TMP_DIR/genesis.json.gz" > "$TMP_DIR/genesis.json"
printf '%s  %s\n' "$GENESIS_SHA256" "$TMP_DIR/genesis.json" | sha256sum --check - >/dev/null

echo -e "${GREEN}All source, binary, and genesis artifacts are staged and verified. Live node has not been modified yet.${RESET}"
create_optional_backup

ROLLBACK_ROOT="$HOME/.gnoland-mainnet-install-rollback-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$ROLLBACK_ROOT"
[ -f "$HOME/.bash_profile" ] && { cp -p "$HOME/.bash_profile" "$ROLLBACK_ROOT/bash_profile"; OLD_PROFILE_PRESENT=true; }
[ -x "$GNO_BIN" ] && { cp -p "$GNO_BIN" "$ROLLBACK_ROOT/gno"; OLD_GNO_PRESENT=true; }
[ -x "$GNOLAND_BIN" ] && { cp -p "$GNOLAND_BIN" "$ROLLBACK_ROOT/gnoland"; OLD_GNOLAND_PRESENT=true; }
[ -x "$GNOKEY_BIN" ] && { cp -p "$GNOKEY_BIN" "$ROLLBACK_ROOT/gnokey"; OLD_GNOKEY_PRESENT=true; }
[ -f "$SERVICE_FILE" ] && { sudo cp "$SERVICE_FILE" "$ROLLBACK_ROOT/service"; sudo chown "$OS_USER":"$(id -gn)" "$ROLLBACK_ROOT/service"; OLD_SERVICE_PRESENT=true; }

CURRENT_STAGE="atomic install cutover"
CUTOVER_STARTED=true
sudo systemctl stop "$GNOLAND_MAINNET_SERVICE_NAME" 2>/dev/null || true
if $NODE_HOME_INSIDE_SOURCE; then
    if [ -d "$GNO_SOURCE_DIR" ]; then mv "$GNO_SOURCE_DIR" "$ROLLBACK_ROOT/source"; OLD_SOURCE_PRESENT=true; fi
else
    if [ -d "$GNOLAND_MAINNET_HOME" ]; then mv "$GNOLAND_MAINNET_HOME" "$ROLLBACK_ROOT/node-data"; OLD_EXTERNAL_NODE_PRESENT=true; fi
    if [ -d "$GNO_SOURCE_DIR" ]; then mv "$GNO_SOURCE_DIR" "$ROLLBACK_ROOT/source"; OLD_SOURCE_PRESENT=true; fi
fi
SOURCE_CUTOVER_ATTEMPTED=true
mkdir -p "$(dirname "$GNO_SOURCE_DIR")"
cp -a "$TMP_DIR/stage-source" "$GNO_SOURCE_DIR"
mkdir -p "$GNOLAND_DEPLOYMENT_DIR" "$HOME/go/bin" "$GNOKEY_HOME"
install -m 0755 "$TMP_DIR/gno" "$GNO_BIN"
install -m 0755 "$TMP_DIR/gnoland" "$GNOLAND_BIN"
install -m 0755 "$TMP_DIR/gnokey" "$GNOKEY_BIN"
install -m 0644 "$TMP_DIR/genesis.json" "$GENESIS_FILE"
printf '%s  %s\n' "$GNO_BIN_SHA256" "$GNO_BIN" | sha256sum --check - >/dev/null
printf '%s  %s\n' "$GNOLAND_BIN_SHA256" "$GNOLAND_BIN" | sha256sum --check - >/dev/null
printf '%s  %s\n' "$GNOKEY_BIN_SHA256" "$GNOKEY_BIN" | sha256sum --check - >/dev/null
printf '%s  %s\n' "$GENESIS_SHA256" "$GENESIS_FILE" | sha256sum --check - >/dev/null
export GNOROOT
export PATH="$HOME/go/bin:$PATH"
hash -r

operator_key_exists() {
    "$GNOKEY_BIN" -home "$GNOKEY_HOME" list 2>/dev/null | awk -v key="$1" '$2 == key {found=1} END {exit !found}'
}
CURRENT_STAGE="select or recover operator key"
case "$OPERATOR_KEY_ACTION" in
    1)
        LOCAL_KEYS=$("$GNOKEY_BIN" -home "$GNOKEY_HOME" list || true)
        if [ -z "$LOCAL_KEYS" ]; then
            while :; do read -r -p "No local key found. Choose 2 to recover or 3 for a new key: " OPERATOR_KEY_ACTION; [[ "$OPERATOR_KEY_ACTION" =~ ^[23]$ ]] && break; done
        else
            echo "$LOCAL_KEYS"
            while :; do read -r -p "Type the existing key name to reuse: " OPERATOR_KEY_NAME; [ -n "$OPERATOR_KEY_NAME" ] && operator_key_exists "$OPERATOR_KEY_NAME" && break; done
        fi
        ;;
esac
case "$OPERATOR_KEY_ACTION" in
    2)
        read -r -p "Enter key name for the recovered operator (default 'operator'): " OPERATOR_KEY_NAME
        OPERATOR_KEY_NAME=${OPERATOR_KEY_NAME:-operator}
        operator_key_exists "$OPERATOR_KEY_NAME" || "$GNOKEY_BIN" -home "$GNOKEY_HOME" add -recover "$OPERATOR_KEY_NAME"
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
[ -n "${OPERATOR_KEY_NAME:-}" ] || { echo "No operator key selected." >&2; false; }

cd "$GNO_SOURCE_DIR"
CURRENT_STAGE="initialize config while preserving validator identity"
CONFIG_FILE="$GNOLAND_MAINNET_HOME/config/config.toml"
if ! $NODE_HOME_INSIDE_SOURCE; then EXTERNAL_NODE_RUNTIME_STARTED=true; fi
mkdir -p "$GNOLAND_MAINNET_HOME"
"$GNOLAND_BIN" config init -force --config-path "$CONFIG_FILE"
PRESERVED_SECRETS=""
if $OLD_SOURCE_PRESENT && $NODE_HOME_INSIDE_SOURCE; then
    old_relative_home=$(realpath --relative-to="$GNO_SOURCE_DIR" "$GNOLAND_MAINNET_HOME")
    [ -d "$ROLLBACK_ROOT/source/$old_relative_home/secrets" ] && PRESERVED_SECRETS="$ROLLBACK_ROOT/source/$old_relative_home/secrets"
elif $OLD_EXTERNAL_NODE_PRESENT && [ -d "$ROLLBACK_ROOT/node-data/secrets" ]; then
    PRESERVED_SECRETS="$ROLLBACK_ROOT/node-data/secrets"
fi
if [ -n "$PRESERVED_SECRETS" ]; then
    rm -rf "$GNOLAND_MAINNET_HOME/secrets"
    cp -a "$PRESERVED_SECRETS" "$GNOLAND_MAINNET_HOME/secrets"
    echo -e "${GREEN}Preserved existing validator/node secrets exactly for safe reinstall.${RESET}"
else
    "$GNOLAND_BIN" secrets init -force --data-dir "$GNOLAND_MAINNET_HOME/secrets"
    echo -e "${GREEN}Generated fresh node secrets for a fresh installation.${RESET}"
fi

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
if [ -n "$GNOLAND_EXTERNAL_HOST" ]; then "$GNOLAND_BIN" config set --config-path "$CONFIG_FILE" p2p.external_address "${GNOLAND_EXTERNAL_HOST}:${GNOLAND_P2P_PORT}"; fi

configure_ufw_safely

sudo tee "$SERVICE_FILE" >/dev/null <<EOF_SERVICE
[Unit]
Description=Gno.land gnoland-1 Node (${GNOLAND_MAINNET_SERVICE_NAME})
After=network-online.target

[Service]
User=$OS_USER
WorkingDirectory=$GNO_SOURCE_DIR
Environment=GNOROOT=$GNOROOT
Environment=PATH=$HOME/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$GNOLAND_BIN start --chainid $CHAIN_ID --genesis $GENESIS_FILE --data-dir $GNOLAND_MAINNET_HOME --gnoroot-dir $GNOROOT --skip-genesis-sig-verification --log-level info
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
LimitNPROC=65536

[Install]
WantedBy=multi-user.target
EOF_SERVICE

write_profile_block
sudo systemctl daemon-reload
CURRENT_STAGE="start and verify gnoland-1 service"
sudo systemctl enable "$GNOLAND_MAINNET_SERVICE_NAME"
sudo systemctl restart "$GNOLAND_MAINNET_SERVICE_NAME"
echo -e "${CYAN}Waiting for the gnoland-1 RPC startup check (up to 90 seconds).${RESET}"
RPC_STATUS=""
for _ in $(seq 1 90); do
    systemctl is-active --quiet "$GNOLAND_MAINNET_SERVICE_NAME" || break
    RPC_STATUS=$(curl -m 2 -fsS "http://127.0.0.1:${GNOLAND_RPC_PORT}/status" 2>/dev/null || true)
    [ -n "$RPC_STATUS" ] && break
    sleep 1
done
RPC_NETWORK=$(printf '%s' "$RPC_STATUS" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
CONFIG_ABCI_PORT=$(sed -n 's/^proxy_app = "tcp:\/\/127\.0\.0\.1:\([0-9][0-9]*\)"$/\1/p' "$CONFIG_FILE")
CONFIG_P2P_PORT=$(awk -F: '/^[[:space:]]*\[p2p\][[:space:]]*$/ {in_p2p=1; next} /^[[:space:]]*\[/ {in_p2p=0} in_p2p && /^[[:space:]]*laddr = "tcp:\/\// {gsub(/".*/, "", $NF); print $NF; exit}' "$CONFIG_FILE")
CONFIG_RPC_PORT=$(awk -F: '/^[[:space:]]*\[rpc\][[:space:]]*$/ {in_rpc=1; next} /^[[:space:]]*\[/ {in_rpc=0} in_rpc && /^[[:space:]]*laddr = "tcp:\/\// {gsub(/".*/, "", $NF); print $NF; exit}' "$CONFIG_FILE")
if systemctl is-active --quiet "$GNOLAND_MAINNET_SERVICE_NAME" && [ "$RPC_NETWORK" = "$CHAIN_ID" ] && [ "$CONFIG_ABCI_PORT" = "$GNOLAND_ABCI_PORT" ] && [ "$CONFIG_P2P_PORT" = "$GNOLAND_P2P_PORT" ] && [ "$CONFIG_RPC_PORT" = "$GNOLAND_RPC_PORT" ]; then
    echo -e "${GREEN}Gnoland service started successfully.${RESET}"
    echo "Verified RPC network: $RPC_NETWORK"
else
    sudo systemctl status "$GNOLAND_MAINNET_SERVICE_NAME" --no-pager -l || true
    sudo journalctl -u "$GNOLAND_MAINNET_SERVICE_NAME" -n 100 --no-pager || true
    false
fi

CUTOVER_STARTED=false
rm -rf "$ROLLBACK_ROOT"
ROLLBACK_ROOT=""
CURRENT_STAGE="complete"
echo -e "${GREEN}Safe installation completed. Validator/node identity was preserved when an existing Valley mainnet node was detected.${RESET}"
echo "Let's Buidl Gnoland Together"
