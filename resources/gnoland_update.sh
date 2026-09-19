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
RESTART_REQUIRED=false
GENESIS_WAS_MISSING=false
TMP_DIR=""
PREVIOUS_SOURCE_COMMIT=""
PREVIOUS_GNO_PRESENT=false
PREVIOUS_GNOLAND_PRESENT=false
PREVIOUS_GNOKEY_PRESENT=false
PREVIOUS_PROFILE_PRESENT=false

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
readonly PUBLIC_RPC="https://rpc.gno.land"
readonly PROFILE_BEGIN="# >>> GRAND VALLEY GNOLAND MAINNET >>>"
readonly PROFILE_END="# <<< GRAND VALLEY GNOLAND MAINNET <<<"

# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null || true

GNOLAND_MAINNET_SERVICE_NAME=${GNOLAND_MAINNET_SERVICE_NAME:-gnoland}
GNOLAND_MAINNET_SERVICE_NAME=${GNOLAND_MAINNET_SERVICE_NAME%.service}
GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOLAND_DEPLOYMENT_DIR=${GNOLAND_DEPLOYMENT_DIR:-$GNO_SOURCE_DIR/misc/deployments/mainnet.gno.land}
GNOLAND_MAINNET_HOME=${GNOLAND_MAINNET_HOME:-$GNO_SOURCE_DIR/gnoland-data}
GNOLAND_GENESIS=${GNOLAND_GENESIS:-$GNOLAND_DEPLOYMENT_DIR/genesis.json}
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNO_BIN=${GNO_BIN:-$HOME/go/bin/gno}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
OS_USER=$(id -un)
SERVICE_FILE=$(systemctl show "$GNOLAND_MAINNET_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)

cleanup() {
    [ -z "$TMP_DIR" ] || rm -rf "$TMP_DIR"
}
trap cleanup EXIT

rollback_update() {
    $CUTOVER_STARTED || return 0
    $ROLLBACK_COMPLETE && return 0
    ROLLBACK_COMPLETE=true
    set +e
    echo -e "${YELLOW}Update did not pass the health gate. Restoring the previous runtime.${RESET}" >&2

    if [ -n "$SERVICE_FILE" ]; then
        sudo systemctl stop "$GNOLAND_MAINNET_SERVICE_NAME" >/dev/null 2>&1 || true
    fi

    if [ -n "$PREVIOUS_SOURCE_COMMIT" ] && [ -d "$GNO_SOURCE_DIR/.git" ]; then
        git -C "$GNO_SOURCE_DIR" checkout --detach --force "$PREVIOUS_SOURCE_COMMIT" >/dev/null 2>&1 || true
    fi

    if $PREVIOUS_GNO_PRESENT && [ -f "$TMP_DIR/rollback/gno" ]; then
        install -m 0755 "$TMP_DIR/rollback/gno" "$GNO_BIN" || true
    elif ! $PREVIOUS_GNO_PRESENT; then
        rm -f "$GNO_BIN"
    fi
    if $PREVIOUS_GNOLAND_PRESENT && [ -f "$TMP_DIR/rollback/gnoland" ]; then
        install -m 0755 "$TMP_DIR/rollback/gnoland" "$GNOLAND_BIN" || true
    elif ! $PREVIOUS_GNOLAND_PRESENT; then
        rm -f "$GNOLAND_BIN"
    fi
    if $PREVIOUS_GNOKEY_PRESENT && [ -f "$TMP_DIR/rollback/gnokey" ]; then
        install -m 0755 "$TMP_DIR/rollback/gnokey" "$GNOKEY_BIN" || true
    elif ! $PREVIOUS_GNOKEY_PRESENT; then
        rm -f "$GNOKEY_BIN"
    fi

    if $GENESIS_WAS_MISSING; then
        rm -f "$GNOLAND_GENESIS"
    fi

    if $PREVIOUS_PROFILE_PRESENT && [ -f "$TMP_DIR/rollback/bash_profile" ]; then
        cp -p "$TMP_DIR/rollback/bash_profile" "$HOME/.bash_profile" || true
    elif ! $PREVIOUS_PROFILE_PRESENT; then
        rm -f "$HOME/.bash_profile"
    fi

    if $SERVICE_WAS_ACTIVE && [ -n "$SERVICE_FILE" ]; then
        sudo systemctl daemon-reload >/dev/null 2>&1 || true
        sudo systemctl restart "$GNOLAND_MAINNET_SERVICE_NAME" >/dev/null 2>&1 || true
    fi
    echo -e "${YELLOW}Rollback attempted. Review service status and journal before retrying.${RESET}" >&2
    set -e
}

on_error() {
    local exit_code=$?
    local line_number=${1:-unknown}
    local failed_command=${2:-unknown}
    trap - ERR
    rollback_update
    echo -e "${RED}Gno.land gnoland-1 update failed.${RESET}" >&2
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
    case "$canonical_path" in
        "$canonical_home"/*) return 0 ;;
        *) return 1 ;;
    esac
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
export GNOLAND_CHAIN_ID="$CHAIN_ID"
export GNOLAND_MAINNET_HOME="$GNOLAND_MAINNET_HOME"
export GNOLAND_MAINNET_SERVICE_NAME="$GNOLAND_MAINNET_SERVICE_NAME"
export GNOLAND_DEPLOYMENT_DIR="$GNOLAND_DEPLOYMENT_DIR"
export GNOLAND_GENESIS="$GNOLAND_GENESIS"
export GNOKEY_HOME="${GNOKEY_HOME:-$HOME/.config/gno}"
export GNO_BIN="$GNO_BIN"
export GNO_SOURCE_DIR="$GNO_SOURCE_DIR"
export GNOROOT="$GNOROOT"
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
    if [ "$version" != "$ASSET_VERSION" ]; then
        echo "$label reports '${version:-unavailable}', expected '$ASSET_VERSION'." >&2
        return 1
    fi
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
    CURRENT_STAGE="check upstream release drift"
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
        echo "No service or binary was changed. Review and update Valley pins before continuing." >&2
        return 1
    fi
    echo -e "${GREEN}Upstream release digests still match Valley's reviewed pins.${RESET}"
}

wait_for_rpc_health() {
    local rpc_port rpc_url status network
    rpc_port=$(awk -F: '/^[[:space:]]*\[rpc\][[:space:]]*$/ {in_rpc=1; next} /^[[:space:]]*\[/ {in_rpc=0} in_rpc && /^[[:space:]]*laddr = "tcp:\/\// {gsub(/".*/, "", $NF); print $NF; exit}' "$GNOLAND_MAINNET_HOME/config/config.toml" 2>/dev/null || true)
    [ -n "$rpc_port" ] || rpc_port=26657
    rpc_url="http://127.0.0.1:${rpc_port}"
    echo -e "${CYAN}Waiting for post-update RPC health (up to 90 seconds).${RESET}"
    for _ in $(seq 1 90); do
        if systemctl is-active --quiet "$GNOLAND_MAINNET_SERVICE_NAME"; then
            status=$(curl -m 2 -fsS "$rpc_url/status" 2>/dev/null || true)
            network=$(printf '%s' "$status" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
            if [ "$network" = "$CHAIN_ID" ]; then
                echo -e "${GREEN}Post-update health check passed on $network.${RESET}"
                return 0
            fi
        fi
        sleep 1
    done
    echo "Post-update RPC health check failed for $CHAIN_ID." >&2
    return 1
}

