#!/bin/bash
set -eou pipefail

# Define the log file
LOG_FILE="./logfile.log"
mkdir -p logs

# Ensure the log file is copied to the logs folder on exit
trap 'cp $LOG_FILE "logs/$(date +%Y%m%d_%H%M%S)-deploy-in-docker.log"' EXIT

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

# Validate world address format if provided
validate_eth_address "$world_address"

show_progress 0 8

#1 Deploying the standard contracts
echo " - Deploying standard contracts..." | tee -a $LOG_FILE
pnpm nx run @eveworld/standard-contracts:deploy >> $LOG_FILE 2>&1
wait
show_progress 1 8

export FORWARDER_ADDRESS=$(cat ./standard-contracts/broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq '.transactions|first|.contractAddress' | tr -d \") 

#2 Deploy the world core
#
# If the world address was not set by a parameter we deploy a new core
# If the world address was passed as a parameter we are updating that world
echo " - Deploying world..." | tee -a $LOG_FILE
if [ -z "$world_address" ]; then
    # If not set, execute a command to obtain the value
    echo "No world address parameter set - Deploying a new world..." | tee -a $LOG_FILE
    pnpm nx deploy @eveworld/world-core >> $LOG_FILE 2>&1
    wait
    show_progress 2 8
    world_address=$(cat ./mud-contracts/core/deploys/$chain_id/latest.json | jq '.worldAddress' | tr -d \")
    export WORLD_ADDRESS="$world_address"
else
    # If set, use that value
    export WORLD_ADDRESS="$world_address"
    echo "World address parameter set - Updating the world @ ${WORLD_ADDRESS}..." | tee -a $LOG_FILE
    pnpm nx deploy @eveworld/world-core --worldAddress '${WORLD_ADDRESS}' >> $LOG_FILE 2>&1
    wait
    show_progress 2 8
fi

#3 Configure the world to receive the forwarder
echo " - Configuring trusted forwarder within the world" | tee -a $LOG_FILE
pnpm nx setForwarder @eveworld/world-core >> $LOG_FILE 2>&1

wait
show_progress 3 8

#4 Deploy smart object framework 
#
echo " - Installing smart object framework into world" | tee -a $LOG_FILE
pnpm nx deploy @eveworld/smart-object-framework --worldAddress '${WORLD_ADDRESS}' >> $LOG_FILE 2>&1
show_progress 4 8

#5 Deploy world features
echo " - Deploying world features" | tee -a $LOG_FILE
deployment_output=$(pnpm nx deploy @eveworld/world --worldAddress '${WORLD_ADDRESS}' 2>&1 | tee -a $LOG_FILE)

# Extract the ERC721 token address from the output
smart_deployable_token_address=$(echo "$deployment_output" \
  | grep "Deploying Smart Deployable token with address:" \
  | grep -oE "0x[0-9a-fA-F]{40}")
if [ -z "$smart_deployable_token_address" ]; then
  echo "Error: Failed to extract Deployable token address from deployment output." | tee -a $LOG_FILE
  exit 1
fi
export SMART_DEPLOYABLE_TOKEN_ADDRESS="$smart_deployable_token_address"

smart_character_token_address=$(echo "$deployment_output" \
  | grep "Deploying Smart Character token with address:" \
  | grep -oE "0x[0-9a-fA-F]{40}")

if [ -z "$smart_character_token_address" ]; then
  echo "Error: Failed to extract Smart Character token address from deployment output." | tee -a $LOG_FILE
  exit 1
fi
export SMART_CHARACTER_TOKEN_ADDRESS="$smart_character_token_address"

eve_token_address=$(echo "$deployment_output" \
  | grep "Deploying ERC20 token with address:" \
  | grep -oE "0x[0-9a-fA-F]{40}")

if [ -z "$eve_token_address" ]; then
  echo "Error: Failed to extract EVE token address from deployment output." | tee -a $LOG_FILE
  exit 1
fi
export EVE_TOKEN_ADDRESS="$eve_token_address"

wait
show_progress 5 8

#6 Delegate Namespace Access
echo " - Delegating namespace access to forwarder contract" | tee -a $LOG_FILE
pnpm nx delegateNamespaceAccess @eveworld/world-core >> $LOG_FILE 2>&1
show_progress 6 8

#7 Setup access control
echo " - Setting up access control" | tee -a $LOG_FILE
pnpm nx access-config:configure-all @eveworld/world > /dev/null >> $LOG_FILE 2>&1

wait
show_progress 7 8
echo " - Access controlled applied" | tee -a $LOG_FILE

echo " - Collecting ABIs" | tee -a $LOG_FILE
mkdir -p abis
mkdir -p abis/trusted-forwarder
mkdir -p abis/world

# 8 Copy ABIS to be used for External consumption
cp standard-contracts/out/ERC2771ForwarderWithHashNonce.sol/ERC2771Forwarder.abi.json "abis/trusted-forwarder/ERC2771Forwarder-${IMAGE_TAG}.abi.json"
cp mud-contracts/world/out/IWorld.sol/IWorld.abi.json "abis/world/IWorld-${IMAGE_TAG}.abi.json"

# Custom ERC2771 Compatible IWorld contract
jq 'map((.name? |= gsub("^eveworld__"; "")) // .)' "abis/world/IWorld-${IMAGE_TAG}.abi.json" > "abis/world/ERC2771IWorld-${IMAGE_TAG}.abi.json"

show_progress 8 8

# Update run_env.json with the extracted addresses
echo '{"WORLD_ADDRESS":"'$WORLD_ADDRESS'", "FORWARDER_ADDRESS":"'$FORWARDER_ADDRESS'", "EVE_TOKEN_ADDRESS":"'$EVE_TOKEN_ADDRESS'", "SMART_DEPLOYABLE_TOKEN_ADDRESS":"'$SMART_DEPLOYABLE_TOKEN_ADDRESS'", "SMART_CHARACTER_TOKEN_ADDRESS": "'$SMART_CHARACTER_TOKEN_ADDRESS'"}' > run_env.json

echo "World address: $WORLD_ADDRESS" | tee -a $LOG_FILE
echo "Trusted forwarder address: $FORWARDER_ADDRESS" | tee -a $LOG_FILE
echo "Smart Deployable token address: $SMART_DEPLOYABLE_TOKEN_ADDRESS" | tee -a $LOG_FILE
echo "Smart Character token address: $SMART_CHARACTER_TOKEN_ADDRESS" | tee -a $LOG_FILE
echo "EVE token address: $EVE_TOKEN_ADDRESS" | tee -a $LOG_FILE
