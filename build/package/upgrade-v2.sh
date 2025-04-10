#!/bin/bash
set -eou pipefail

# Define the log file
LOG_FILE="./logfile.log"
mkdir -p logs

# Ensure the log file is copied to the logs folder on exit
trap 'cp $LOG_FILE "logs/$(date +%Y%m%d_%H%M%S)-upgrade-v2-in-docker.log"' EXIT

# Source common code
[ -f "$(dirname "$0")/common.sh" ] && . "$(dirname "$0")/common.sh"

# Parse command line arguments
parse_arguments "$@"

# Fetch and export the chain ID
chain_id=$(get_chain_id "$rpc_url")
wait
echo "Using chain ID: $chain_id" | tee -a $LOG_FILE

## Temporarily hardcode private key and rpc url before adding them as params
export RPC_URL="$rpc_url"
export PRIVATE_KEY="$private_key"
export WORLD_ADDRESS="$world_address"

# Validate world address format if provided
if [ ! -z "$world_address" ]; then
    if [[ ! "$world_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo "Error: Invalid world address format. Must be a valid Ethereum address (0x... with 40 hex characters)" | tee -a $LOG_FILE
        exit 1
    fi
fi
wait
show_progress 0 2   

#1 Upgrade smart object framework 
#
echo " - Upgrading smart object framework" | tee -a $LOG_FILE
pnpm nx deploy @eveworld/smart-object-framework-v2 --worldAddress '${WORLD_ADDRESS}' >> $LOG_FILE 2>&1

wait
show_progress 1 2

#2 Upgrade world features
echo " - Upgrading world features" | tee -a $LOG_FILE
pnpm nx upgrade @eveworld/world-v2 >> $LOG_FILE 2>&1

wait
show_progress 2 2

echo " - Upgrade completed successfully" | tee -a $LOG_FILE
