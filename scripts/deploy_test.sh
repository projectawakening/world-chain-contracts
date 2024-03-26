#!/bin/bash

# Fresh install
pnpm install

# Navigate to standard-contracts and setup environment
cd standard-contracts

pnpm run build
pnpm run deploy

wait
# Capture ForwarderAddress from JSON file
NEW_FORWARDER_ADDRESS=$(cat broadcast/Deploy.s.sol/31337/run-latest.json | jq '.transactions|first|.contractAddress' | tr -d \") 

echo "==================== Forwarder Contract Deployed ===================="
echo "Forwarder Address: $NEW_FORWARDER_ADDRESS"

# Navigate to mud-contracts/core and deploy
cd ../mud-contracts/core/
pnpm run deploy:local

# Capture WorldContract Address from JSON file
NEW_WORLD_ADDRESS=$(cat deploys/31337/latest.json | jq '.worldAddress' | tr -d \")


echo "==================== World Contract Deployed ===================="
echo "World Address: $NEW_WORLD_ADDRESS"

wait

# Update the .env file with ForwarderAddress
sed -i '' "s/^FORWARDER_ADDRESS=.*/FORWARDER_ADDRESS=$NEW_FORWARDER_ADDRESS/" .env
sed -i '' "s/^WORLD_ADDRESS=.*/WORLD_ADDRESS=$NEW_WORLD_ADDRESS/" .env

# Set forwarder and deploy frontier-world
pnpm run setForwarder

# Deploy frontier-world
echo "==================== Deploying Frontier World ===================="
cd ../frontier-world
pnpm run deploy:local --worldAddress $NEW_WORLD_ADDRESS

# Navigate back to standard-contracts
cd ../../standard-contracts/

# Update .env file in standard-contracts with WorldAddress
sed -i '' "s/^FORWARDER_ADDRESS=.*/FORWARDER_ADDRESS=$NEW_FORWARDER_ADDRESS/" .env
sed -i '' "s/^WORLD_ADDRESS=.*/WORLD_ADDRESS=$NEW_WORLD_ADDRESS/" .env

# Run callWorld
pnpm run callWorld