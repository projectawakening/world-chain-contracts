#!/bin/bash

# Start anvil with the saved state
echo "Starting Anvil node with saved smart object frameowrk snapshot..."
anvil --load-state sof-state.json > /dev/null 2>&1 &
ANVIL_PID=$!

# Wait for anvil to start
sleep 2

# Run the world tests
echo "Running world tests..."
export WORLD_ADDRESS=0x5fc8d32690cc91d4c39d9d3abcbd16989f875707
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export RPC_URL=http://127.0.0.1:8545

pnpm run deploy --worldAddress $WORLD_ADDRESS
pnpm run config-sof
pnpm run test:world

# Kill anvil process
kill $ANVIL_PID 