if [ -n "${SUDO_USER:-}" ]; then
    echo "Run the updater as the node OS user, not with sudo." >&2
    exit 1
fi
if [ "$(realpath -m "$GNOLAND_GENESIS")" != "$(realpath -m "$GNOLAND_DEPLOYMENT_DIR/genesis.json")" ]; then
    echo "Mainnet genesis must be stored under $GNOLAND_DEPLOYMENT_DIR." >&2
    exit 1
fi
for instance_path in "$GNO_SOURCE_DIR" "$GNOLAND_DEPLOYMENT_DIR" "$GNOLAND_MAINNET_HOME" "$GNOLAND_GENESIS" "$GNO_BIN" "$GNOLAND_BIN" "$GNOKEY_BIN"; do
    path_is_under_home "$instance_path" || { echo "Unsafe instance path outside $HOME: $instance_path" >&2; exit 1; }
done
if [[ ! "$GNOLAND_MAINNET_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then
    echo "Invalid Gnoland service name: $GNOLAND_MAINNET_SERVICE_NAME" >&2
    exit 1
fi
if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "The published mainnet assets are only verified for Linux amd64." >&2
    exit 1
fi
for command_name in curl git jq sha256sum gzip tar; do
    command -v "$command_name" >/dev/null 2>&1 || { echo "$command_name is required for a verified mainnet update." >&2; exit 1; }
done
if [ ! -d "$GNO_SOURCE_DIR/.git" ]; then
    echo "Gno source checkout is missing at $GNO_SOURCE_DIR; run the installer first." >&2
    exit 1
fi

if [ -n "$SERVICE_FILE" ]; then
    [ -f "$SERVICE_FILE" ] || { echo "Cannot inspect existing service: $SERVICE_FILE" >&2; exit 1; }
    UNIT_USER=$(sed -n 's/^User=//p' "$SERVICE_FILE" | tail -n 1)
    UNIT_WORKDIR=$(sed -n 's/^WorkingDirectory=//p' "$SERVICE_FILE" | tail -n 1)
    if [ "$UNIT_USER" != "$OS_USER" ] || [ "$UNIT_WORKDIR" != "$GNO_SOURCE_DIR" ]; then
        echo "$GNOLAND_MAINNET_SERVICE_NAME.service belongs to another instance." >&2
        exit 1
    fi
    grep -Fq -- "--chainid $CHAIN_ID" "$SERVICE_FILE" || { echo "Update blocked: this service is not configured for $CHAIN_ID." >&2; exit 1; }
    grep -Fq -- "--genesis $GNOLAND_GENESIS" "$SERVICE_FILE" || { echo "Update blocked: service genesis path is unexpected." >&2; exit 1; }
    grep -Fq -- "--skip-genesis-sig-verification" "$SERVICE_FILE" || { echo "Update blocked: required mainnet startup flag is missing." >&2; exit 1; }
    if systemctl is-active --quiet "$GNOLAND_MAINNET_SERVICE_NAME"; then SERVICE_WAS_ACTIVE=true; fi
fi

if git -C "$GNO_SOURCE_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$GNO_SOURCE_DIR" remote set-url origin https://github.com/gnolang/gno.git
else
    git -C "$GNO_SOURCE_DIR" remote add origin https://github.com/gnolang/gno.git
fi

check_upstream_release_drift
CURRENT_STAGE="verify reviewed source and tag"
release_tag_commit=$(git -C "$GNO_SOURCE_DIR" ls-remote --refs origin "refs/tags/$RELEASE_TAG" | awk 'NR == 1 {print $1}' || true)
[ "$release_tag_commit" = "$RELEASE_COMMIT" ] || { echo "The $RELEASE_TAG tag moved from the reviewed release commit." >&2; exit 1; }
branch_tip=$(git -C "$GNO_SOURCE_DIR" ls-remote --refs origin "refs/heads/$SOURCE_BRANCH" | awk 'NR == 1 {print $1}' || true)
if [ -n "$branch_tip" ] && [ "$branch_tip" != "$SOURCE_COMMIT" ]; then
    echo -e "${YELLOW}Upstream $SOURCE_BRANCH currently points to $branch_tip; Valley remains pinned to reviewed commit $SOURCE_COMMIT.${RESET}"
fi

CURRENT_GNO_SHA=$(sha256sum "$GNO_BIN" 2>/dev/null | awk '{print $1}' || true)
CURRENT_GNOLAND_SHA=$(sha256sum "$GNOLAND_BIN" 2>/dev/null | awk '{print $1}' || true)
CURRENT_GNOKEY_SHA=$(sha256sum "$GNOKEY_BIN" 2>/dev/null | awk '{print $1}' || true)
CURRENT_SOURCE_COMMIT=$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD 2>/dev/null || true)
CURRENT_GENESIS_SHA=$(sha256sum "$GNOLAND_GENESIS" 2>/dev/null | awk '{print $1}' || true)
[ -n "$CURRENT_SOURCE_COMMIT" ] || { echo "Cannot identify the current Gno source commit at $GNO_SOURCE_DIR." >&2; exit 1; }

GNO_NEEDS_UPDATE=true
GNOLAND_NEEDS_UPDATE=true
GNOKEY_NEEDS_UPDATE=true
SOURCE_NEEDS_UPDATE=true
[ "$CURRENT_GNO_SHA" = "$GNO_BIN_SHA256" ] && GNO_NEEDS_UPDATE=false
[ "$CURRENT_GNOLAND_SHA" = "$GNOLAND_BIN_SHA256" ] && GNOLAND_NEEDS_UPDATE=false
[ "$CURRENT_GNOKEY_SHA" = "$GNOKEY_BIN_SHA256" ] && GNOKEY_NEEDS_UPDATE=false
[ "$CURRENT_SOURCE_COMMIT" = "$SOURCE_COMMIT" ] && SOURCE_NEEDS_UPDATE=false
if [ -e "$GNOLAND_GENESIS" ]; then
    [ "$CURRENT_GENESIS_SHA" = "$GENESIS_SHA256" ] || { echo "Existing genesis checksum differs from the reviewed gnoland-1 genesis. Update refused." >&2; exit 1; }
else
    GENESIS_WAS_MISSING=true
fi

if ! $GNO_NEEDS_UPDATE && ! $GNOLAND_NEEDS_UPDATE && ! $GNOKEY_NEEDS_UPDATE && ! $SOURCE_NEEDS_UPDATE && ! $GENESIS_WAS_MISSING; then
    echo -e "${GREEN}Already up to date.${RESET}"
    echo "gno:     $ASSET_VERSION ($GNO_BIN_SHA256)"
    echo "gnoland: $ASSET_VERSION ($GNOLAND_BIN_SHA256)"
    echo "gnokey:  $ASSET_VERSION ($GNOKEY_BIN_SHA256)"
    echo "source:   $SOURCE_COMMIT"
    echo "No service restart required."
    exit 0
fi

TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/rollback" "$TMP_DIR/stage-source"
if [ -f "$HOME/.bash_profile" ]; then cp -p "$HOME/.bash_profile" "$TMP_DIR/rollback/bash_profile"; PREVIOUS_PROFILE_PRESENT=true; fi
[ -x "$GNO_BIN" ] && { cp -p "$GNO_BIN" "$TMP_DIR/rollback/gno"; PREVIOUS_GNO_PRESENT=true; }
if [ -x "$GNOLAND_BIN" ]; then cp -p "$GNOLAND_BIN" "$TMP_DIR/rollback/gnoland"; PREVIOUS_GNOLAND_PRESENT=true; fi
if [ -x "$GNOKEY_BIN" ]; then cp -p "$GNOKEY_BIN" "$TMP_DIR/rollback/gnokey"; PREVIOUS_GNOKEY_PRESENT=true; fi
PREVIOUS_SOURCE_COMMIT=$CURRENT_SOURCE_COMMIT

CURRENT_STAGE="stage exact reviewed source"
git -C "$TMP_DIR/stage-source" init -q
git -C "$TMP_DIR/stage-source" remote add origin https://github.com/gnolang/gno.git
git -C "$TMP_DIR/stage-source" fetch --depth 1 origin "$SOURCE_COMMIT" >/dev/null
git -C "$TMP_DIR/stage-source" checkout --detach --force "$SOURCE_COMMIT" >/dev/null
[ "$(git -C "$TMP_DIR/stage-source" rev-parse HEAD)" = "$SOURCE_COMMIT" ]
[ -d "$TMP_DIR/stage-source/misc/deployments/mainnet.gno.land" ] || { echo "Pinned source lacks mainnet deployment files." >&2; exit 1; }

CURRENT_STAGE="stage and verify immutable GHCR OCI binaries"
stage_oci_binary gno "$GNO_IMAGE_REPOSITORY" "$GNO_IMAGE_MANIFEST_DIGEST" "$GNO_BINARY_LAYER_DIGEST" "$GNO_BINARY_PATH" "$GNO_BIN_SHA256" "$TMP_DIR/gno"
verify_reported_version "$TMP_DIR/gno" "gno" gno
stage_oci_binary gnoland "$GNOLAND_IMAGE_REPOSITORY" "$GNOLAND_IMAGE_MANIFEST_DIGEST" "$GNOLAND_BINARY_LAYER_DIGEST" "$GNOLAND_BINARY_PATH" "$GNOLAND_BIN_SHA256" "$TMP_DIR/gnoland"
verify_reported_version "$TMP_DIR/gnoland" "gnoland" gnoland
stage_oci_binary gnokey "$GNOKEY_IMAGE_REPOSITORY" "$GNOKEY_IMAGE_MANIFEST_DIGEST" "$GNOKEY_BINARY_LAYER_DIGEST" "$GNOKEY_BINARY_PATH" "$GNOKEY_BIN_SHA256" "$TMP_DIR/gnokey"
verify_reported_version "$TMP_DIR/gnokey" "gnokey" gnokey

CURRENT_STAGE="stage and verify compressed genesis"
curl -fsSL "$GENESIS_GZ_URL" -o "$TMP_DIR/genesis.json.gz"
printf '%s  %s\n' "$GENESIS_GZ_SHA256" "$TMP_DIR/genesis.json.gz" | sha256sum --check - >/dev/null
gzip -dc "$TMP_DIR/genesis.json.gz" > "$TMP_DIR/genesis.json"
printf '%s  %s\n' "$GENESIS_SHA256" "$TMP_DIR/genesis.json" | sha256sum --check - >/dev/null

if $SOURCE_NEEDS_UPDATE || $GNOLAND_NEEDS_UPDATE; then RESTART_REQUIRED=true; fi

echo -e "${CYAN}Update plan:${RESET}"
echo "  source:  $CURRENT_SOURCE_COMMIT -> $SOURCE_COMMIT"
echo "  gno:     ${CURRENT_GNO_SHA:-missing} -> $GNO_BIN_SHA256"
echo "  gnoland: ${CURRENT_GNOLAND_SHA:-missing} -> $GNOLAND_BIN_SHA256"
echo "  gnokey:  ${CURRENT_GNOKEY_SHA:-missing} -> $GNOKEY_BIN_SHA256"
echo "  restart required: $RESTART_REQUIRED"

CURRENT_STAGE="cut over reviewed runtime"
CUTOVER_STARTED=true
if $RESTART_REQUIRED && $SERVICE_WAS_ACTIVE; then
    sudo systemctl stop "$GNOLAND_MAINNET_SERVICE_NAME"
fi

if $SOURCE_NEEDS_UPDATE; then
    git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "$SOURCE_COMMIT" >/dev/null
    git -C "$GNO_SOURCE_DIR" checkout --detach --force "$SOURCE_COMMIT"
    [ "$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD)" = "$SOURCE_COMMIT" ]
fi
mkdir -p "$(dirname "$GNO_BIN")" "$(dirname "$GNOLAND_BIN")" "$(dirname "$GNOKEY_BIN")" "$GNOLAND_DEPLOYMENT_DIR"
if $GNO_NEEDS_UPDATE; then install -m 0755 "$TMP_DIR/gno" "$GNO_BIN"; fi
if $GNOLAND_NEEDS_UPDATE; then install -m 0755 "$TMP_DIR/gnoland" "$GNOLAND_BIN"; fi
if $GNOKEY_NEEDS_UPDATE; then install -m 0755 "$TMP_DIR/gnokey" "$GNOKEY_BIN"; fi
if $GENESIS_WAS_MISSING; then install -m 0644 "$TMP_DIR/genesis.json" "$GNOLAND_GENESIS"; fi

printf '%s  %s\n' "$GNO_BIN_SHA256" "$GNO_BIN" | sha256sum --check - >/dev/null
printf '%s  %s\n' "$GNOLAND_BIN_SHA256" "$GNOLAND_BIN" | sha256sum --check - >/dev/null
printf '%s  %s\n' "$GNOKEY_BIN_SHA256" "$GNOKEY_BIN" | sha256sum --check - >/dev/null
verify_reported_version "$GNO_BIN" "gno" gno
verify_reported_version "$GNOLAND_BIN" "gnoland" gnoland
verify_reported_version "$GNOKEY_BIN" "gnokey" gnokey
printf '%s  %s\n' "$GENESIS_SHA256" "$GNOLAND_GENESIS" | sha256sum --check - >/dev/null
write_profile_block
export PATH="$HOME/go/bin:$PATH"
hash -r
[ "$(command -v gnoland)" = "$GNOLAND_BIN" ] || { echo "gnoland does not resolve to $GNOLAND_BIN" >&2; false; }
[ "$(command -v gnokey)" = "$GNOKEY_BIN" ] || { echo "gnokey does not resolve to $GNOKEY_BIN" >&2; false; }
[ "$(command -v gno)" = "$GNO_BIN" ] || { echo "gno does not resolve to $GNO_BIN" >&2; false; }

if $RESTART_REQUIRED && $SERVICE_WAS_ACTIVE; then
    CURRENT_STAGE="restart and verify gnoland-1 service"
    sudo systemctl daemon-reload
    sudo systemctl restart "$GNOLAND_MAINNET_SERVICE_NAME"
    wait_for_rpc_health
elif $RESTART_REQUIRED && [ -n "$SERVICE_FILE" ]; then
    echo "Service was inactive before the update and remains inactive; no automatic start was performed."
elif $GNO_NEEDS_UPDATE && $GNOKEY_NEEDS_UPDATE; then
    echo "Only gno and gnokey changed; the running gnoland service was not restarted."
elif $GNO_NEEDS_UPDATE; then
    echo "Only gno changed; the running gnoland service was not restarted."
elif $GNOKEY_NEEDS_UPDATE; then
    echo "Only gnokey changed; the running gnoland service was not restarted."
fi

CUTOVER_STARTED=false
CURRENT_STAGE="complete"
echo -e "${GREEN}Gnoland mainnet update completed safely.${RESET}"
echo "Source: $SOURCE_COMMIT"
echo "Asset version: $ASSET_VERSION"
echo "Verified gno: $GNO_BIN_SHA256"
echo "Verified gnoland: $GNOLAND_BIN_SHA256"
echo "Verified gnokey: $GNOKEY_BIN_SHA256"
