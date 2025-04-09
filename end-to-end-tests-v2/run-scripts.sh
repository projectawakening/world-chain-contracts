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
echo "Running end-to-end-tests..."
export WORLD_ADDRESS="0x5FC8d32690cc91D4c39d9d3abcBD16989F875707"
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export RPC_URL=http://127.0.0.1:8545
export ERC20_TOKEN_NAME="TEST TOKEN"
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

echo "Running world-v2 upgrade..."
pnpm nx run @eveworld/world-v2:upgrade || { echo "Upgrade failed"; kill $ANVIL_PID; exit 1; }

echo "Running post-deploy..."
pnpm nx run @eveworld/world-v2:post-deploy || { echo "Post-deploy failed"; kill $ANVIL_PID; exit 1; }

echo "Running config..."
pnpm nx run @eveworld/world-v2:config || { echo "Config failed"; kill $ANVIL_PID; exit 1; }

echo "Running scripts..."
forge script script/CreateSmartCharacter.s.sol:CreateSmartCharacter --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "CreateSmartCharacter script failed"; kill $ANVIL_PID; exit 1; }
forge script script/CreateMintERC20.s.sol:CreateMintERC20 --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "CreateMintERC20 script failed"; kill $ANVIL_PID; exit 1; }
forge script script/AnchorSSU.s.sol:AnchorSSU --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "AnchorSSU script failed"; kill $ANVIL_PID; exit 1; }
forge script script/DepositFuel.s.sol:DepositFuel --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "DepositFuel script failed"; kill $ANVIL_PID; exit 1; }
forge script script/BringOnline.s.sol:BringOnline --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "BringOnline script failed"; kill $ANVIL_PID; exit 1; }
forge script script/DepositToInventory.s.sol:DepositToInventory --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "DepositToInventory script failed"; kill $ANVIL_PID; exit 1; }
forge script script/DepositToEphemeral.s.sol:DepositToEphemeral --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "DepositToEphemeral script failed"; kill $ANVIL_PID; exit 1; }
forge script script/WithdrawFromInventory.s.sol:WithdrawFromInventory --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "WithdrawFromInventory script failed"; kill $ANVIL_PID; exit 1; }
forge script script/WithdrawFromEphemeral.s.sol:WithdrawFromEphemeral --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "WithdrawFromEphemeral script failed"; kill $ANVIL_PID; exit 1; }
forge script script/TransferItems.s.sol:TransferItems --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "TransferItems script failed"; kill $ANVIL_PID; exit 1; }
forge script script/AnchorSmartTurret.s.sol:AnchorSmartTurret --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "AnchorSmartTurret script failed"; kill $ANVIL_PID; exit 1; }
forge script script/ConfigureSmartTurret.s.sol:ConfigureSmartTurret --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "ConfigureSmartTurret script failed"; kill $ANVIL_PID; exit 1; }
forge script script/AnchorSmartGate.s.sol:AnchorSmartGate --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "AnchorSmartGate script failed"; kill $ANVIL_PID; exit 1; }
forge script script/ConfigureSmartGate.s.sol:ConfigureSmartGate --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(address)" $WORLD_ADDRESS -vvv || { echo "ConfigureSmartGate script failed"; kill $ANVIL_PID; exit 1; }

# Kill anvil process
echo "Tests completed. Shutting down Anvil."
kill $ANVIL_PID