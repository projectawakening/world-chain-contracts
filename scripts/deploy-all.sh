#!/bin/bash

# Fresh install
pnpm install

# Tooling

# Function to print formatted instructions
print_instruction() {
    echo -e "\n===================================================================================================="
    echo -e "|| $1"
    echo -e "===================================================================================================="
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
pnpm nx run @eve/frontier-standard-contracts:deploy
wait

export FORWARDER_ADDRESS=$(cat ./standard-contracts/broadcast/Deploy.s.sol/31337/run-latest.json | jq '.transactions|first|.contractAddress' | tr -d \") 

echo "==================== Forwarder contract deployed ===================="
echo "Forwarder Address: $FORWARDER_ADDRESS"



echo "------------------------- Deploying world core ---------------------"
# pnpm nx run-many -t deploy --projects "standard-contracts/**"
pnpm nx deploy @eve/frontier-world-core
wait
export WORLD_ADDRESS=$(cat ./mud-contracts/core/deploys/31337/latest.json | jq '.worldAddress' | tr -d \")

echo "==================== World Core deployed ===================="
echo "World Address: $WORLD_ADDRESS"


echo "------------------------- Configuring trusted forwarder ---------------------"
pnpm nx setForwarder @eve/frontier-world-core
echo "==================== Trusted forwarder configured ===================="

echo "---------------------- Deploying smart object framework ---------------------"
pnpm nx deploy @eve/frontier-smart-object-framework --worldAddress '${WORLD_ADDRESS}'
wait
echo "==================== Smart object framework deployed ===================="


echo "==================== Deploying Frontier world modules ===================="
pnpm nx deploy @eve/frontier-world --worldAddress '${WORLD_ADDRESS}'


echo "World address: $WORLD_ADDRESS"
echo "Trusted forwarder address: $FORWARDER_ADDRESS" 

