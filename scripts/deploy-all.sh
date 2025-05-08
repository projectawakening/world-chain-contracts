#!/bin/bash
set -eou pipefail

# Source common functionality
source "$(dirname "$0")/common.sh"

# Build everything
echo "------------------------- Building all packages ---------------------"
pnpm nx run-many -t build --projects=mud-contracts/common,mud-contracts/core,mud-contracts/smart-object-framework,mud-contracts/world,end-to-end-tests --parallel=false
wait
echo "==================== Packages successfully built ===================="

# Deploy the standard contracts
echo "------------------------- Deploying forwarder contract ---------------------"
pnpm nx run @eveworld/standard-contracts:deploy
wait

export FORWARDER_ADDRESS=$(cat ./standard-contracts/broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq '.transactions|first|.contractAddress' | tr -d \") 

echo "==================== Forwarder contract deployed ===================="
echo "Forwarder Address: $FORWARDER_ADDRESS"

echo "------------------------- Deploying world core ---------------------"
pnpm nx deploy @eveworld/world-core
wait
export WORLD_ADDRESS=$(cat ./mud-contracts/core/deploys/$chain_id/latest.json | jq '.worldAddress' | tr -d \")

echo "==================== World Core deployed ===================="
echo "World Address: $WORLD_ADDRESS"

echo "------------------------- Configuring trusted forwarder ---------------------"
pnpm nx setForwarder @eveworld/world-core
echo "==================== Trusted forwarder configured ===================="

echo "---------------------- Deploying smart object framework ---------------------"
pnpm nx deploy @eveworld/smart-object-framework --worldAddress '${WORLD_ADDRESS}'
wait
echo "==================== Smart object framework deployed ===================="

echo "==================== Deploying world modules ===================="
pnpm nx deploy @eveworld/world --worldAddress '${WORLD_ADDRESS}'

echo "==================== Delegate access to Forwarder Contract ===================="
pnpm nx delegateNamespaceAccess @eveworld/world-core

echo "World address: $WORLD_ADDRESS"
echo "Trusted forwarder address: $FORWARDER_ADDRESS" 
