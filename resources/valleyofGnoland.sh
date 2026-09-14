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
readonly GNOLAND_SOURCE_COMMIT="31b6650a100d9baf14e7669f8f0df924f1f841e0"
readonly GNOLAND_RELEASE_TAG="chain/mainnet"
readonly GNOLAND_RELEASE_COMMIT="9c8eb132e483d6fd324d92c193e629ad65a98a37"
readonly GNOLAND_GENESIS_SHA256="ea22691003130eae3ba975b7d16460706b5d75ce6c04ae82c0c4faeab7de91f0"
readonly GNOLAND_BIN_SHA256="aa22a26823924642481fe7fc5e98eb9f42399b337f7afdac635d91403117db28"
readonly GNOKEY_BIN_SHA256="38018492bcaa4de2f146d0566daf6507d9e811ee28547b963a015f51f9b14511"
readonly OFFICIAL_GNOLAND_PEERS="g15rcv5yqef3kvnmueqvkyw8y05sd40jz9p3n5su@seed-1.gno.land:26656,g1ck2yeyvvnpl92237gcea0z68jx07a4nnyvuaan@seed-2.gno.land:26656"
readonly GNOLAND_ACTIVE_REALM="r/sys/validators/v0"
readonly VALLEY_RUNTIME_REF="49f887478fbc1d83079cd5675c4c3eb51bdd459a"
readonly NODE_DOCTOR_RELATIVE_PATH="resources/gnoland_node_doctor.sh"

