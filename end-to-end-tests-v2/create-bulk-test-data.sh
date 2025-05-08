#!/bin/bash

# Load environment variables
source ./.env.local

# Min 2 Max 10
COUNT=10

export RPC_URL=http://127.0.0.1:8545
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export WORLD_ADDRESS=0x5fc8d32690cc91d4c39d9d3abcbd16989f875707

# Run the bulk create script
echo "Creating $COUNT instances of each entity type..."
forge script script/BulkCreateTestData.s.sol:BulkCreateTestData \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --sig "run(address,uint256)" $WORLD_ADDRESS $COUNT \
  --gas-price 0 \
  -vvv

echo "Bulk test data creation complete!" 
