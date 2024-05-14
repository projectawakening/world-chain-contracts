#!/bin/sh


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
        printf "\nSuccess: Frontier world deployed\n"
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
        echo "Error: Failed to fetch chain ID from RPC URL: $rpc_url"
        return 1
    fi

    # Extract the result and handle the case where no result is found
    local chain_id_hex=$(echo "$response" | jq -r '.result')
    if [ "$chain_id_hex" = "null" ] || [ -z "$chain_id_hex" ]; then
        echo "Error: No valid chain ID returned from the RPC URL: $rpc_url"
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
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done


# Fetch and export the chain ID
chain_id=$(get_chain_id "$rpc_url")
wait
echo "Using chain ID: $chain_id"

## Temporarily hardcode private key and rpc url before adding them as params
export RPC_URL="$rpc_url"
export PRIVATE_KEY="$private_key"

show_progress 0 6


#1 Deploying the standard contracts
echo " - Deploying standard contracts..."
pnpm nx run @eve/frontier-standard-contracts:deploy 1> '/dev/null'
wait
show_progress 1 6

export FORWARDER_ADDRESS=$(cat ./standard-contracts/broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq '.transactions|first|.contractAddress' | tr -d \") 

#2 Deploy the world core
#
# If the world address was not set by a parameter we deploy a new core
# If the world address was passed as a parameter we are updating that world
echo " - Deploying frontier world..."
if [ -z "$world_address" ]; then
    # If not set, execute a command to obtain the value
    echo "No world address parameter set - Deploying a new frontier world..."
    pnpm nx deploy @eve/frontier-world-core 1> '/dev/null'
    wait
    show_progress 2 6
    world_address=$(cat ./mud-contracts/core/deploys/$chain_id/latest.json | jq '.worldAddress' | tr -d \")
    export WORLD_ADDRESS="$world_address"
else
    # If set, use that value
    export WORLD_ADDRESS="$world_address"
    echo "World address parameter set - Updating the world @ ${WORLD_ADDRESS}..."
    pnpm nx deploy @eve/frontier-world-core --worldAddress '${WORLD_ADDRESS}' 1> '/dev/null'
    wait
    show_progress 2 6
fi

#3 Configure the world to receive the forwarder
echo " - Configuring trusted forwarder within the world"
pnpm nx setForwarder @eve/frontier-world-core 1> '/dev/null'

wait
show_progress 3 6


#4 Deploy smart object framework 
#
# TODO stop using :local for all the 
echo " - Installing smart object framework into world"
pnpm nx deploy @eve/frontier-smart-object-framework --worldAddress '${WORLD_ADDRESS}' 1> '/dev/null'
show_progress 4 6

#5 Deploy Frontier world features
echo " - Deploying world features"
pnpm nx deploy @eve/frontier-world --worldAddress '${WORLD_ADDRESS}' &> '/dev/null'
show_progress 5 6

echo " - Collecting ABIs"
mkdir abis
mkdir abis/trusted-forwarder
mkdir abis/frontier-world

# Copy ABIS to be used for External consumption
cp standard-contracts/out/ERC2771ForwarderWithHashNonce.sol/ERC2771Forwarder.abi.json "abis/trusted-forwarder/ERC2771Forwarder-v${IMAGE_TAG}.abi.json"
cp mud-contracts/frontier-world/out/IWorld.sol/IWorld.abi.json "abis/frontier-world/IWorld-v${IMAGE_TAG}.abi.json"
# Custome ERC2771 Compatible IWorld contract
jq 'map((.name? |= gsub("^frontier__"; "")) // .)' "abis/frontier-world/IWorld-v${IMAGE_TAG}.abi.json" > "abis/frontier-world/ERC2771IWorld-v${IMAGE_TAG}.abi.json"


show_progress 6 6

echo '{"WORLD_ADDRESS":"'$WORLD_ADDRESS'", "FORWARDER_ADDRESS":"'$FORWARDER_ADDRESS'"}' > run_env.json
echo "World address: $WORLD_ADDRESS"
echo "Trusted forwarder address: $FORWARDER_ADDRESS" 
