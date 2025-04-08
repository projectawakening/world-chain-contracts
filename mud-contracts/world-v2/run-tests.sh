#!/bin/bash
set -e

# Start anvil with the saved state
echo "Starting Anvil node with saved smart object framework snapshot..."
anvil --gas-limit 120000000 --load-state sof-state.json > /dev/null 2>&1 &
ANVIL_PID=$!

# Wait for anvil to initialize
echo "Waiting for Anvil to initialize..."
sleep 2

# Check if Anvil is running properly
if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://127.0.0.1:8545 > /dev/null; then
  echo "ERROR: Anvil node failed to start properly."
  kill $ANVIL_PID 2>/dev/null || true
  exit 1
fi

# Print latest block for debugging
LATEST_BLOCK=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://127.0.0.1:8545 | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
echo "Latest block: $LATEST_BLOCK"

# Run the world tests
echo "Running world tests..."
export WORLD_ADDRESS=0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export RPC_URL=http://127.0.0.1:8545
export ERC20_TOKEN_NAME=TEST TOKEN
export ERC20_TOKEN_SYMBOL=TEST
export ERC20_INITIAL_SUPPLY=10000000000
export EVE_TOKEN_NAMESPACE=test
export EVE_TOKEN_ADMIN=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export TENANT=TEST
export CHARACTER_TYPE_ID=1
export CHARACTER_VOLUME=0
export SSU_TYPE_ID=2
export SSU_VOLUME=1000
export DEPLOYABLE_TYPE_ID=3
export DEPLOYABLE_VOLUME=0
export TURRET_TYPE_ID=4
export TURRET_VOLUME=1000
export GATE_TYPE_ID=5
export GATE_VOLUME=10000

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