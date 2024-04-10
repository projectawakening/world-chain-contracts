#!/bin/bash

# Fresh install
pnpm install

# Navigate to standard-contracts and setup environment
cd standard-contracts
pnpm run build
pnpm run deploy

wait
# Capture ForwarderAddress from JSON file
export FORWARDER_ADDRESS=$(cat broadcast/Deploy.s.sol/31337/run-latest.json | jq '.transactions|first|.contractAddress' | tr -d \") 

echo "==================== Forwarder Contract Deployed ===================="
echo "Forwarder Address: $FORWARDER_ADDRESS"

# Navigate to mud-contracts/core and deploy
cd ../mud-contracts/core/
pnpm run deploy:local

# Capture WorldContract Address from JSON file
export WORLD_ADDRESS_DEPLOYMENT=$(cat deploys/31337/latest.json | jq '.worldAddress' | tr -d \")


echo "==================== World Contract Deployed ===================="
echo "World Address: $WORLD_ADDRESS_DEPLOYMENT"

wait

# Set forwarder and deploy frontier-world
pnpm run setForwarder

wait 
# Deploy frontier-world
echo "==================== Deploying Frontier World ===================="
cd ../frontier-world
pnpm run deploy:local --worldAddress $WORLD_ADDRESS_DEPLOYMENT

# Navigate back to standard-contracts
cd ../../standard-contracts/

# Run callWorld
pnpm run callWorld
