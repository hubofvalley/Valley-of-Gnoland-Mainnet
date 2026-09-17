#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
ORANGE='\033[38;5;214m'
RESET='\033[0m'

readonly GNOLAND_CHAIN_ID_DEFAULT="gnoland-1"
readonly GNOLAND_PUBLIC_RPC_DEFAULT="https://rpc.gno.land"
readonly GNOLAND_SOURCE_BRANCH="chain/mainnet"
readonly GNOLAND_SOURCE_COMMIT="00417a1be97b9a311d9669ae7aa9585b277ee594"
readonly GNOLAND_RELEASE_TAG="chain/mainnet"
readonly GNOLAND_RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"
readonly GNOLAND_ASSET_VERSION="chain/mainnet.3435+139a63fe6"
readonly GNOLAND_GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"
readonly GNOLAND_BIN_SHA256="ef393f4e15f433cf966468fa6a8f65f1a1a69dc854f6fe843a3931a6ec0711d3"
readonly GNOKEY_BIN_SHA256="86be6aa70bd2c030b50823477e774c75a1f5d63d9387630eb5f39ffa1b62ae14"
readonly OFFICIAL_GNOLAND_PEERS="g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656"
readonly GNOLAND_ACTIVE_REALM="r/sys/validators/v0"
readonly GNOLAND_VALOPER_REALM="r/gnops/valopers"
readonly VALOPER_GAS_FEE="1000000ugnot"
readonly VALOPER_GAS_WANTED=50000000
readonly VALLEY_RUNTIME_REF="35196270ea330dde87b3bc4baf18686e16a2cd19"
readonly NODE_DOCTOR_RELATIVE_PATH="resources/gnoland_node_doctor.sh"
readonly PROFILE_BEGIN="# >>> GRAND VALLEY GNOLAND MAINNET >>>"
readonly PROFILE_END="# <<< GRAND VALLEY GNOLAND MAINNET <<<"

run_node_doctor_script() {
    local script_dir script_file exit_code

    if ! script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd); then
        script_dir=""
    fi
    if [ -n "$script_dir" ] && [ -f "$script_dir/gnoland_node_doctor.sh" ]; then
        bash "$script_dir/gnoland_node_doctor.sh" "$@"
        return $?
    fi

    if ! command -v curl >/dev/null 2>&1 || [[ ! "$VALLEY_RUNTIME_REF" =~ ^[0-9a-f]{40}$ ]] || [ "$VALLEY_RUNTIME_REF" = "0000000000000000000000000000000000000000" ]; then
        echo -e "${RED}Node Doctor is unavailable: no local helper or verified remote pin was found.${RESET}" >&2
        return 2
    fi

    script_file=$(mktemp)
    if ! curl -fsSL "https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Mainnet/35196270ea330dde87b3bc4baf18686e16a2cd19/${NODE_DOCTOR_RELATIVE_PATH}" -o "$script_file"; then
        rm -f "$script_file"
        echo -e "${RED}Failed to download the Node Doctor from pinned commit ${VALLEY_RUNTIME_REF}. Nothing was executed.${RESET}" >&2
        return 2
    fi
    chmod +x "$script_file"
    GNOLAND_NODE_DOCTOR_REF="$VALLEY_RUNTIME_REF" bash "$script_file" "$@"
    exit_code=$?
    rm -f "$script_file"
    return "$exit_code"
}

# Non-interactive command mode intentionally runs before the profile and banner.
if [ "${1:-}" = "doctor" ] || [ "${1:-}" = "node-doctor" ]; then
    shift
    run_node_doctor_script "$@"
    exit $?
fi

# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null || true

OS_USER=$(id -un)

if [ -n "${SUDO_USER:-}" ]; then
    echo -e "${RED}Run Valley of Gnoland as the node OS user, not with sudo.${RESET}" >&2
    echo "The tool requests sudo only where system access is required." >&2
    exit 1
fi

GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOLAND_DEPLOYMENT_DIR=${GNOLAND_DEPLOYMENT_DIR:-$GNO_SOURCE_DIR/misc/deployments/mainnet.gno.land}
if [ -z "${GNOLAND_MAINNET_HOME:-}" ] || [ "$GNOLAND_MAINNET_HOME" = "$HOME/.gnoland" ] || [ "$GNOLAND_MAINNET_HOME" = "$HOME/gnoland-data" ]; then
    GNOLAND_MAINNET_HOME="$GNO_SOURCE_DIR/gnoland-data"
fi
GNOKEY_HOME=${GNOKEY_HOME:-$HOME/.config/gno}
GNOLAND_GENESIS="$GNOLAND_DEPLOYMENT_DIR/genesis.json"
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
GNOLAND_CHAIN_ID=${GNOLAND_CHAIN_ID:-$GNOLAND_CHAIN_ID_DEFAULT}
GNOLAND_PUBLIC_REMOTE=${GNOLAND_PUBLIC_REMOTE:-$GNOLAND_PUBLIC_RPC_DEFAULT}
GNOLAND_REMOTE=${GNOLAND_REMOTE:-}
GNOLAND_PERSISTENT_PEERS="$OFFICIAL_GNOLAND_PEERS"
export GNOROOT
export PATH="$HOME/go/bin:$PATH"

