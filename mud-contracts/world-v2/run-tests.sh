#!/bin/bash

# Start anvil with the saved state
echo "Starting Anvil node with saved smart object framework snapshot..."
anvil --load-state sof-state.json --block-time 1 > anvil.log 2>&1 &
ANVIL_PID=$!

# Wait for anvil to initialize
echo "Waiting for Anvil to initialize..."
sleep 3

# Check if Anvil is running properly
if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://127.0.0.1:8545 > /dev/null; then
  echo "ERROR: Anvil node failed to start properly. Check anvil.log for details."
  cat anvil.log
  kill $ANVIL_PID 2>/dev/null || true
  exit 1
fi

# Print latest block for debugging
LATEST_BLOCK=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://127.0.0.1:8545 | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
echo "Latest block: $LATEST_BLOCK"

# Run the world tests
echo "Running world tests..."
export WORLD_ADDRESS=0x5fc8d32690cc91d4c39d9d3abcbd16989f875707
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export RPC_URL=http://127.0.0.1:8545

# Run deployments and tests
echo "Running deployment..."
pnpm run deploy --worldAddress $WORLD_ADDRESS || { echo "Deployment failed"; kill $ANVIL_PID; exit 1; }

echo "Running config..."
pnpm run config || { echo "Config failed"; kill $ANVIL_PID; exit 1; }

echo "Running tests..."
pnpm run test:world || { echo "Tests failed"; kill $ANVIL_PID; exit 1; }

# Kill anvil process
echo "Tests completed. Shutting down Anvil."
kill $ANVIL_PID 