#!/bin/bash
set -eou pipefail
# Fresh install
pnpm install

# Tooling

# Function to print formatted instructions
print_instruction() {
    echo -e "\n===================================================================================================="
    echo -e "|| $1"
    echo -e "===================================================================================================="
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

# Export local env variables for local dev

rpc_url=""
private_key=""

# Parse command-line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --rpc-url)
            rpc_url="$2"
            shift 2
            ;;
        --private-key)
            private_key="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done


if [ -z "$rpc_url" ]; then
    echo "RPC URL must be provided with --rpc-url"
    exit 1
fi

# Fetch and export the chain ID
chain_id=$(get_chain_id "$rpc_url")
echo "Using chain ID: $chain_id"

# Export assigned parameters to RPC_URL and PRIVATE_KEY variables
export RPC_URL="$rpc_url"
export PRIVATE_KEY="$private_key"

# Build everything
echo "------------------------- Building all packages ---------------------"
pnpm nx run-many -t build
wait
echo "==================== Packages successfully built ===================="


# Deploy the standard contracts
echo "------------------------- Deploying forwarder contract ---------------------"
pnpm nx run @eveworld/standard-contracts:deploy
wait

export FORWARDER_ADDRESS=$(cat ./standard-contracts/broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq '.transactions|first|.contractAddress' | tr -d \") 

echo "==================== Forwarder contract deployed ===================="
echo "Forwarder Address: $FORWARDER_ADDRESS"



echo "------------------------- Deploying world core ---------------------"
# pnpm nx run-many -t deploy --projects "standard-contracts/**"
pnpm nx deploy @eveworld/world-core
wait
export WORLD_ADDRESS=$(cat ./mud-contracts/core/deploys/$chain_id/latest.json | jq '.worldAddress' | tr -d \")

echo "==================== World Core deployed ===================="
echo "World Address: $WORLD_ADDRESS"


echo "------------------------- Configuring trusted forwarder ---------------------"
pnpm nx setForwarder @eveworld/world-core
echo "==================== Trusted forwarder configured ===================="

echo "---------------------- Deploying smart object framework ---------------------"
pnpm nx deploy @eveworld/smart-object-framework --worldAddress '${WORLD_ADDRESS}'
wait
echo "==================== Smart object framework deployed ===================="


echo "==================== Deploying world modules ===================="
pnpm nx deploy @eveworld/world --worldAddress '${WORLD_ADDRESS}'


echo "==================== Delegate access to Forwarder Contract ===================="
pnpm nx delegateNamespaceAccess @eveworld/world-core


echo "World address: $WORLD_ADDRESS"
echo "Trusted forwarder address: $FORWARDER_ADDRESS" 