run_node_doctor_script() {
    local script_dir script_file exit_code

    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)
    if [ -n "$script_dir" ] && [ -f "$script_dir/gnoland_node_doctor.sh" ]; then
        bash "$script_dir/gnoland_node_doctor.sh" "$@"
        return $?
    fi

    if ! command -v curl >/dev/null 2>&1 || [[ ! "$VALLEY_RUNTIME_REF" =~ ^[0-9a-f]{40}$ ]] || [ "$VALLEY_RUNTIME_REF" = "0000000000000000000000000000000000000000" ]; then
        echo -e "${RED}Node Doctor is unavailable: no local helper or verified remote pin was found.${RESET}" >&2
        return 2
    fi

    script_file=$(mktemp)
    if ! curl -fsSL "https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Mainnet/49f887478fbc1d83079cd5675c4c3eb51bdd459a/${NODE_DOCTOR_RELATIVE_PATH}" -o "$script_file"; then
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
if [ -z "${GNOLAND_HOME:-}" ] || [ "$GNOLAND_HOME" = "$HOME/.gnoland" ] || [ "$GNOLAND_HOME" = "$HOME/gnoland-data" ]; then
    GNOLAND_HOME="$GNO_SOURCE_DIR/gnoland-data"
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
    if [ -z "${GNOLAND_SERVICE_NAME:-}" ]; then
        echo -e "${YELLOW}Service name configuration not found.${RESET}"
        read -r -p "Enter Service Name (default 'gnoland'): " INPUT_SVC
        GNOLAND_SERVICE_NAME=${INPUT_SVC:-gnoland}
    fi
    GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME%.service}
    if [[ "$GNOLAND_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then
        break
    fi
    echo -e "${RED}Service name must start with a letter or number and may contain _, ., @, and -.${RESET}"
    GNOLAND_SERVICE_NAME=""
done

# Keep the established per-user startup configuration, while replacing only
# the Valley-managed values on each invocation.
sed -i '/^export GNOLAND_SERVICE_NAME=/d' "$HOME/.bash_profile" 2>/dev/null || true
echo "export GNOLAND_SERVICE_NAME=\"$GNOLAND_SERVICE_NAME\"" >> "$HOME/.bash_profile"
export GNOLAND_SERVICE_NAME

service_belongs_to_current_instance() {
    local service_file unit_user unit_workdir
    service_file=$(systemctl show "$GNOLAND_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
    [ -n "$service_file" ] || return 0
    if [ ! -f "$service_file" ]; then
        echo -e "${RED}Cannot inspect existing service: $service_file${RESET}" >&2
        return 1
    fi
    unit_user=$(sed -n 's/^User=//p' "$service_file" | tail -n 1)
    unit_workdir=$(sed -n 's/^WorkingDirectory=//p' "$service_file" | tail -n 1)
    if [ "$unit_user" != "$OS_USER" ] || [ "$unit_workdir" != "$GNO_SOURCE_DIR" ]; then
        echo -e "${RED}${GNOLAND_SERVICE_NAME}.service belongs to another instance.${RESET}" >&2
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
- source directory: ${CYAN}${GNO_SOURCE_DIR}${RESET}
- mainnet deployment: ${CYAN}${GNOLAND_DEPLOYMENT_DIR}${RESET}
- node directory: ${CYAN}${GNOLAND_HOME}${RESET}
- operator keyring: ${CYAN}${GNOKEY_HOME}${RESET}
- binaries: ${CYAN}$HOME/go/bin/gnoland, $HOME/go/bin/gnokey${RESET}
- service file: ${CYAN}${GNOLAND_SERVICE_NAME}.service${RESET}
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
- This Valley installs and inspects a node. Validator admission and transaction broadcasting are not automated here.
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

sed -i '/^export GNOLAND_CHAIN_ID=/d;/^export GNOLAND_HOME=/d;/^export GNOLAND_DEPLOYMENT_DIR=/d;/^export GNOLAND_GENESIS=/d;/^export GNOKEY_HOME=/d;/^export GNO_SOURCE_DIR=/d;/^export GNOROOT=/d;/^export GNOLAND_PUBLIC_REMOTE=/d;/go\/bin/d' "$HOME/.bash_profile" 2>/dev/null || true
{
    echo "export GNOLAND_CHAIN_ID=\"$GNOLAND_CHAIN_ID_DEFAULT\""
    echo "export GNOLAND_HOME=\"$GNOLAND_HOME\""
    echo "export GNOLAND_DEPLOYMENT_DIR=\"$GNOLAND_DEPLOYMENT_DIR\""
    echo "export GNOLAND_GENESIS=\"$GNOLAND_GENESIS\""
    echo "export GNOKEY_HOME=\"$GNOKEY_HOME\""
    echo "export GNO_SOURCE_DIR=\"$GNO_SOURCE_DIR\""
    echo "export GNOROOT=\"$GNOROOT\""
    echo "export GNOLAND_PUBLIC_REMOTE=\"$GNOLAND_PUBLIC_RPC_DEFAULT\""
    # shellcheck disable=SC2016
    echo 'export PATH="$HOME/go/bin:$PATH"'
} >> "$HOME/.bash_profile"
# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null || true

# Tests and local runs use this function from the checked-out repository. A
# remote fallback is intentionally absent because this checkout has no verified
# immutable helper commit.
run_repository_script() {
    local relative_path=$1 script_dir script_file exit_code
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)
    if [ -n "$script_dir" ] && [ -f "$script_dir/../$relative_path" ]; then
        bash "$script_dir/../$relative_path"
        return $?
    fi

    if ! command -v curl >/dev/null 2>&1 || [[ ! "$VALLEY_RUNTIME_REF" =~ ^[0-9a-f]{40}$ ]] || [ "$VALLEY_RUNTIME_REF" = "0000000000000000000000000000000000000000" ]; then
        echo -e "${RED}Cannot run ${relative_path}: local helper not found and no verified remote pin is configured.${RESET}" >&2
        return 2
    fi

    script_file=$(mktemp)
    if ! curl -fsSL "https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Mainnet/49f887478fbc1d83079cd5675c4c3eb51bdd459a/${relative_path}" -o "$script_file"; then
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

function get_rpc_port_from_remote() {
    local remote="${GNOLAND_REMOTE:-}"
    if [[ "$remote" =~ :([0-9]+)/?$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

function get_local_rpc_port() {
    local cfg="$GNOLAND_HOME/config/config.toml" port
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
    echo -e "${YELLOW}Service:${RESET} ${CYAN}${GNOLAND_SERVICE_NAME}.service${RESET}"
    echo -e "${YELLOW}Directory:${RESET} ${CYAN}$GNOLAND_HOME${RESET}"
    echo -e "${YELLOW}Default ports:${RESET} P2P ${CYAN}26656${RESET}, RPC ${CYAN}26657${RESET}, ABCI ${CYAN}26658${RESET}; the installer remaps local listeners with the chosen two-digit prefix."
    echo -e "${YELLOW}Install/update method:${RESET} pinned ${GNOLAND_SOURCE_BRANCH} source plus verified Linux amd64 release assets."
    echo -e "${RED}Installation replaces Valley node data inside the selected node directory after backup and explicit confirmation.${RESET}"
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
    echo -e "${YELLOW}Update gnoland and gnokey from the pinned ${GNOLAND_SOURCE_BRANCH} source and verified release assets.${RESET}"
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

    local cfg="$GNOLAND_HOME/config/config.toml"
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
    service_state=$(systemctl is-active "$GNOLAND_SERVICE_NAME" 2>/dev/null || true)
    [ -z "$service_state" ] && service_state="unknown"
    disk_line=$(df -h "$GNOLAND_HOME" 2>/dev/null | awk 'NR==2 {print $4 " free of " $2 " (" $5 " used)"}')
    [ -z "$disk_line" ] && disk_line="unavailable for $GNOLAND_HOME"

    echo -e "${CYAN}Operational health summary${RESET}"
    echo "Service: ${GNOLAND_SERVICE_NAME}.service ($service_state)"
    echo "Local RPC: $rpc_url"
    echo "Node directory: $GNOLAND_HOME"
    echo "Disk: $disk_line"
    echo

    node_height=$(echo "$status_json" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null)
    if [ -z "$node_height" ]; then
        echo -e "${RED}Cannot reach local RPC at ${rpc_url%/}/status. Is ${GNOLAND_SERVICE_NAME}.service running?${RESET}"
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
    sudo journalctl -u "$GNOLAND_SERVICE_NAME" -fn 100 -o cat || true
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

function show_validator_pubkey() {
    echo -e "${CYAN}Your local consensus public key:${RESET}"
    "$GNOLAND_BIN" secrets get --data-dir "$GNOLAND_HOME/secrets" validator_key
    echo -e "\n${YELLOW}Use the displayed value only with a separately verified mainnet procedure. Press Enter to go back.${RESET}"
    read -r
    menu
}

function register_valoper_candidate() {
    echo -e "${CYAN}Mainnet validator registration${RESET}"
    echo -e "${YELLOW}This option is disabled. Active realm: $GNOLAND_ACTIVE_REALM${RESET}"
    echo "No verified mainnet funding route, gas specification, or transaction procedure is configured."
    echo "Mainnet has no public faucet."
    echo "No transaction was prepared or broadcast."
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function query_balance_or_realm() {
    echo "Choose an option:"
    echo "1. Query an ABCI path manually"
    echo "2. Show verified Gno.land links"
    echo "3. Back"
    read -r -p "Enter your choice: " choice
    case $choice in
        1)
            read -r -p "Enter ABCI query path: " path
            gnokey_cmd query "$path"
            ;;
        2)
            echo "Web: https://gno.land"
            echo "RPC: https://rpc.gno.land"
            echo "Faucet: none (mainnet has no public faucet)"
            echo "Active validator realm: $GNOLAND_ACTIVE_REALM"
            ;;
        3)
            menu
            return
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function backup_node_secrets() {
    if [ -d "$GNOLAND_HOME/secrets" ]; then
        local backup
        backup="$HOME/gnoland-secrets-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "$backup" -C "$GNOLAND_HOME" secrets
        chmod 600 "$backup"
        echo -e "${YELLOW}Node secrets copied to $backup${RESET}"
        echo -e "${RED}Move it somewhere safe and offline.${RESET}"
    else
        echo -e "${RED}No secrets directory found at $GNOLAND_HOME/secrets. Deploy node first.${RESET}"
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
    sudo systemctl restart "$GNOLAND_SERVICE_NAME"
    echo -e "${GREEN}${GNOLAND_SERVICE_NAME}.service restarted.${RESET}"
    menu
}

function stop_gnoland() {
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Stop blocked to protect the other instance.${RESET}"
        menu
        return
    fi
    sudo systemctl stop "$GNOLAND_SERVICE_NAME"
    echo -e "${YELLOW}${GNOLAND_SERVICE_NAME}.service stopped.${RESET}"
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
    canonical_node_home=$(realpath -m "$GNOLAND_HOME")
    case "$canonical_node_home" in
        "$canonical_home"/*) ;;
        *)
            echo -e "${RED}Delete blocked: node path is outside $HOME.${RESET}"
            menu
            return
            ;;
    esac
    sudo systemctl stop "$GNOLAND_SERVICE_NAME" || true
    sudo systemctl disable "$GNOLAND_SERVICE_NAME" || true
    sudo rm -f "/etc/systemd/system/${GNOLAND_SERVICE_NAME}.service"
    sudo systemctl daemon-reload
    rm -rf "$GNOLAND_HOME"
    rm -f "$GNOLAND_GENESIS"
    rm -f "$GNOLAND_BIN" "$GNOKEY_BIN"
    sed -i '/GNOLAND_/d;/GNOKEY_/d;/GNO_SOURCE_DIR/d;/GNOROOT/d;/go\/bin/d' "$HOME/.bash_profile"
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
    echo -e "${YELLOW}Candidate registration and snapshot application remain disabled until their funding/provider facts are independently verified.${RESET}"
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
    echo "   1b. Update Gnoland/Gnokey from Pinned Mainnet Release"
    echo "   1c. Apply Snapshot"
    echo "   1d. Add/Reset Peers"
    echo "   1e. Show Node Status"
    echo "   1f. Show Node Logs"
    echo "   1g. Run Node Doctor (Read-only)"
    echo
    echo "2. Validator/Key Interactions"
    echo "   2a. Reuse/Recover/Create Operator Key"
    echo "   2b. Show Validator Consensus Pubkey"
    echo "   2c. Mainnet Validator Registration (disabled)"
    echo "   2d. Query / Show Mainnet Links"
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
        2d|2-d) query_balance_or_realm ;;
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
