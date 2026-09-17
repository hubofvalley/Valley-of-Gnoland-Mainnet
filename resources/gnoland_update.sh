#!/bin/bash

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'
CURRENT_STAGE="startup"

on_error() {
    local exit_code=$?
    local line_number=${1:-unknown}
    local failed_command=${2:-unknown}
    trap - ERR
    echo -e "${RED}Gno.land gnoland-1 update failed.${RESET}" >&2
    echo "Stage: $CURRENT_STAGE" >&2
    echo "Line: $line_number" >&2
    echo "Command: $failed_command" >&2
    echo "Exit code: $exit_code" >&2
    echo "No success status was reported. Review the error above before retrying." >&2
    exit "$exit_code"
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null || true

readonly CHAIN_ID="gnoland-1"
readonly SOURCE_BRANCH="chain/mainnet"
readonly SOURCE_COMMIT="00417a1be97b9a311d9669ae7aa9585b277ee594"
readonly RELEASE_TAG="chain/mainnet"
readonly RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"
readonly RELEASE_ASSET_BASE_URL="https://github.com/gnolang/gno/releases/download/chain/mainnet"
readonly GENESIS_URL="https://github.com/gnolang/gno/releases/download/chain/mainnet/genesis.json"
readonly GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"
readonly GNOLAND_ASSET="gnoland_linux_amd64"
readonly GNOLAND_ASSET_SHA256="ef393f4e15f433cf966468fa6a8f65f1a1a69dc854f6fe843a3931a6ec0711d3"
readonly GNOKEY_ASSET="gnokey_linux_amd64"
readonly GNOKEY_ASSET_SHA256="86be6aa70bd2c030b50823477e774c75a1f5d63d9387630eb5f39ffa1b62ae14"
readonly PUBLIC_RPC="https://rpc.gno.land"

GNOLAND_MAINNET_SERVICE_NAME=${GNOLAND_MAINNET_SERVICE_NAME:-gnoland}
GNOLAND_MAINNET_SERVICE_NAME=${GNOLAND_MAINNET_SERVICE_NAME%.service}
GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOLAND_DEPLOYMENT_DIR=${GNOLAND_DEPLOYMENT_DIR:-$GNO_SOURCE_DIR/misc/deployments/mainnet.gno.land}
GNOLAND_MAINNET_HOME=${GNOLAND_MAINNET_HOME:-$GNO_SOURCE_DIR/gnoland-data}
GNOLAND_GENESIS=${GNOLAND_GENESIS:-$GNOLAND_DEPLOYMENT_DIR/genesis.json}
if [ "$(realpath -m "$GNOLAND_GENESIS")" != "$(realpath -m "$GNOLAND_DEPLOYMENT_DIR/genesis.json")" ]; then
    echo "Mainnet genesis must be stored under $GNOLAND_DEPLOYMENT_DIR." >&2
    exit 1
fi
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
OS_USER=$(id -un)
SERVICE_FILE=$(systemctl show "$GNOLAND_MAINNET_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)

if [ -n "${SUDO_USER:-}" ]; then
    echo "Run the updater as the node OS user, not with sudo." >&2
    exit 1
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

for instance_path in "$GNO_SOURCE_DIR" "$GNOLAND_DEPLOYMENT_DIR" "$GNOLAND_MAINNET_HOME" "$GNOLAND_GENESIS" "$GNOLAND_BIN" "$GNOKEY_BIN"; do
    if ! path_is_under_home "$instance_path"; then
        echo "Unsafe instance path outside $HOME: $instance_path" >&2
        exit 1
    fi
done

if [[ ! "$GNOLAND_MAINNET_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then
    echo "Invalid Gnoland service name: $GNOLAND_MAINNET_SERVICE_NAME" >&2
    exit 1
fi

if [ -n "$SERVICE_FILE" ]; then
    if [ ! -f "$SERVICE_FILE" ]; then
        echo "Cannot inspect existing service: $SERVICE_FILE" >&2
        exit 1
    fi
    UNIT_USER=$(sed -n 's/^User=//p' "$SERVICE_FILE" | tail -n 1)
    UNIT_WORKDIR=$(sed -n 's/^WorkingDirectory=//p' "$SERVICE_FILE" | tail -n 1)
    if [ "$UNIT_USER" != "$OS_USER" ] || [ "$UNIT_WORKDIR" != "$GNO_SOURCE_DIR" ]; then
        echo "$GNOLAND_MAINNET_SERVICE_NAME.service belongs to another instance." >&2
        exit 1
    fi
    if ! grep -Fq -- "--chainid $CHAIN_ID" "$SERVICE_FILE"; then
        echo "Update blocked: this service is not configured for $CHAIN_ID." >&2
        echo "Use Deploy/Re-deploy to configure the pinned mainnet release first." >&2
        exit 1
    fi
    if ! grep -Fq -- "--genesis $GNOLAND_GENESIS" "$SERVICE_FILE" || \
        ! grep -Fq -- "--skip-genesis-sig-verification" "$SERVICE_FILE"; then
        echo "Update blocked: the service does not reference the verified mainnet deployment genesis and startup flags." >&2
        echo "Use Deploy/Re-deploy to configure the pinned mainnet release first." >&2
        exit 1
    fi
fi

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "The published mainnet assets are only verified for Linux amd64." >&2
    exit 1
fi
if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 || ! command -v sha256sum >/dev/null 2>&1; then
    echo "curl, git, and sha256sum are required for a verified mainnet update." >&2
    exit 1
fi
if [ ! -d "$GNO_SOURCE_DIR/.git" ]; then
    echo "Gno source checkout is missing at $GNO_SOURCE_DIR; run the installer first." >&2
    exit 1
fi

if git -C "$GNO_SOURCE_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$GNO_SOURCE_DIR" remote set-url origin https://github.com/gnolang/gno.git
else
    git -C "$GNO_SOURCE_DIR" remote add origin https://github.com/gnolang/gno.git
fi

CURRENT_STAGE="verify pinned mainnet source"
release_tag_commit=$(git -C "$GNO_SOURCE_DIR" ls-remote --refs origin "refs/tags/$RELEASE_TAG" | awk 'NR == 1 {print $1}' || true)
if [ "$release_tag_commit" != "$RELEASE_COMMIT" ]; then
    echo "The $RELEASE_TAG tag does not match the pinned release commit." >&2
    echo "Expected: $RELEASE_COMMIT" >&2
    echo "Observed: ${release_tag_commit:-unavailable}" >&2
    exit 1
fi
git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "refs/heads/$SOURCE_BRANCH"
if [ "$(git -C "$GNO_SOURCE_DIR" rev-parse FETCH_HEAD)" != "$SOURCE_COMMIT" ]; then
    echo "The $SOURCE_BRANCH tip is not the pinned mainnet source commit." >&2
    echo "Expected: $SOURCE_COMMIT" >&2
    echo "Observed: $(git -C "$GNO_SOURCE_DIR" rev-parse FETCH_HEAD 2>/dev/null || echo unavailable)" >&2
    exit 1
fi
git -C "$GNO_SOURCE_DIR" checkout --detach --force "$SOURCE_COMMIT"
if [ "$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD)" != "$SOURCE_COMMIT" ]; then
    echo "Unexpected Gno source commit at $GNO_SOURCE_DIR." >&2
    exit 1
fi
if [ ! -d "$GNOLAND_DEPLOYMENT_DIR" ]; then
    echo "Mainnet deployment path is missing from the pinned source: $GNOLAND_DEPLOYMENT_DIR" >&2
    exit 1
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

CURRENT_STAGE="download and verify mainnet genesis"
mkdir -p "$GNOLAND_DEPLOYMENT_DIR"
curl -fsSL "$GENESIS_URL" -o "$TMP_DIR/genesis.json"
printf '%s  %s\n' "$GENESIS_SHA256" "$TMP_DIR/genesis.json" | sha256sum --check - >/dev/null
echo -e "${GREEN}Verified mainnet genesis SHA-256: $GENESIS_SHA256${RESET}"
if [ -e "$GNOLAND_GENESIS" ]; then
    printf '%s  %s\n' "$GENESIS_SHA256" "$GNOLAND_GENESIS" | sha256sum --check - >/dev/null
else
    install -m 0644 "$TMP_DIR/genesis.json" "$GNOLAND_GENESIS"
fi

CURRENT_STAGE="install verified mainnet binaries"
mkdir -p "$(dirname "$GNOLAND_BIN")" "$(dirname "$GNOKEY_BIN")"
if [ -n "$SERVICE_FILE" ]; then
    sudo systemctl stop "$GNOLAND_MAINNET_SERVICE_NAME"
fi
install -m 0755 "$TMP_DIR/gnoland" "$GNOLAND_BIN"
install -m 0755 "$TMP_DIR/gnokey" "$GNOKEY_BIN"
if [ ! -x "$GNOLAND_BIN" ] || [ ! -x "$GNOKEY_BIN" ]; then
    echo "Verified mainnet assets were not installed as executable commands." >&2
    exit 1
fi
printf '%s  %s\n' "$GNOLAND_ASSET_SHA256" "$GNOLAND_BIN" | sha256sum --check - >/dev/null
printf '%s  %s\n' "$GNOKEY_ASSET_SHA256" "$GNOKEY_BIN" | sha256sum --check - >/dev/null

# Keep the runtime profile aligned with the checked-out mainnet deployment.
sed -i '/^export GNOLAND_CHAIN_ID=/d;/^export GNOLAND_MAINNET_HOME=/d;/^export GNOLAND_DEPLOYMENT_DIR=/d;/^export GNOLAND_GENESIS=/d;/^export GNOKEY_HOME=/d;/^export GNO_SOURCE_DIR=/d;/^export GNOROOT=/d;/^export GNOLAND_PUBLIC_REMOTE=/d;/go\/bin/d' "$HOME/.bash_profile" 2>/dev/null || true
{
    echo "export GNOLAND_CHAIN_ID=\"$CHAIN_ID\""
    echo "export GNOLAND_MAINNET_HOME=\"$GNOLAND_MAINNET_HOME\""
    echo "export GNOLAND_DEPLOYMENT_DIR=\"$GNOLAND_DEPLOYMENT_DIR\""
    echo "export GNOLAND_GENESIS=\"$GNOLAND_GENESIS\""
    echo "export GNO_SOURCE_DIR=\"$GNO_SOURCE_DIR\""
    echo "export GNOROOT=\"$GNOROOT\""
    echo "export GNOLAND_PUBLIC_REMOTE=\"$PUBLIC_RPC\""
    echo 'export PATH="$HOME/go/bin:$PATH"'
} >> "$HOME/.bash_profile"

export PATH="$HOME/go/bin:$PATH"
hash -r
if [ "$(command -v gnoland)" != "$GNOLAND_BIN" ] || [ "$(command -v gnokey)" != "$GNOKEY_BIN" ]; then
    echo "Per-user commands do not resolve to $HOME/go/bin." >&2
    exit 1
fi

if [ -n "$SERVICE_FILE" ]; then
    sudo systemctl daemon-reload
    CURRENT_STAGE="restart gnoland-1 service"
    sudo systemctl restart "$GNOLAND_MAINNET_SERVICE_NAME"
    sudo systemctl status "$GNOLAND_MAINNET_SERVICE_NAME" --no-pager -l || true
else
    echo "No existing service was found; verified binaries and genesis were installed only."
fi

echo -e "${GREEN}Updated gnoland-1 from ${SOURCE_BRANCH}@${SOURCE_COMMIT}.${RESET}"
echo "Release tag: $RELEASE_TAG ($RELEASE_COMMIT)"
echo "Verified genesis: $GENESIS_SHA256"
echo "Verified gnoland: $GNOLAND_ASSET_SHA256"
echo "Verified gnokey: $GNOKEY_ASSET_SHA256"
