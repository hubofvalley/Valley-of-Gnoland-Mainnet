#!/bin/bash

set -euo pipefail

readonly EXPECTED_CHAIN_ID="gnoland-1"
readonly SNAPSHOT_STATUS="disabled"
SNAPSHOT_PROVIDER=""
SNAPSHOT_URL=""
SNAPSHOT_AVAILABLE=0

reset_snapshot_metadata() {
    SNAPSHOT_PROVIDER=""
    SNAPSHOT_URL=""
    SNAPSHOT_AVAILABLE=0
}

show_snapshot_stats() {
    echo "Network: $EXPECTED_CHAIN_ID"
    echo "Status: $SNAPSHOT_STATUS"
    echo "Provider: ${SNAPSHOT_PROVIDER:-none}"
    echo "Available: $SNAPSHOT_AVAILABLE"
    echo "URL: ${SNAPSHOT_URL:-none}"
    echo "Reason: no verified gnoland-1 snapshot provider is configured"
}

# This is intentionally a closed gate. A future implementation must add a
# reviewed provider, metadata checks, archive checks, and rollback tests before
# this function is changed.
load_verified_gnoland_snapshot() {
    reset_snapshot_metadata
    echo "No verified gnoland-1 snapshot provider is configured." >&2
    return 1
}

show_menu() {
    echo "Snapshot application is disabled for $EXPECTED_CHAIN_ID."
    echo "No verified $EXPECTED_CHAIN_ID provider is configured."
    echo "1. Exit"
}

apply_snapshot() {
    show_snapshot_stats
    echo "Snapshot application failed closed. No download, service stop, or node-data change was attempted." >&2
    return 1
}

main() {
    show_menu
    read -r -p "Enter your choice: " provider_choice
    case "$provider_choice" in
        1) echo "Exiting."; return 0 ;;
        *) echo "Invalid choice. Exiting." >&2; return 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
