#!/bin/bash
set -eou pipefail

# Source common functionality
source "$(dirname "$0")/common.sh"

# Build everything
echo "------------------------- Building all packages ---------------------"
pnpm nx run-many -t build --projects=standard-contracts-v2,mud-contracts/common,mud-contracts/core-v2,mud-contracts/smart-object-framework-v2,mud-contracts/world-v2,end-to-end-tests-v2 --parallel=false
wait
echo "==================== Packages successfully built ===================="

# Deploy the standard contracts
echo "------------------------- Deploying forwarder contract ---------------------"
pnpm nx run @eveworld/standard-contracts-v2:deploy
wait

export FORWARDER_ADDRESS=$(cat ./standard-contracts-v2/broadcast/Deploy.s.sol/$chain_id/run-latest.json | jq '.transactions|first|.contractAddress' | tr -d \") 

echo "==================== Forwarder contract deployed ===================="
echo "Forwarder Address: $FORWARDER_ADDRESS"

echo "------------------------- Deploying world core ---------------------"
pnpm nx deploy @eveworld/world-core-v2
wait
export WORLD_ADDRESS=$(cat ./mud-contracts/core-v2/deploys/$chain_id/latest.json | jq '.worldAddress' | tr -d \")

echo "==================== World Core deployed ===================="
echo "World Address: $WORLD_ADDRESS"

echo "------------------------- Configuring trusted forwarder ---------------------"
pnpm nx setForwarder @eveworld/world-core-v2
wait
echo "==================== Trusted forwarder configured ===================="

echo "---------------------- Deploying smart object framework ---------------------"
pnpm nx deploy @eveworld/smart-object-framework-v2 --worldAddress '${WORLD_ADDRESS}'
wait
echo "==================== Smart object framework deployed ===================="

echo "==================== Configuring Smart Object Framework ===================="
pnpm nx configure-access @eveworld/smart-object-framework-v2
wait
echo "==================== Smart object framework configured ===================="

echo "==================== Deploying world modules ===================="
pnpm nx deploy @eveworld/world-v2 --worldAddress '${WORLD_ADDRESS}'
wait
echo "==================== World modules deployed ===================="

echo "==================== Configuring world modules ===================="
pnpm nx config @eveworld/world-v2
wait
echo "==================== World modules configured ===================="

echo "==================== Delegate access to Forwarder Contract ===================="
pnpm nx delegateNamespaceAccess @eveworld/world-core-v2
wait
echo "==================== Deploy Successfull ===================="

echo "World address: $WORLD_ADDRESS"
echo "Trusted forwarder address: $FORWARDER_ADDRESS" 
