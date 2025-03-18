#!/bin/sh
set -eou pipefail

# Define the log file
LOG_FILE="./logfile.log"
mkdir -p logs

# Ensure the log file is copied to the logs folder on exit
trap 'cp $LOG_FILE "logs/$(date +%Y%m%d_%H%M%S)-deploy-in-docker.log"' EXIT

bar_size=40
bar_char_done="#"
bar_char_todo="-"
bar_percentage_scale=2


show_progress() {
    current="$1"
    total="$2"

    # calculate the progress in percentage using awk for floating point arithmetic with fixed precision
    percent=$(awk -v current="$current" -v total="$total" \
        'BEGIN {printf "%.2f", (100 * current / total)}')

    # Calculate the number of done and todo characters using awk
    done=$(awk -v percent="$percent" -v bar_size="$bar_size" 'BEGIN {printf "%d", int(bar_size * percent / 100)}')
    todo=$(awk -v done="$done" -v bar_size="$bar_size" 'BEGIN {printf "%d", int(bar_size - done)}')

    # Build the done and todo sub-bars
    done_sub_bar=$(printf "%${done}s" | tr " " "$bar_char_done")
    todo_sub_bar=$(printf "%${todo}s" | tr " " "$bar_char_todo")

    # Output the bar
    printf "\rProgress : [${done_sub_bar}${todo_sub_bar}] ${percent}%%"

    if [ "$total" -eq "$current" ]; then
        printf "\nSuccess: World deployed\n"
    fi
}


# Function to get chain ID from RPC URL
get_chain_id() {
    local rpc_url=$1
    # Perform the curl request and check if it was successful
    local response=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' -H "Content-Type: application/json" $rpc_url)
    local success=$?

    # Check if curl command was successful (exit code 0)
    if [ $success -ne 0 ]; then
        echo "Error: Failed to fetch chain ID from RPC URL: $rpc_url" | tee -a $LOG_FILE
        return 1
    fi

    # Extract the result and handle the case where no result is found
    local chain_id_hex=$(echo "$response" | jq -r '.result')
    if [ "$chain_id_hex" = "null" ] || [ -z "$chain_id_hex" ]; then
        echo "Error: No valid chain ID returned from the RPC URL: $rpc_url" | tee -a $LOG_FILE
        return 1
    fi

    # Remove the '0x' prefix if present and convert hex to decimal
    local chain_id_decimal=$(echo "$chain_id_hex" | sed 's/0x//')
    echo "$((16#$chain_id_decimal))"
}

# Default values
rpc_url=""
private_key=""
world_address=""

# Parse command-line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -p1|--rpc-url)
            rpc_url="$2"
            shift 2
            ;;
        -p2|--private-key)
            private_key="$2"
            shift 2
            ;;
        -wa|--world-address)
            world_address="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" | tee -a $LOG_FILE
            exit 1
            ;;
    esac
done


# Fetch and export the chain ID
chain_id=$(get_chain_id "$rpc_url")
wait
echo "Using chain ID: $chain_id" | tee -a $LOG_FILE

## Temporarily hardcode private key and rpc url before adding them as params
export RPC_URL="$rpc_url"
export PRIVATE_KEY="$private_key"

# Validate world address format if provided
if [ ! -z "$world_address" ]; then
    if [[ ! "$world_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo "Error: Invalid world address format. Must be a valid Ethereum address (0x... with 40 hex characters)" | tee -a $LOG_FILE
        exit 1
    fi
fi

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
