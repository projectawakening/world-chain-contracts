#!/bin/bash

# Start anvil in a separate process
echo "Starting Anvil node..."
anvil --dump-state sof-state.json > /dev/null 2>&1 &
ANVIL_PID=$!

# Wait for anvil to start
sleep 2


# Deploy the framework contracts
echo "Deploying smart-object-framework contracts..."
# Set the private key and rpc url
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export RPC_URL=http://127.0.0.1:8545

echo $PRIVATE_KEY
echo $RPC_URL
pnpm install
pnpm nx build @eveworld/smart-object-framework-v2
pnpm nx deploy @eveworld/smart-object-framework-v2

export WORLD_ADDRESS=$(cat ./deploys/31337/latest.json | jq '.worldAddress' | tr -d \")

echo "World address: $WORLD_ADDRESS"

pnpm nx run @eveworld/smart-object-framework-v2:configure-access

# Kill anvil process
kill $ANVIL_PID

echo "Framework state saved to sof-state.json" 