while :; do
    if [ -z "${GNOLAND_MAINNET_SERVICE_NAME:-}" ]; then
        echo -e "${YELLOW}Service name configuration not found.${RESET}"
        read -r -p "Enter Service Name (default 'gnoland'): " INPUT_SVC
        GNOLAND_MAINNET_SERVICE_NAME=${INPUT_SVC:-gnoland}
    fi
    GNOLAND_MAINNET_SERVICE_NAME=${GNOLAND_MAINNET_SERVICE_NAME%.service}
    if [[ "$GNOLAND_MAINNET_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then
        break
    fi
    echo -e "${RED}Service name must start with a letter or number and may contain _, ., @, and -.${RESET}"
    GNOLAND_MAINNET_SERVICE_NAME=""
done

export GNOLAND_MAINNET_SERVICE_NAME

service_belongs_to_current_instance() {
    local service_file unit_user unit_workdir
    service_file=$(systemctl show "$GNOLAND_MAINNET_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
    [ -n "$service_file" ] || return 0
    if [ ! -f "$service_file" ]; then
        echo -e "${RED}Cannot inspect existing service: $service_file${RESET}" >&2
        return 1
    fi
    unit_user=$(sed -n 's/^User=//p' "$service_file" | tail -n 1)
    unit_workdir=$(sed -n 's/^WorkingDirectory=//p' "$service_file" | tail -n 1)
    if [ "$unit_user" != "$OS_USER" ] || [ "$unit_workdir" != "$GNO_SOURCE_DIR" ]; then
        echo -e "${RED}${GNOLAND_MAINNET_SERVICE_NAME}.service belongs to another instance.${RESET}" >&2
        echo "Existing User=${unit_user:-unknown}, WorkingDirectory=${unit_workdir:-unknown}" >&2
        echo "Current User=$OS_USER, WorkingDirectory=$GNO_SOURCE_DIR" >&2
        return 1
    fi
}

LOGO="
 __      __     _ _
 \ \    / /    | | |
  \ \  / /__ _ | | |  ___  _   _
   \ \/ // _\` || | | / _ \| | | |
    \  /| (_| || | ||  __/| |_| |
     \/  \__,_||_|_| \___| \__, |
                             __/ |
                            |___/
          ___   __
         / _ \ / _|
        | (_) | |_
         \___/|_|
   _____             _                 _
  / ____|           | |               | |
 | |  __ _ __   ___ | | __ _ _ __   __| |
 | | |_ | '_ \ / _ \| |/ _\` | '_ \ / _\` |
 | |__| | | | | (_) | | (_| | | | | (_| |
  \_____|_| |_|\___/|_|\__,_|_| |_|\__,_|
"

INTRO="
Valley of Gnoland by ${ORANGE}Grand Valley${RESET}

${GREEN}Gno.land gnoland-1 Node${RESET}
- network: ${CYAN}gnoland-1${RESET}
- source branch: ${CYAN}${GNOLAND_SOURCE_BRANCH}${RESET} @ ${CYAN}${GNOLAND_SOURCE_COMMIT}${RESET}
- release tag: ${CYAN}${GNOLAND_RELEASE_TAG}${RESET} @ ${CYAN}${GNOLAND_RELEASE_COMMIT}${RESET}
- asset version: ${CYAN}${GNOLAND_ASSET_VERSION}${RESET}
- source directory: ${CYAN}${GNO_SOURCE_DIR}${RESET}
- mainnet deployment: ${CYAN}${GNOLAND_DEPLOYMENT_DIR}${RESET}
- node directory: ${CYAN}${GNOLAND_MAINNET_HOME}${RESET}
- operator keyring: ${CYAN}${GNOKEY_HOME}${RESET}
- binaries: ${CYAN}$HOME/go/bin/gnoland, $HOME/go/bin/gnokey${RESET}
- service file: ${CYAN}${GNOLAND_MAINNET_SERVICE_NAME}.service${RESET}
- release assets: ${CYAN}verified Linux amd64 binaries${RESET}
- hardware requirements: ${CYAN}not asserted by this Valley${RESET}
"

PRIVACY_SAFETY_STATEMENT="
${YELLOW}Privacy and Safety Statement${RESET}

${GREEN}Local operation${RESET}
- This script performs its operations locally and does not send keys or mnemonics to Grand Valley.

${GREEN}Key safety${RESET}
- Keep operator mnemonics and node secrets offline. Review every transaction or destructive action yourself.

${GREEN}Scope${RESET}
- This Valley installs and inspects a node. Option 2c can broadcast a validator-candidate registration only after explicit operator confirmation.
- Candidate registration does not grant validator admission; GovDAO approval is still required for the active set.
"

ENDPOINTS="${GREEN}
Gno.land useful links:${RESET}
- Web: ${BLUE}https://gno.land${RESET}
- RPC / comparison RPC: ${BLUE}https://rpc.gno.land${RESET}
- Faucet: ${CYAN}none - mainnet has no public faucet${RESET}
- Gno source: ${BLUE}https://github.com/gnolang/gno${RESET}
- Source branch: ${BLUE}https://github.com/gnolang/gno/tree/chain/mainnet${RESET}
- Mainnet deployment: ${BLUE}https://github.com/gnolang/gno/tree/chain/mainnet/misc/deployments/mainnet.gno.land${RESET}
- Release: ${BLUE}https://github.com/gnolang/gno/releases/tag/chain%2Fmainnet${RESET}

${GREEN}Network facts:${RESET}
- Chain ID: ${CYAN}gnoland-1${RESET}
- Official persistent peers: ${CYAN}${OFFICIAL_GNOLAND_PEERS}${RESET}
- Release genesis SHA256: ${CYAN}${GNOLAND_GENESIS_SHA256}${RESET}
- gnoland Linux amd64 SHA256: ${CYAN}${GNOLAND_BIN_SHA256}${RESET}
- gnokey Linux amd64 SHA256: ${CYAN}${GNOKEY_BIN_SHA256}${RESET}
- Valoper candidate realm: ${CYAN}${GNOLAND_VALOPER_REALM}${RESET}
- Active validator realm: ${CYAN}${GNOLAND_ACTIVE_REALM}${RESET}

${GREEN}Connect with Grand Valley:${RESET}
- X: ${BLUE}https://x.com/bacvalley${RESET}
- GitHub: ${BLUE}https://github.com/hubofvalley${RESET}
- Email: ${BLUE}letsbuidltogether@grandvalleys.com${RESET}
"

echo -e "$LOGO"
echo -e "$PRIVACY_SAFETY_STATEMENT"
echo -e "\n${YELLOW}Press Enter to continue...${RESET}"
read -r

echo -e "$INTRO"
echo -e "$ENDPOINTS"
echo -e "\n${YELLOW}Press Enter to continue${RESET}"
read -r

write_valley_profile_block() {
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
            /^export GNO_SOURCE_DIR=/ {next}
            /^export GNOROOT=/ {next}
            {print}
        ' "$profile" > "$tmp"
    fi
    cat >> "$tmp" <<EOF_PROFILE
$PROFILE_BEGIN
export GNOLAND_CHAIN_ID="$GNOLAND_CHAIN_ID_DEFAULT"
export GNOLAND_MAINNET_HOME="$GNOLAND_MAINNET_HOME"
export GNOLAND_MAINNET_SERVICE_NAME="$GNOLAND_MAINNET_SERVICE_NAME"
export GNOLAND_DEPLOYMENT_DIR="$GNOLAND_DEPLOYMENT_DIR"
export GNOLAND_GENESIS="$GNOLAND_GENESIS"
export GNOKEY_HOME="$GNOKEY_HOME"
export GNO_SOURCE_DIR="$GNO_SOURCE_DIR"
export GNOROOT="$GNOROOT"
export GNOLAND_PUBLIC_REMOTE="$GNOLAND_PUBLIC_RPC_DEFAULT"
export PATH="\$HOME/go/bin:\$PATH"
$PROFILE_END
EOF_PROFILE
    mv "$tmp" "$profile"
}

remove_valley_profile_block() {
    local profile="$HOME/.bash_profile" tmp
    [ -f "$profile" ] || return 0
    tmp=$(mktemp)
    awk -v begin="$PROFILE_BEGIN" -v end="$PROFILE_END" '
        $0 == begin {skip=1; next}
        $0 == end {skip=0; next}
        skip {next}
        /^export GNOLAND_CHAIN_ID=/ {next}
        /^export GNOLAND_MAINNET_HOME=/ {next}
        /^export GNOLAND_MAINNET_SERVICE_NAME=/ {next}
        /^export GNOLAND_DEPLOYMENT_DIR=/ {next}
        /^export GNOLAND_GENESIS=/ {next}
        /^export GNOLAND_OPERATOR_KEY=/ {next}
        /^export GNOLAND_REMOTE=/ {next}
        /^export GNOLAND_PUBLIC_REMOTE=/ {next}
        /^export GNOKEY_HOME=/ {next}
        /^export GNO_SOURCE_DIR=/ {next}
        /^export GNOROOT=/ {next}
        {print}
    ' "$profile" > "$tmp"
    mv "$tmp" "$profile"
}

write_valley_profile_block
# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null || true

# Tests and local runs use this function from the checked-out repository. A
# remote fallback is intentionally absent because this checkout has no verified
# immutable helper commit.
run_repository_script() {
    local relative_path=$1 script_dir script_file exit_code
    if ! script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd); then
        script_dir=""
    fi
    if [ -n "$script_dir" ] && [ -f "$script_dir/../$relative_path" ]; then
        bash "$script_dir/../$relative_path"
        return $?
    fi

    if ! command -v curl >/dev/null 2>&1 || [[ ! "$VALLEY_RUNTIME_REF" =~ ^[0-9a-f]{40}$ ]] || [ "$VALLEY_RUNTIME_REF" = "0000000000000000000000000000000000000000" ]; then
        echo -e "${RED}Cannot run ${relative_path}: local helper not found and no verified remote pin is configured.${RESET}" >&2
        return 2
    fi

    script_file=$(mktemp)
    if ! curl -fsSL "https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Mainnet/35196270ea330dde87b3bc4baf18686e16a2cd19/${relative_path}" -o "$script_file"; then
        rm -f "$script_file"
        echo -e "${RED}Failed to download ${relative_path} from pinned commit ${VALLEY_RUNTIME_REF}. Nothing was executed.${RESET}" >&2
        return 2
    fi
    chmod +x "$script_file"
    bash "$script_file"
    exit_code=$?
    rm -f "$script_file"
    return "$exit_code"
}

function gnokey_cmd() {
    gnokey -home "$GNOKEY_HOME" -remote "$GNOLAND_PUBLIC_REMOTE" "$@"
}

function operator_key_exists() {
    gnokey -home "$GNOKEY_HOME" list 2>/dev/null |
        awk -v key="$1" '$2 == key { found=1 } END { exit !found }'
}

function operator_key_address() {
    gnokey -home "$GNOKEY_HOME" list 2>/dev/null |
        awk -v key="$1" '$2 == key && $5 == "addr:" { print $6; exit }'
}

function get_valoper_register_fee() {
    local fee_output fee
    fee_output=$(gnokey_cmd query vm/qeval -data 'gno.land/r/sys/params.GetValoperRegisterFee()' 2>/dev/null) || return 1
    fee=$(printf '%s\n' "$fee_output" | grep -Eo '[0-9]+[[:space:]]+uint64' | head -n 1 | awk '{print $1}')
    [[ "$fee" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$fee"
}


function get_valoper_rotation_fee() {
    local fee_output fee
    fee_output=$(gnokey_cmd query vm/qeval -data 'gno.land/r/sys/params.GetValoperRotationFee()' 2>/dev/null) || return 1
    fee=$(printf '%s\n' "$fee_output" | grep -Eo '[0-9]+[[:space:]]+uint64' | head -n 1 | awk '{print $1}')
    [[ "$fee" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$fee"
}

function get_valoper_rotation_period_blocks() {
    local period_output period
    period_output=$(gnokey_cmd query vm/qeval -data 'gno.land/r/sys/params.GetValoperRotationPeriodBlocks()' 2>/dev/null) || return 1
    period=$(printf '%s\n' "$period_output" | grep -Eo '[0-9]+[[:space:]]+int64' | head -n 1 | awk '{print $1}')
    [[ "$period" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$period"
}

function format_ugnot_balance() {
    local raw=$1 amount
    amount=$(printf '%s\n' "$raw" | grep -Eo '[0-9]+ugnot' | head -n 1 | sed 's/ugnot$//')
    if [[ "$amount" =~ ^[0-9]+$ ]]; then
        awk -v amount="$amount" 'BEGIN { printf "%.6f GNOT (%s ugnot)\n", amount / 1000000, amount }'
    else
        printf '%s\n' "unavailable"
    fi
}

function valoper_profile_output() {
    gnokey_cmd query vm/qrender -data "gno.land/$GNOLAND_VALOPER_REALM:$1" 2>&1
}

function active_valset_output() {
    gnokey_cmd query vm/qrender -data "gno.land/$GNOLAND_ACTIVE_REALM:" 2>&1
}

function profile_signing_pubkey() {
    printf '%s\n' "$1" | grep -Eo 'Signing PubKey: gpub1[0-9a-z]+' | head -n 1 | awk '{print $3}'
}

function profile_signing_address() {
    printf '%s\n' "$1" | grep -Eo 'Signing Address: g1[0-9a-z]+' | head -n 1 | awk '{print $3}'
}

VALOPER_PROFILE_QUERY_STATUS="UNKNOWN"
VALOPER_PROFILE_QUERY_OUTPUT=""
ACTIVE_VALIDATOR_QUERY_STATUS="UNKNOWN"

function query_valoper_profile_status() {
    local operator_addr=$1 output
    VALOPER_PROFILE_QUERY_STATUS="UNKNOWN"
    VALOPER_PROFILE_QUERY_OUTPUT=""

    if ! output=$(valoper_profile_output "$operator_addr"); then
        VALOPER_PROFILE_QUERY_OUTPUT=$output
        return 1
    fi
    VALOPER_PROFILE_QUERY_OUTPUT=$output

    if printf '%s\n' "$output" | grep -Fq "unknown address $operator_addr"; then
        VALOPER_PROFILE_QUERY_STATUS="NO"
        return 0
    fi
    if printf '%s\n' "$output" | grep -Fq "Valoper's details:" &&
        [ -n "$(profile_signing_pubkey "$output")" ]; then
        VALOPER_PROFILE_QUERY_STATUS="YES"
        return 0
    fi

    return 1
}

function query_active_validator_status() {
    local signing_addr=$1 output
    ACTIVE_VALIDATOR_QUERY_STATUS="UNKNOWN"

    [ -n "$signing_addr" ] || return 1
    if ! output=$(active_valset_output); then
        return 1
    fi

    if ! printf '%s\n' "$output" | grep -Fq '## Valset at height'; then
        return 1
    fi
    if printf '%s\n' "$output" | grep -Fq ": $signing_addr ("; then
        ACTIVE_VALIDATOR_QUERY_STATUS="YES"
    else
        ACTIVE_VALIDATOR_QUERY_STATUS="NO"
    fi
    return 0
}

function resolve_operator_target() {
    local target=$1
    if [[ "$target" =~ ^g1[0-9a-z]+$ ]]; then
        printf '%s\n' "$target"
        return 0
    fi
    operator_key_exists "$target" || return 1
    operator_key_address "$target"
}

function broadcast_valoper_call() {
    local key_name=$1 func_name=$2 confirm_word=$3
    shift 3
    local -a call_args=()
    local arg confirm tx_status

    for arg in "$@"; do
        call_args+=( -args "$arg" )
    done

    echo -e "\n${YELLOW}Transaction preview:${RESET}"
    printf 'gnokey maketx call \\\n'
    printf '  --pkgpath gno.land/%s \\\n' "$GNOLAND_VALOPER_REALM"
    printf '  --func %s \\\n' "$func_name"
    for arg in "$@"; do
        printf '  --args %q \\\n' "$arg"
    done
    printf '  --gas-fee %s --gas-wanted %s \\\n' "$VALOPER_GAS_FEE" "$VALOPER_GAS_WANTED"
    printf '  --chainid %s --remote %s --broadcast %q\n' "$GNOLAND_CHAIN_ID" "$GNOLAND_PUBLIC_REMOTE" "$key_name"

    if [ "$confirm_word" = "yes" ]; then
        read -r -p $'\n\e[33mBroadcast this transaction? (yes/no): \e[0m' confirm
        [[ "${confirm,,}" == "yes" ]] || { echo "Cancelled."; return 1; }
    else
        read -r -p "Type '$confirm_word' to broadcast: " confirm
        [ "$confirm" = "$confirm_word" ] || { echo "Cancelled."; return 1; }
    fi

    gnokey_cmd maketx call \
        -pkgpath "gno.land/$GNOLAND_VALOPER_REALM" \
        -func "$func_name" \
        "${call_args[@]}" \
        -gas-fee "$VALOPER_GAS_FEE" \
        -gas-wanted "$VALOPER_GAS_WANTED" \
        -chainid "$GNOLAND_CHAIN_ID" \
        -broadcast \
        "$key_name"
    tx_status=$?
    if [ "$tx_status" -ne 0 ]; then
        echo -e "${RED}Transaction failed. Review the gnokey output above.${RESET}"
        return "$tx_status"
    fi
    echo -e "${GREEN}Transaction broadcast succeeded.${RESET}"
    return 0
}

function get_rpc_port_from_remote() {
    local remote="${GNOLAND_REMOTE:-}"
    if [[ "$remote" =~ :([0-9]+)/?$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

function get_local_rpc_port() {
    local cfg="$GNOLAND_MAINNET_HOME/config/config.toml" port
    if [ -f "$cfg" ]; then
        port=$(awk -F: '
            /^[[:space:]]*\[rpc\][[:space:]]*$/ {in_rpc=1; next}
            /^[[:space:]]*\[/ {in_rpc=0}
            in_rpc && /^[[:space:]]*laddr = "tcp:\/\// {
                gsub(/".*/, "", $NF)
                print $NF
                exit
            }
        ' "$cfg")
        if [ -z "$port" ]; then
            port=$(awk -F: '/laddr = "tcp:\/\/127\.0\.0\.1:/ {gsub(/".*/, "", $3); print $3; exit}' "$cfg")
        fi
        if [ -n "$port" ]; then
            echo "$port"
            return
        fi
    fi
    get_rpc_port_from_remote
}

function get_local_rpc_url() {
    local port
    port=$(get_local_rpc_port)
    if [ -n "$port" ]; then
        echo "http://127.0.0.1:${port}"
    else
        echo "${GNOLAND_REMOTE:-http://127.0.0.1:${GNOLAND_PORT:-26}657}"
    fi
}

function get_local_status_json() {
    local rpc_url
    rpc_url=$(get_local_rpc_url)
    curl -m 5 -fsS "${rpc_url%/}/status" 2>/dev/null
}

function get_network_height() {
    curl -m 5 -fsS "$GNOLAND_PUBLIC_REMOTE/status" 2>/dev/null | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null
}

function get_local_net_info_json() {
    local rpc_url
    rpc_url=$(get_local_rpc_url)
    curl -m 5 -fsS "${rpc_url%/}/net_info" 2>/dev/null
}

function prompt_back_or_continue() {
    read -r -p "Press Enter to continue or type 'back' to go back to the menu: " user_choice
    if [[ ${user_choice,,} == "back" ]]; then
        menu
        return 1
    fi
    return 0
}

function deploy_gnoland_node() {
    clear
    echo -e "${RED}IMPORTANT DISCLAIMER AND TERMS${RESET}"
    echo -e "${YELLOW}Network:${RESET} ${CYAN}gnoland-1${RESET}"
    echo -e "${YELLOW}Service:${RESET} ${CYAN}${GNOLAND_MAINNET_SERVICE_NAME}.service${RESET}"
    echo -e "${YELLOW}Directory:${RESET} ${CYAN}$GNOLAND_MAINNET_HOME${RESET}"
    echo -e "${YELLOW}Default ports:${RESET} P2P ${CYAN}26656${RESET}, RPC ${CYAN}26657${RESET}, ABCI ${CYAN}26658${RESET}; the installer remaps local listeners with the chosen two-digit prefix."
    echo -e "${YELLOW}Install/update method:${RESET} exact reviewed source commit plus verified Linux amd64 release assets."
    echo -e "${YELLOW}Install safety:${RESET} all artifacts are staged first; a persistent backup is optional, while existing validator/node secrets are preserved on a recognized safe reinstall."
    echo -e "${RED}Installation rebuilds Valley node database/config only after staging and explicit confirmation.${RESET}"
    echo
    echo "This installs a Gnoland node. It does not prove validator admission."
    read -r -p $'\n\e[33mDo you want to proceed with installation? (yes/no): \e[0m' confirm
    if [[ "${confirm,,}" != "yes" ]]; then
        echo -e "${RED}Installation cancelled.${RESET}"
        menu
        return
    fi
    run_repository_script "resources/gnoland_node_install.sh" || true
    menu
}

function update_gnoland_binary() {
    echo -e "${YELLOW}Transactional update: compare installed state, stage and verify artifacts, then cut over only if needed.${RESET}"
    echo -e "${YELLOW}Target source commit: ${GNOLAND_SOURCE_COMMIT}${RESET}"
    echo -e "${YELLOW}Target asset version: ${GNOLAND_ASSET_VERSION}${RESET}"
    echo "If the reviewed target is already installed, no service restart is performed."
    echo "If a running node-runtime update fails its gnoland-1 RPC health gate, the previous source/binaries are restored."
    if ! prompt_back_or_continue; then
        return
    fi
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Update blocked to protect the other instance.${RESET}"
        menu
        return
    fi
    run_repository_script "resources/gnoland_update.sh" || true
    menu
}

function apply_snapshot() {
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Snapshot application blocked to protect the other instance.${RESET}"
        menu
        return
    fi
    run_repository_script "resources/apply_snapshot.sh" || true
    menu
}

function add_peers() {
    echo "Select an option:"
    echo "1. Add peers manually"
    echo "2. Reset to the official gnoland-1 persistent peers"
    echo "3. Back"
    read -r -p "Enter your choice (1, 2, or 3): " choice

    if [ "$choice" = "3" ]; then
        menu
        return
    fi

    local cfg="$GNOLAND_MAINNET_HOME/config/config.toml"
    if [ ! -f "$cfg" ]; then
        echo -e "${RED}config.toml not found at $cfg. Deploy the node first.${RESET}"
        menu
        return
    fi

    case $choice in
        1)
            read -r -p "Enter peers (comma-separated id@host:port): " peers
            echo "You entered: $peers"
            read -r -p "Proceed? (yes/no): " confirm
            if [[ "${confirm,,}" == "yes" ]]; then
                gnoland config set -config-path "$cfg" p2p.persistent_peers "$peers"
                echo "Peers updated."
            fi
            ;;
        2)
            gnoland config set -config-path "$cfg" p2p.seeds ""
            gnoland config set -config-path "$cfg" p2p.persistent_peers "$GNOLAND_PERSISTENT_PEERS"
            echo "Official gnoland-1 persistent peers restored."
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
    echo -e "\n${YELLOW}Restart node to apply changes.${RESET}"
    menu
}

function show_node_status() {
    local rpc_url status_json net_info_json node_height catching_up network_height latest_block_time validator_address peer_count service_state disk_line block_diff sync_status
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Status blocked: selected service belongs to another instance.${RESET}"
        menu
        return
    fi
    rpc_url=$(get_local_rpc_url)
    status_json=$(get_local_status_json)
    net_info_json=$(get_local_net_info_json)
    service_state=$(systemctl is-active "$GNOLAND_MAINNET_SERVICE_NAME" 2>/dev/null || true)
    [ -z "$service_state" ] && service_state="unknown"
    disk_line=$(df -h "$GNOLAND_MAINNET_HOME" 2>/dev/null | awk 'NR==2 {print $4 " free of " $2 " (" $5 " used)"}')
    [ -z "$disk_line" ] && disk_line="unavailable for $GNOLAND_MAINNET_HOME"

    echo -e "${CYAN}Operational health summary${RESET}"
    echo "Service: ${GNOLAND_MAINNET_SERVICE_NAME}.service ($service_state)"
    echo "Local RPC: $rpc_url"
    echo "Node directory: $GNOLAND_MAINNET_HOME"
    echo "Disk: $disk_line"
    echo

    node_height=$(echo "$status_json" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null)
    if [ -z "$node_height" ]; then
        echo -e "${RED}Cannot reach local RPC at ${rpc_url%/}/status. Is ${GNOLAND_MAINNET_SERVICE_NAME}.service running?${RESET}"
    else
        catching_up=$(echo "$status_json" | jq -r '.result.sync_info.catching_up // empty' 2>/dev/null)
        [ -z "$catching_up" ] && catching_up="unknown"
        latest_block_time=$(echo "$status_json" | jq -r '.result.sync_info.latest_block_time // empty' 2>/dev/null)
        [ -z "$latest_block_time" ] && latest_block_time="unknown"
        validator_address=$(echo "$status_json" | jq -r '.result.validator_info.address // empty' 2>/dev/null)
        [ -z "$validator_address" ] && validator_address="unknown"
        peer_count=$(echo "$net_info_json" | jq -r '.result.n_peers // empty' 2>/dev/null)
        [ -z "$peer_count" ] && peer_count="unknown"

        echo "Local height: $node_height"
        network_height=$(get_network_height)
        if [ -n "$network_height" ]; then
            echo "Network height: $network_height"
            if [[ "$network_height" =~ ^[0-9]+$ ]] && [[ "$node_height" =~ ^[0-9]+$ ]]; then
                block_diff=$((network_height - node_height))
                echo "Block difference: $block_diff"
                if [ "$block_diff" -le 0 ]; then
                    sync_status="synced"
                else
                    sync_status="behind by ${block_diff} blocks"
                    if [ "$catching_up" = "true" ]; then
                        sync_status="${sync_status} (catching up)"
                    fi
                fi
            fi
        else
            echo -e "${YELLOW}Network latest block height unavailable from $GNOLAND_PUBLIC_REMOTE${RESET}"
        fi
        [ -z "$sync_status" ] && sync_status="catching_up=${catching_up}"
        echo "Sync status: $sync_status"
        echo "Connected peers: $peer_count"
        echo "Latest block time: $latest_block_time"
        echo "Validator address: $validator_address"
    fi
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function run_node_doctor() {
    local doctor_exit
    clear
    echo -e "${CYAN}Valley of Gnoland Node Doctor${RESET}"
    echo -e "${YELLOW}Read-only inspection: no config, service, firewall, or key will be changed.${RESET}"
    echo

    run_node_doctor_script
    doctor_exit=$?
    case "$doctor_exit" in
        0) echo -e "\n${GREEN}Node Doctor completed. Review any WARN results before maintenance.${RESET}" ;;
        1) echo -e "\n${RED}Node Doctor found one or more failures. Review them before maintenance.${RESET}" ;;
        *) echo -e "\n${RED}Node Doctor could not complete (exit code $doctor_exit).${RESET}" ;;
    esac
    echo -e "${YELLOW}Press Enter to go back to the main menu${RESET}"
    read -r
    menu
}

function show_logs() {
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Logs blocked: selected service belongs to another instance.${RESET}" >&2
        menu
        return
    fi
    trap 'echo -e "\nStopping logs and returning to main menu...";' INT
    sudo journalctl -u "$GNOLAND_MAINNET_SERVICE_NAME" -fn 100 -o cat || true
    trap - INT
    menu
}

function create_operator_key() {
    echo "Choose an option:"
    echo "1. List/reuse an existing local operator key"
    echo "2. Recover an operator key from mnemonic"
    echo "3. Create a new operator key"
    echo "4. Back"
    read -r -p "Enter your choice: " choice

    case $choice in
        1)
            gnokey -home "$GNOKEY_HOME" list
            ;;
        2)
            read -r -p "Enter key name (default 'operator'): " keyname
            keyname=${keyname:-operator}
            if operator_key_exists "$keyname"; then
                echo -e "${RED}Key '$keyname' already exists. Refusing to overwrite it.${RESET}"
            else
                gnokey -home "$GNOKEY_HOME" add -recover "$keyname"
            fi
            ;;
        3)
            read -r -p "Enter key name (default 'operator'): " keyname
            keyname=${keyname:-operator}
            if operator_key_exists "$keyname"; then
                echo -e "${RED}Key '$keyname' already exists. Refusing to overwrite it.${RESET}"
            else
                gnokey -home "$GNOKEY_HOME" add "$keyname"
                echo -e "\n${RED}WRITE DOWN THE MNEMONIC ABOVE AND STORE IT OFFLINE. It will not be shown again.${RESET}"
            fi
            ;;
        4)
            menu
            return
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
    echo -e "\n${YELLOW}Mainnet funding: no public faucet is available.${RESET}"
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}


function local_consensus_pubkey() {
    "$GNOLAND_BIN" secrets get --data-dir "$GNOLAND_MAINNET_HOME/secrets" validator_key 2>/dev/null |
        grep -Eo 'gpub1[0-9a-z]+' | head -n 1
}

function show_validator_pubkey() {
    local key_name operator_addr local_pubkey profile registered_pubkey signing_addr candidate_status active_status identity_status

    echo -e "${CYAN}Validator Identity & Status${RESET}"
    local_pubkey=$(local_consensus_pubkey || true)
    read -r -p "Enter operator key name (default 'operator'): " key_name
    key_name=${key_name:-operator}
    if ! operator_key_exists "$key_name"; then
        echo "Local consensus pubkey: ${local_pubkey:-unavailable}"
        echo -e "${YELLOW}Operator key '$key_name' was not found, so on-chain operator/candidate correlation is unavailable.${RESET}"
        echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
        read -r
        menu
        return
    fi
    operator_addr=$(operator_key_address "$key_name")
    profile=""
    registered_pubkey=""
    signing_addr=""
    candidate_status="UNKNOWN"
    active_status="UNKNOWN"
    identity_status="UNKNOWN"

    if query_valoper_profile_status "$operator_addr"; then
        profile=$VALOPER_PROFILE_QUERY_OUTPUT
        candidate_status=$VALOPER_PROFILE_QUERY_STATUS
    fi
    if [ "$candidate_status" = "YES" ]; then
        registered_pubkey=$(profile_signing_pubkey "$profile")
        signing_addr=$(profile_signing_address "$profile")
        if query_active_validator_status "$signing_addr"; then
            active_status=$ACTIVE_VALIDATOR_QUERY_STATUS
        fi
        if [ -n "$local_pubkey" ]; then
            if [ "$local_pubkey" = "$registered_pubkey" ]; then
                identity_status="MATCH"
            else
                identity_status="MISMATCH"
            fi
        fi
    elif [ "$candidate_status" = "NO" ]; then
        identity_status="N/A"
    fi

    echo
    echo "Network:                $GNOLAND_CHAIN_ID"
    echo "Operator key:           $key_name"
    echo "Operator address:       ${operator_addr:-unavailable}"
    echo "Local consensus pubkey: ${local_pubkey:-unavailable}"
    echo "Candidate registered:   $candidate_status"
    echo "Active validator:       $active_status"
    echo "Registered pubkey:      ${registered_pubkey:-unavailable}"
    echo "Signing address:        ${signing_addr:-unavailable}"
    echo "Identity check:         $identity_status"

    if [ "$candidate_status" = "UNKNOWN" ]; then
        echo "Candidate status is UNKNOWN because the valoper profile query could not be verified."
    fi
    if [ "$candidate_status" = "YES" ] && [ "$active_status" = "UNKNOWN" ]; then
        echo "Active-validator status is UNKNOWN because the validator-set query could not be verified."
    fi
    if [ "$identity_status" = "MISMATCH" ]; then
        echo -e "${RED}WARNING: local consensus key does not match the valoper profile signing key.${RESET}"
        echo -e "${YELLOW}Do not assume this node can safely sign for the registered validator until the mismatch is understood.${RESET}"
    fi
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function show_account_dashboard() {
    local target operator_addr key_label balance_output account_output gas_output register_fee rotation_fee rotation_period
    local account_number sequence profile registered_pubkey signing_addr candidate_status active_status

    echo -e "${CYAN}Account & Balance Dashboard${RESET}"
    read -r -p "Enter local key name or g1... address (default 'operator'): " target
    target=${target:-operator}
    if ! operator_addr=$(resolve_operator_target "$target"); then
        echo -e "${RED}Could not resolve '$target' as a local key or g1... address.${RESET}"
        echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
        read -r
        menu
        return
    fi
    key_label="$target"
    [[ "$target" =~ ^g1 ]] && key_label="address-only"

    balance_output=$(gnokey_cmd query "bank/balances/$operator_addr" 2>&1 || true)
    account_output=$(gnokey_cmd query "auth/accounts/$operator_addr" 2>&1 || true)
    gas_output=$(gnokey_cmd query auth/gasprice 2>&1 || true)
    register_fee=$(get_valoper_register_fee 2>/dev/null || echo unavailable)
    rotation_fee=$(get_valoper_rotation_fee 2>/dev/null || echo unavailable)
    rotation_period=$(get_valoper_rotation_period_blocks 2>/dev/null || echo unavailable)
    account_number=$(printf '%s\n' "$account_output" | sed -n 's/.*"account_number"[[:space:]]*:[[:space:]]*"\([0-9][0-9]*\)".*/\1/p' | head -n 1)
    sequence=$(printf '%s\n' "$account_output" | sed -n 's/.*"sequence"[[:space:]]*:[[:space:]]*"\([0-9][0-9]*\)".*/\1/p' | head -n 1)
    profile=""
    registered_pubkey=""
    signing_addr=""
    candidate_status="UNKNOWN"
    active_status="UNKNOWN"
    if query_valoper_profile_status "$operator_addr"; then
        profile=$VALOPER_PROFILE_QUERY_OUTPUT
        candidate_status=$VALOPER_PROFILE_QUERY_STATUS
    fi
    if [ "$candidate_status" = "YES" ]; then
        registered_pubkey=$(profile_signing_pubkey "$profile")
        signing_addr=$(profile_signing_address "$profile")
        if query_active_validator_status "$signing_addr"; then
            active_status=$ACTIVE_VALIDATOR_QUERY_STATUS
        fi
    fi

    echo
    echo "Network:                $GNOLAND_CHAIN_ID"
    echo "Target:                 $key_label"
    echo "Address:                $operator_addr"
    echo "Balance:                $(format_ugnot_balance "$balance_output")"
    echo "Account number:         ${account_number:-unavailable}"
    echo "Sequence:               ${sequence:-unavailable}"
    echo "Minimum gas price:"
    printf '%s\n' "$gas_output" | sed 's/^/  /'
    echo "Valoper candidate:      $candidate_status"
    echo "Active validator:       $active_status"
    echo "Registered signing key: ${registered_pubkey:-unavailable}"
    echo "Register fee:           ${register_fee} ugnot"
    echo "Rotation fee:           ${rotation_fee} ugnot"
    echo "Rotation period:        ${rotation_period} blocks"
    if [ "$candidate_status" = "UNKNOWN" ]; then
        echo "Candidate status is UNKNOWN because the valoper profile query could not be verified."
    fi
    if [ "$candidate_status" = "YES" ] && [ "$active_status" = "UNKNOWN" ]; then
        echo "Active-validator status is UNKNOWN because the validator-set query could not be verified."
    fi
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function register_valoper_candidate() {
    local register_fee derived_operator_addr tx_status profile balance_output


    echo -e "${CYAN}Register Gno.land Mainnet Valoper Candidate${RESET}"
    echo -e "${YELLOW}This broadcasts a transaction. It creates a candidate profile only, not active validator status.${RESET}"
    echo -e "${YELLOW}Node sync is recommended operationally, but local RPC sync is not a transaction blocker.${RESET}"
    if ! prompt_back_or_continue; then
        return
    fi

    read -r -p "Enter operator key name (default 'operator'): " KEY_NAME
    KEY_NAME=${KEY_NAME:-operator}
    read -r -p "Enter validator moniker: " MONIKER
    read -r -p "Enter short validator description: " DESCRIPTION
    read -r -p "Enter infrastructure type (cloud/on-prem/data-center): " INFRA_TYPE
    read -r -p "Enter operator g1... address: " OPERATOR_ADDR
    read -r -p "Enter consensus gpub1... public key: " CONSENSUS_PUBKEY

    if ! operator_key_exists "$KEY_NAME"; then
        echo -e "${RED}Operator key '$KEY_NAME' was not found in $GNOKEY_HOME.${RESET}"
        echo -e "${YELLOW}Create/recover it with option 2a, then retry.${RESET}"
        echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
        read -r
        menu
        return
    fi
    derived_operator_addr=$(operator_key_address "$KEY_NAME")
    if [ "$derived_operator_addr" != "$OPERATOR_ADDR" ]; then
        echo -e "${RED}Registration blocked: operator address does not match key '$KEY_NAME'.${RESET}"
        echo "Address controlled by the selected key: ${derived_operator_addr:-unavailable}"
        echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
        read -r
        menu
        return
    fi
    case "$INFRA_TYPE" in
        cloud|on-prem|data-center) ;;
        *)
            echo -e "${RED}Infrastructure type must be exactly: cloud, on-prem, or data-center.${RESET}"
            echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
            read -r
            menu
            return
            ;;
    esac
    if [ -z "$MONIKER" ] || [ "${#MONIKER}" -gt 32 ] || [ -z "$DESCRIPTION" ] || [ "${#DESCRIPTION}" -gt 2048 ]; then
        echo -e "${RED}Moniker/description violates the valoper realm length requirements.${RESET}"
        echo -e "${YELLOW}Moniker: 1-32 chars. Description: 1-2048 chars.${RESET}"
        echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
        read -r
        menu
        return
    fi
    if [[ ! "$OPERATOR_ADDR" =~ ^g1[0-9a-z]+$ ]] || [[ ! "$CONSENSUS_PUBKEY" =~ ^gpub1[0-9a-z]+$ ]]; then
        echo -e "${RED}Operator address or consensus public key has an invalid format.${RESET}"
        echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
        read -r
        menu
        return
    fi

    if ! register_fee=$(get_valoper_register_fee); then
        echo -e "${RED}Registration blocked: current on-chain valoper registration fee could not be verified.${RESET}"
        echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
        read -r
        menu
        return
    fi
    if [ "$register_fee" -ne 0 ]; then
        echo -e "${RED}Registration blocked: the current on-chain valoper registration fee is ${register_fee} ugnot.${RESET}"
        echo "Valley will not guess or attach a payment amount to this call."
        echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
        read -r
        menu
        return
    fi

    if ! query_valoper_profile_status "$OPERATOR_ADDR"; then
        echo "Registration blocked: candidate profile status could not be verified from the configured public RPC."
        echo "Valley will not treat an RPC or realm query failure as Candidate exists: NO."
        echo "Retry after the read-only profile query is healthy."
        read -r -p "Press Enter to go back to main menu"
        menu
        return
    fi
    profile=$VALOPER_PROFILE_QUERY_OUTPUT
    if [ "$VALOPER_PROFILE_QUERY_STATUS" = "YES" ]; then
        echo "Registration blocked: this operator address already has a valoper profile."
        printf '%s\n' "$profile"
        echo "Use option 2e to manage the existing profile."
        read -r -p "Press Enter to go back to main menu"
        menu
        return
    fi
    if [ "$VALOPER_PROFILE_QUERY_STATUS" != "NO" ]; then
        echo "Registration blocked: candidate profile status is UNKNOWN."
        read -r -p "Press Enter to go back to main menu"
        menu
        return
    fi
    balance_output=$(gnokey_cmd query "bank/balances/$OPERATOR_ADDR" 2>&1 || true)
    echo -e "\n${CYAN}Registration preflight${RESET}"
    echo "Signer/address match: OK"
    echo "Candidate exists:     NO"
    echo "Register fee:         ${register_fee} ugnot"
    echo "Operator balance:     $(format_ugnot_balance "$balance_output")"

    echo -e "\n${YELLOW}Transaction preview:${RESET}"
    cat <<EOF
gnokey maketx call \\
  --pkgpath gno.land/$GNOLAND_VALOPER_REALM \\
  --func Register \\
  --args "$MONIKER" \\
  --args "$DESCRIPTION" \\
  --args "$INFRA_TYPE" \\
  --args "$OPERATOR_ADDR" \\
  --args "$CONSENSUS_PUBKEY" \\
  --gas-fee $VALOPER_GAS_FEE --gas-wanted $VALOPER_GAS_WANTED \\
  --chainid $GNOLAND_CHAIN_ID \\
  --remote $GNOLAND_PUBLIC_REMOTE \\
  --broadcast \\
  $KEY_NAME
EOF
    read -r -p $'\n\e[33mBroadcast registration transaction? (yes/no): \e[0m' confirm
    if [[ "${confirm,,}" != "yes" ]]; then
        echo "Cancelled."
        menu
        return
    fi

    gnokey_cmd maketx call \
        -pkgpath "gno.land/$GNOLAND_VALOPER_REALM" \
        -func Register \
        -args "$MONIKER" \
        -args "$DESCRIPTION" \
        -args "$INFRA_TYPE" \
        -args "$OPERATOR_ADDR" \
        -args "$CONSENSUS_PUBKEY" \
        -gas-fee "$VALOPER_GAS_FEE" \
        -gas-wanted "$VALOPER_GAS_WANTED" \
        -chainid "$GNOLAND_CHAIN_ID" \
        -broadcast \
        "$KEY_NAME"
    tx_status=$?

    if [ "$tx_status" -ne 0 ]; then
        echo -e "\n${RED}Candidate registration failed. No success status was reported.${RESET}"
        echo -e "${YELLOW}Review the transaction error above, then retry from option 2c.${RESET}"
        echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
        read -r
        menu
        return
    fi

    echo -e "\n${GREEN}Candidate registration transaction broadcast succeeded.${RESET}"
    echo -e "${YELLOW}Next gate: GovDAO proposal approval via $GNOLAND_ACTIVE_REALM.${RESET}"
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function manage_valoper_profile() {
    local key_name operator_addr profile choice value keep_running
    echo -e "${CYAN}Manage Valoper Profile${RESET}"
    read -r -p "Enter operator key name (default 'operator'): " key_name
    key_name=${key_name:-operator}
    if ! operator_key_exists "$key_name"; then
        echo -e "${RED}Operator key '$key_name' was not found.${RESET}"
        read -r -p "Press Enter to go back to main menu"
        menu
        return
    fi
    operator_addr=$(operator_key_address "$key_name")
    if ! query_valoper_profile_status "$operator_addr"; then
        echo "Valoper profile status is UNKNOWN because the read-only query could not be verified."
        echo "No profile-changing transaction will be prepared."
        read -r -p "Press Enter to go back to main menu"
        menu
        return
    fi
    profile=$VALOPER_PROFILE_QUERY_OUTPUT
    if [ "$VALOPER_PROFILE_QUERY_STATUS" = "NO" ]; then
        echo -e "${RED}No valoper profile found for $operator_addr.${RESET}"
        echo -e "${YELLOW}Use option 2c to register first.${RESET}"
        read -r -p "Press Enter to go back to main menu"
        menu
        return
    fi

    echo
    echo "1. Show current profile"
    echo "2. Update moniker"
    echo "3. Update description"
    echo "4. Update server type"
    echo "5. Update KeepRunning status"
    echo "6. Back"
    read -r -p "Enter your choice: " choice
    case "$choice" in
        1)
            printf '%s\n' "$profile"
            ;;
        2)
            read -r -p "Enter new moniker: " value
            if [ -z "$value" ] || [ "${#value}" -gt 32 ]; then
                echo -e "${RED}Moniker must be 1-32 characters.${RESET}"
            else
                broadcast_valoper_call "$key_name" UpdateMoniker yes "$operator_addr" "$value" || true
            fi
            ;;
        3)
            read -r -p "Enter new description: " value
            if [ -z "$value" ] || [ "${#value}" -gt 2048 ]; then
                echo -e "${RED}Description must be 1-2048 characters.${RESET}"
            else
                broadcast_valoper_call "$key_name" UpdateDescription yes "$operator_addr" "$value" || true
            fi
            ;;
        4)
            read -r -p "Enter server type (cloud/on-prem/data-center): " value
            case "$value" in
                cloud|on-prem|data-center) broadcast_valoper_call "$key_name" UpdateServerType yes "$operator_addr" "$value" || true ;;
                *) echo -e "${RED}Invalid server type.${RESET}" ;;
            esac
            ;;
        5)
            read -r -p "Set KeepRunning to true or false: " keep_running
            case "$keep_running" in
                true|false)
                    echo -e "${YELLOW}KeepRunning affects whether this valoper wants to remain in the active set.${RESET}"
                    broadcast_valoper_call "$key_name" UpdateKeepRunning KEEP-RUNNING "$operator_addr" "$keep_running" || true
                    ;;
                *) echo -e "${RED}Value must be exactly true or false.${RESET}" ;;
            esac
            ;;
        6) menu; return ;;
        *) echo "Invalid choice." ;;
    esac
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function advanced_validator_operations() {
    local key_name operator_addr profile rotation_fee rotation_period new_pubkey choice local_pubkey
    echo -e "${CYAN}Advanced Validator Operations${RESET}"
    echo "1. Show valoper/rotation parameters"
    echo "2. Rotate consensus signing key"
    echo "3. Back"
    read -r -p "Enter your choice: " choice
    case "$choice" in
        1)
            read -r -p "Enter operator key name (default 'operator'): " key_name
            key_name=${key_name:-operator}
            if operator_key_exists "$key_name"; then
                operator_addr=$(operator_key_address "$key_name")
                if query_valoper_profile_status "$operator_addr"; then
                    if [ "$VALOPER_PROFILE_QUERY_STATUS" = "YES" ]; then
                        printf '%s\n' "$VALOPER_PROFILE_QUERY_OUTPUT"
                    else
                        echo "Valoper profile: not registered"
                    fi
                else
                    echo "Valoper profile: UNKNOWN (read-only query could not be verified)"
                fi
            else
                echo -e "${RED}Operator key '$key_name' was not found.${RESET}"
            fi
            echo "Rotation fee: $(get_valoper_rotation_fee 2>/dev/null || echo unavailable) ugnot"
            echo "Rotation period: $(get_valoper_rotation_period_blocks 2>/dev/null || echo unavailable) blocks"
            ;;
        2)
            read -r -p "Enter operator key name (default 'operator'): " key_name
            key_name=${key_name:-operator}
            if ! operator_key_exists "$key_name"; then
                echo -e "${RED}Operator key '$key_name' was not found.${RESET}"
            else
                operator_addr=$(operator_key_address "$key_name")
                if ! query_valoper_profile_status "$operator_addr"; then
                    echo "Rotation blocked: valoper profile status is UNKNOWN because the read-only query could not be verified."
                elif [ "$VALOPER_PROFILE_QUERY_STATUS" = "NO" ]; then
                    echo "No valoper profile found for $operator_addr."
                else
                    profile=$VALOPER_PROFILE_QUERY_OUTPUT
                    rotation_fee=$(get_valoper_rotation_fee 2>/dev/null || echo unavailable)
                    rotation_period=$(get_valoper_rotation_period_blocks 2>/dev/null || echo unavailable)
                    if ! [[ "$rotation_fee" =~ ^[0-9]+$ ]]; then
                        echo -e "${RED}Rotation blocked: current on-chain rotation fee could not be verified.${RESET}"
                    elif [ "$rotation_fee" -ne 0 ]; then
                        echo "Rotation blocked: current on-chain rotation fee is $rotation_fee ugnot."
                        echo "Valley will not guess or attach a payment amount to this high-impact call."
                    elif ! [[ "$rotation_period" =~ ^[0-9]+$ ]]; then
                        echo "Rotation blocked: current on-chain rotation period could not be verified."
                    else
                        local_pubkey=$(local_consensus_pubkey || true)
                        echo "Current profile:"
                        printf '%s\n' "$profile"
                        echo "Local consensus pubkey: ${local_pubkey:-unavailable}"
                        echo "Rotation throttle: ${rotation_period} blocks"
                        read -r -p "Enter NEW consensus gpub1... public key: " new_pubkey
                        if [[ ! "$new_pubkey" =~ ^gpub1[0-9a-z]+$ ]]; then
                            echo -e "${RED}Invalid consensus public key format.${RESET}"
                        elif [ "$new_pubkey" = "$(profile_signing_pubkey "$profile")" ]; then
                            echo -e "${RED}New signing key is identical to the currently registered key.${RESET}"
                        else
                            echo -e "${RED}HIGH IMPACT: UpdateSigningKey changes the consensus signing identity. The realm applies the rotation to consensus after the on-chain transition.${RESET}"
                            echo -e "${YELLOW}Confirm the new private validator key is safely installed on the intended node before using this.${RESET}"
                            broadcast_valoper_call "$key_name" UpdateSigningKey ROTATE "$operator_addr" "$new_pubkey" || true
                        fi
                    fi
                fi
            fi
            ;;
        3) menu; return ;;
        *) echo "Invalid choice." ;;
    esac
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function advanced_query_inspector() {
    local choice path data
    echo -e "${CYAN}Advanced Read-only Query / Realm Inspector${RESET}"
    echo "1. Query arbitrary ABCI path"
    echo "2. Render realm/path (vm/qrender)"
    echo "3. List exported functions (vm/qfuncs)"
    echo "4. Show realm/package docs (vm/qdoc)"
    echo "5. Evaluate read-only expression (vm/qeval)"
    echo "6. Show realm storage/deposit (vm/qstorage)"
    echo "7. Search package/realm paths (vm/qpaths)"
    echo "8. Back"
    read -r -p "Enter your choice: " choice
    case "$choice" in
        1)
            read -r -p "Enter ABCI query path: " path
            gnokey_cmd query "$path"
            ;;
        2)
            read -r -p "Enter pkgpath[:render-path]: " data
            gnokey_cmd query vm/qrender -data "$data"
            ;;
        3)
            read -r -p "Enter package/realm path: " data
            gnokey_cmd query vm/qfuncs -data "$data"
            ;;
        4)
            read -r -p "Enter package/realm path: " data
            gnokey_cmd query vm/qdoc -data "$data"
            ;;
        5)
            read -r -p "Enter full read-only expression (for example gno.land/r/sys/params.GetValoperRegisterFee()): " data
            gnokey_cmd query vm/qeval -data "$data"
            ;;
        6)
            read -r -p "Enter realm path: " data
            gnokey_cmd query vm/qstorage -data "$data"
            ;;
        7)
            read -r -p "Enter path prefix (for example gno.land/r/gnops): " data
            gnokey_cmd query 'vm/qpaths?limit=100' -data "$data"
            ;;
        8) menu; return ;;
        *) echo "Invalid choice." ;;
    esac
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}


function backup_node_secrets() {
    if [ -d "$GNOLAND_MAINNET_HOME/secrets" ]; then
        local backup
        backup="$HOME/gnoland-secrets-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "$backup" -C "$GNOLAND_MAINNET_HOME" secrets
        chmod 600 "$backup"
        echo -e "${YELLOW}Node secrets copied to $backup${RESET}"
        echo -e "${RED}Move it somewhere safe and offline.${RESET}"
    else
        echo -e "${RED}No secrets directory found at $GNOLAND_MAINNET_HOME/secrets. Deploy node first.${RESET}"
    fi
    menu
}

function restart_gnoland() {
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Restart blocked to protect the other instance.${RESET}"
        menu
        return
    fi
    sudo systemctl daemon-reload
    sudo systemctl restart "$GNOLAND_MAINNET_SERVICE_NAME"
    echo -e "${GREEN}${GNOLAND_MAINNET_SERVICE_NAME}.service restarted.${RESET}"
    menu
}

function stop_gnoland() {
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Stop blocked to protect the other instance.${RESET}"
        menu
        return
    fi
    sudo systemctl stop "$GNOLAND_MAINNET_SERVICE_NAME"
    echo -e "${YELLOW}${GNOLAND_MAINNET_SERVICE_NAME}.service stopped.${RESET}"
    menu
}

function delete_gnoland_node() {
    echo -e "${YELLOW}You are about to delete the Valley Gnoland node data.${RESET}"
    echo -e "${RED}BACK UP OPERATOR MNEMONIC AND NODE SECRETS BEFORE YOU DO THIS.${RESET}"
    if ! prompt_back_or_continue; then
        return
    fi
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Delete blocked to protect the other instance.${RESET}"
        menu
        return
    fi
    local canonical_home canonical_node_home
    canonical_home=$(realpath -m "$HOME")
    canonical_node_home=$(realpath -m "$GNOLAND_MAINNET_HOME")
    case "$canonical_node_home" in
        "$canonical_home"/*) ;;
        *)
            echo -e "${RED}Delete blocked: node path is outside $HOME.${RESET}"
            menu
            return
            ;;
    esac
    sudo systemctl stop "$GNOLAND_MAINNET_SERVICE_NAME" || true
    sudo systemctl disable "$GNOLAND_MAINNET_SERVICE_NAME" || true
    sudo rm -f "/etc/systemd/system/${GNOLAND_MAINNET_SERVICE_NAME}.service"
    sudo systemctl daemon-reload
    rm -rf "$GNOLAND_MAINNET_HOME"
    rm -f "$GNOLAND_GENESIS"
    rm -f "$GNOLAND_BIN" "$GNOKEY_BIN"
    remove_valley_profile_block
    echo -e "${RED}Gnoland node deleted. Local gnokey home was not deleted: $GNOKEY_HOME${RESET}"
    menu
}

function show_endpoints() {
    echo -e "$ENDPOINTS"
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function show_guidelines() {
    echo -e "${CYAN}Guidelines on How to Use the Valley of Gnoland${RESET}"
    echo -e "${GREEN}Recommended flow:${RESET}"
    echo " - 1a Install the node from the pinned mainnet source and verified release assets"
    echo " - 1e Confirm local RPC reports gnoland-1 and monitor sync"
    echo " - 1g Run the read-only Node Doctor"
    echo " - 2a Manage an operator key only after reviewing key safety"
    echo " - 3d Back up node secrets before maintenance"
    echo -e "${YELLOW}Mainnet candidate registration is enabled in option 2c using the verified upstream procedure. Snapshot application remains disabled until a provider is independently verified.${RESET}"
    echo
    echo -e "${GREEN}Node Interactions:${RESET}"
    echo "   a) Deploy/Re-deploy Gnoland Node: verifies the pinned source and release assets, then starts gnoland-1."
    echo "   b) Update Gnoland/Gnokey: verifies the pinned source and release assets."
    echo "   c) Apply Snapshot: fails closed without a verified gnoland-1 provider."
    echo "   d) Add/Reset Peers: manages persistent peers and the official mainnet seed list."
    echo "   e) Show Node Status: shows local health and comparison-RPC height."
    echo "   f) Show Node Logs: live-tails the Gnoland service logs."
    echo "   g) Run Node Doctor: read-only health and configuration inspection."
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function menu() {
    clear
    echo -e "$LOGO"
    local node_height network_height catching_up diff sync_status
    node_height=$(get_local_status_json | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null)
    catching_up=$(get_local_status_json | jq -r '.result.sync_info.catching_up // empty' 2>/dev/null)
    network_height=$(get_network_height)
    [ -z "$node_height" ] && node_height="N/A"
    [ -z "$network_height" ] && network_height="N/A"
    [ -z "$catching_up" ] && catching_up="N/A"
    if [[ "$node_height" =~ ^[0-9]+$ ]] && [[ "$network_height" =~ ^[0-9]+$ ]]; then
        diff=$((network_height - node_height))
        if [ "$diff" -le 0 ]; then
            sync_status="synced"
        else
            sync_status="behind by ${diff} blocks"
            [ "$catching_up" = "true" ] && sync_status="${sync_status} (catching up)"
        fi
    else
        diff="N/A"
        sync_status="catching_up=${catching_up}"
    fi

    echo -e "${GREEN}Valley of Gnoland by Grand Valley${RESET}"
    echo -e "Network Height: ${CYAN}${network_height}${RESET} | Local Height: ${CYAN}${node_height}${RESET} | Block Difference: ${YELLOW}${diff}${RESET} | Sync Status: ${YELLOW}${sync_status}${RESET}"
    echo
    echo "1. Node Interactions"
    echo "   1a. Deploy/Re-deploy Gnoland Node"
    echo "   1b. Update Gnoland/Gnokey from Pinned Mainnet Assets (${GNOLAND_ASSET_VERSION})"
    echo "   1c. Apply Snapshot"
    echo "   1d. Add/Reset Peers"
    echo "   1e. Show Node Status"
    echo "   1f. Show Node Logs"
    echo "   1g. Run Node Doctor (Read-only)"
    echo
    echo "2. Validator/Key/Account Interactions"
    echo "   2a. Operator Key Manager"
    echo "   2b. Validator Identity & Status"
    echo "   2c. Mainnet Validator Registration"
    echo "   2d. Account & Balance Dashboard"
    echo "   2e. Manage Valoper Profile"
    echo "   2f. Advanced Validator Operations"
    echo "   2g. Advanced Query / Realm Inspector"
    echo
    echo "3. Node Management"
    echo "   3a. Restart Gnoland Node"
    echo "   3b. Stop Gnoland Node"
    echo "   3c. Delete Gnoland Node"
    echo "   3d. Backup Node Secrets"
    echo
    echo "4. Show Endpoints & Useful Links"
    echo "5. Show Guidelines"
    echo "6. Exit"
    echo
    echo -e "Gno.land gnoland-1: ${BLUE}https://gno.land${RESET}"
    echo -e "${GREEN}Let's Buidl Gnoland Together - Grand Valley${RESET}"
    if ! read -r -p "Choose an option: " choice; then
        echo
        echo "Let's Buidl Gnoland Together - Grand Valley"
        exit 0
    fi
    case "${choice,,}" in
        1a|1-a) deploy_gnoland_node ;;
        1b|1-b) update_gnoland_binary ;;
        1c|1-c) apply_snapshot ;;
        1d|1-d) add_peers ;;
        1e|1-e) show_node_status ;;
        1f|1-f) show_logs ;;
        1g|1-g) run_node_doctor ;;
        2a|2-a) create_operator_key ;;
        2b|2-b) show_validator_pubkey ;;
        2c|2-c) register_valoper_candidate ;;
        2d|2-d) show_account_dashboard ;;
        2e|2-e) manage_valoper_profile ;;
        2f|2-f) advanced_validator_operations ;;
        2g|2-g) advanced_query_inspector ;;
        3a|3-a) restart_gnoland ;;
        3b|3-b) stop_gnoland ;;
        3c|3-c) delete_gnoland_node ;;
        3d|3-d) backup_node_secrets ;;
        4) show_endpoints ;;
        5) show_guidelines ;;
        6) echo "Let's Buidl Gnoland Together - Grand Valley"; exit 0 ;;
        *)
            echo "Invalid choice."
            sleep 1
            menu
            ;;
    esac
}

menu
