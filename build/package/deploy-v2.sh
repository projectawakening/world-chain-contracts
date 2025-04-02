#!/bin/sh
set -eou pipefail

# Define the log file
LOG_FILE="./logfile.log"
mkdir -p logs

# Ensure the log file is copied to the logs folder on exit
trap 'cp $LOG_FILE "logs/$(date +%Y%m%d_%H%M%S)-deploy-in-docker-v2.log"' EXIT

# Source common code
[ -f "$(dirname "$0")/common.sh" ] && . "$(dirname "$0")/common.sh"

# Parse command line arguments
parse_arguments "$@"

# Fetch and export the chain ID
chain_id=$(get_chain_id "$rpc_url")
wait
echo "Using chain ID: $chain_id" | tee -a $LOG_FILE

export RPC_URL="$rpc_url"
export PRIVATE_KEY="$private_key"
 
#1 Deploying the standard contracts
echo " - Deploying standard contracts..." | tee -a $LOG_FILE
pnpm nx run @eveworld/standard-contracts-v2:deploy >> $LOG_FILE 2>&1
wait
show_progress 1 9 "Standard contracts deployed"

export FORWARDER_ADDRESS=$(cat ./standard-contracts-v2/broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq '.transactions|first|.contractAddress' | tr -d \") 

#2 Deploy the world core
#
# If the world address was not set by a parameter we deploy a new core
# If the world address was passed as a parameter we are updating that world
echo " - Deploying world core..." | tee -a $LOG_FILE
if [ -z "$world_address" ]; then
    # If not set, execute a command to obtain the value
    echo "No world address parameter set - Deploying a new world..." | tee -a $LOG_FILE
    pnpm nx deploy @eveworld/world-core-v2 >> $LOG_FILE 2>&1
    wait
    show_progress 2 9 "World core deployed"
    world_address=$(cat ./mud-contracts/core-v2/deploys/$chain_id/latest.json | jq '.worldAddress' | tr -d \")
    export WORLD_ADDRESS="$world_address"
else
    # If set, use that value
    export WORLD_ADDRESS="$world_address"
    echo "World address parameter set - Updating the world @ ${WORLD_ADDRESS}..." | tee -a $LOG_FILE
    pnpm nx deploy @eveworld/world-core-v2 --worldAddress '${WORLD_ADDRESS}' >> $LOG_FILE 2>&1
    wait
    show_progress 2 9 "World core deployed"
fi

#3 Configure the world to receive the forwarder
echo " - Configuring trusted forwarder within the world" | tee -a $LOG_FILE
pnpm nx setForwarder @eveworld/world-core-v2 >> $LOG_FILE 2>&1

wait
show_progress 3 9 "Trusted forwarder configured"

echo " - World address: $WORLD_ADDRESS" | tee -a $LOG_FILE

#4 Deploy smart object framework v2
echo " - Installing smart object framework v2 into world" | tee -a $LOG_FILE
pnpm nx deploy @eveworld/smart-object-framework-v2 --worldAddress '${WORLD_ADDRESS}' >> $LOG_FILE 2>&1

wait
show_progress 4 9 "Smart object framework v2 deployed"

#5 Deploy world v2
echo " - Deploying world v2" | tee -a $LOG_FILE
deployment_output=$(pnpm nx deploy @eveworld/world-v2 --worldAddress '${WORLD_ADDRESS}' 2>&1 | tee -a $LOG_FILE)

wait
show_progress 5 9 "World v2 deployed"

#6 Configure Smart Object Framework access control
echo " - Configuring access control for smart object framework v2" | tee -a $LOG_FILE
pnpm nx configure-access @eveworld/smart-object-framework-v2 >> $LOG_FILE 2>&1

wait
show_progress 6 9 "Configured smart object framework v2 access control" 

#7 Configure Smart Object Framework v2 Rules for World v2
echo " - Configuring Smart Object Framework v2 Rules for World v2" | tee -a $LOG_FILE
pnpm nx config @eveworld/world-v2 >> $LOG_FILE 2>&1

wait
show_progress 7 9 "Configured Smart Object Framework v2 Rules for World v2"
echo " - World v2 configured with Smart Object Framework v2" | tee -a $LOG_FILE


# Extract the ERC20 token address from the output
eve_token_address=$(echo "$deployment_output" \
  | grep "Deploying ERC20 token with address:" \
  | grep -oE "0x[0-9a-fA-F]{40}")

if [ -z "$eve_token_address" ]; then
  echo "Error: Failed to extract EVE token address from deployment output." | tee -a $LOG_FILE
  exit 1
fi
export EVE_TOKEN_ADDRESS="$eve_token_address"

wait
show_progress 6 9 "EVE token deployed"

#8 Delegate Namespace Access
echo " - Delegating namespace access to forwarder contract" | tee -a $LOG_FILE
pnpm nx delegateNamespaceAccess @eveworld/world-core-v2 >> $LOG_FILE 2>&1

wait
show_progress 7 9 "Namespace access delegated"


echo " - Collecting ABIs" | tee -a $LOG_FILE
mkdir -p abis
mkdir -p abis/trusted-forwarder
mkdir -p abis/world
# 9 Copy ABIS to be used for External consumption
cp standard-contracts-v2/out/ERC2771ForwarderWithHashNonce.sol/ERC2771Forwarder.abi.json "abis/trusted-forwarder/ERC2771Forwarder-v2-${IMAGE_TAG}.abi.json"
cp build/artifacts/IWorld-v2.abi.json "abis/world/IWorld-v2-${IMAGE_TAG}.abi.json"
cp build/artifacts/ERC2771IWorld-v2.abi.json "abis/world/ERC2771IWorld-v2-${IMAGE_TAG}.abi.json"

# Custom ERC2771 Compatible IWorld contract
jq 'map((.name? |= gsub("^evefrontier__"; "")) // .)' "abis/world/IWorld-v2-${IMAGE_TAG}.abi.json" > "abis/world/ERC2771IWorld-v2-${IMAGE_TAG}.abi.json"


# Update run_env.json with the extracted addresses
echo '{"WORLD_ADDRESS":"'$WORLD_ADDRESS'", "FORWARDER_ADDRESS":"'$FORWARDER_ADDRESS'", "EVE_TOKEN_ADDRESS":"'$EVE_TOKEN_ADDRESS'"}' > run_env.json

echo "World v2 address: $WORLD_ADDRESS" | tee -a $LOG_FILE
echo "Trusted forwarder address: $FORWARDER_ADDRESS" | tee -a $LOG_FILE
echo "EVE token address: $EVE_TOKEN_ADDRESS" | tee -a $LOG_FILE 
