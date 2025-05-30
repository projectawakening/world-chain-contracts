#!/bin/bash
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

# Function to validate and log environment variables
validate_and_log_env() {
    local var_name=$1
    local var_value=${!var_name}
    
    if [ -z "$var_value" ]; then
        echo "Error: Required environment variable $var_name is not set" | tee -a $LOG_FILE
        exit 1
    fi
    
    echo "Environment variable $var_name: $var_value" | tee -a $LOG_FILE
}

# Log all environment variables
echo "=== Required Environment Variables ===" | tee -a $LOG_FILE
validate_and_log_env "BASE_URI"
validate_and_log_env "ERC20_TOKEN_NAME"
validate_and_log_env "ERC20_TOKEN_SYMBOL"
validate_and_log_env "ERC20_INITIAL_SUPPLY"
validate_and_log_env "EVE_TOKEN_NAMESPACE"
validate_and_log_env "EVE_TOKEN_ADMIN"
validate_and_log_env "ADMIN_ACCOUNTS"
validate_and_log_env "TENANT"
validate_and_log_env "CHARACTER_TYPE_ID"
validate_and_log_env "CHARACTER_VOLUME"
validate_and_log_env "NETWORK_NODE_TYPE_ID"
validate_and_log_env "NETWORK_NODE_VOLUME"
validate_and_log_env "NETWORK_NODE_VOLUME"
validate_and_log_env "TYPE_IDS"
validate_and_log_env "ASSEMBLY_TYPE_ID"
validate_and_log_env "ENERGY_CONSTANT"
validate_and_log_env "FUEL_TYPE_ID"
validate_and_log_env "FUEL_EFFICIENCY"
validate_and_log_env "FUEL_VOLUME"
echo "===========================" | tee -a $LOG_FILE

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
show_progress 1 11 "Standard contracts deployed"

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
    show_progress 2 11 "World core deployed"
    world_address=$(cat ./mud-contracts/core-v2/deploys/$chain_id/latest.json | jq '.worldAddress' | tr -d \")
    export WORLD_ADDRESS="$world_address"
else
    # If set, use that value
    export WORLD_ADDRESS="$world_address"
    echo "World address parameter set - Updating the world @ ${WORLD_ADDRESS}..." | tee -a $LOG_FILE
    pnpm nx deploy @eveworld/world-core-v2 --worldAddress '${WORLD_ADDRESS}' >> $LOG_FILE 2>&1
    wait
    show_progress 2 11 "World core deployed"
fi

echo " - World address: $WORLD_ADDRESS" | tee -a $LOG_FILE

#3 Configure the world to receive the forwarder
echo " - Configuring trusted forwarder within the world" | tee -a $LOG_FILE
pnpm nx setForwarder @eveworld/world-core-v2 >> $LOG_FILE 2>&1

wait
show_progress 3 11 "Trusted forwarder configured"

#4 Deploy smart object framework v2
echo " - Installing smart object framework v2 into world" | tee -a $LOG_FILE
pnpm nx deploy @eveworld/smart-object-framework-v2 --worldAddress '${WORLD_ADDRESS}' >> $LOG_FILE 2>&1

wait
show_progress 4 11 "Smart object framework v2 deployed"

#5 Deploy world v2
echo " - Deploying world v2" | tee -a $LOG_FILE
deployment_output=$(pnpm nx deploy @eveworld/world-v2 --worldAddress '${WORLD_ADDRESS}' 2>&1 | tee -a $LOG_FILE)

wait
show_progress 5 11 "World v2 deployed"

#6 Configure Smart Object Framework access control
echo " - Configuring access control for smart object framework v2" | tee -a $LOG_FILE
pnpm nx configure-access @eveworld/smart-object-framework-v2 >> $LOG_FILE 2>&1

wait
show_progress 6 11 "Configured smart object framework v2 access control" 

#7 Configure Smart Object Framework v2 Rules for World v2
echo " - Configuring Smart Object Framework v2 Rules for World v2" | tee -a $LOG_FILE
pnpm nx config @eveworld/world-v2 >> $LOG_FILE 2>&1

wait
show_progress 7 11 "Configured Smart Object Framework v2 Rules for World v2"

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
show_progress 7 11 "EVE token deployed"

#8 Delegate Namespace Access and Grant Admin Access to 
echo " - Delegating namespace access to forwarder contract" | tee -a $LOG_FILE
pnpm nx delegateNamespaceAccess @eveworld/world-core-v2 >> $LOG_FILE 2>&1

wait
show_progress 8 11 "Namespace access delegated"

#9 Grant Admin Access to list of addresses
echo " - Granting admin access to list of addresses" | tee -a $LOG_FILE
pnpm nx grant-admin-access @eveworld/world-v2 >> $LOG_FILE 2>&1

wait
show_progress 9 11 "Admin access granted"

#10 Configure Fuel
echo " - Configuring fuel" | tee -a $LOG_FILE
pnpm nx configure-fuel @eveworld/world-v2 >> $LOG_FILE 2>&1

wait
show_progress 10 10 "Fuel configured"

#11 Configure Energy
echo " - Configuring energy" | tee -a $LOG_FILE
pnpm nx configure-energy @eveworld/world-v2 >> $LOG_FILE 2>&1

wait
show_progress 11 11 "Energy configured"


echo " - Collecting ABIs" | tee -a $LOG_FILE
mkdir -p abis
mkdir -p abis/trusted-forwarder
mkdir -p abis/world
#Copy ABIS to be used for External consumption
cp standard-contracts-v2/out/ERC2771ForwarderWithHashNonce.sol/ERC2771Forwarder.abi.json "abis/trusted-forwarder/ERC2771Forwarder-v2-${IMAGE_TAG}.abi.json"
cp build/artifacts/IWorld-v2.abi.json "abis/world/IWorld-v2-${IMAGE_TAG}.abi.json"
cp build/artifacts/ERC2771IWorld-v2.abi.json "abis/world/ERC2771IWorld-v2-${IMAGE_TAG}.abi.json"

# Custom ERC2771 Compatible IWorld contract
jq 'map((.name? |= gsub("^evefrontier__"; "")) // .)' "abis/world/IWorld-v2-${IMAGE_TAG}.abi.json" > "abis/world/ERC2771IWorld-v2-${IMAGE_TAG}.abi.json"

#Copy Systems.json for systemIds to be used for External consumption
cp mud-contracts/world-v2/.mud/local/systems.json "abis/world/systems.json"


# Update run_env.json with the extracted addresses
echo '{"WORLD_ADDRESS":"'$WORLD_ADDRESS'", "FORWARDER_ADDRESS":"'$FORWARDER_ADDRESS'", "EVE_TOKEN_ADDRESS":"'$EVE_TOKEN_ADDRESS'"}' > run_env.json

echo "World v2 address: $WORLD_ADDRESS" | tee -a $LOG_FILE
echo "Trusted forwarder address: $FORWARDER_ADDRESS" | tee -a $LOG_FILE
echo "EVE token address: $EVE_TOKEN_ADDRESS" | tee -a $LOG_FILE 
