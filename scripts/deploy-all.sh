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


# Build the standard contracts
echo "------------------------- Deploying forwarder contract ---------------------"
pnpm nx run @eve/frontier-standard-contracts:build
pnpm nx run @eve/frontier-standard-contracts:deploy
wait

export FORWARDER_ADDRESS=$(cat ./standard-contracts/broadcast/Deploy.s.sol/31337/run-latest.json | jq '.transactions|first|.contractAddress' | tr -d \") 

echo "==================== Forwarder contract deployed ===================="
echo "Forwarder Address: $FORWARDER_ADDRESS"



echo "------------------------- Deploying world core ---------------------"
# pnpm nx run-many -t deploy --projects "standard-contracts/**"
pnpm nx deploy:local @eve/frontier-world-core
wait
export WORLD_ADDRESS=$(cat ./mud-contracts/core/deploys/31337/latest.json | jq '.worldAddress' | tr -d \")

echo "==================== World Core deployed ===================="
echo "World Address: $WORLD_ADDRESS"


echo "------------------------- Configuring trusted forwarder ---------------------"
pnpm nx setForwarder @eve/frontier-world-core
echo "==================== Trusted forwarder configured ===================="

echo "==================== Deploying Frontier world modules ===================="
pnpm nx deploy:local @eve/frontier-world --worldAddress '${WORLD_ADDRESS}'
