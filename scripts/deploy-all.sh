#!/bin/bash

# Fresh install
pnpm install

# Tooling

# Function to print formatted instructions
print_instruction() {
    echo -e "\n===================================================================================================="
    echo -e "|| $1"
    echo -e "===================================================================================================="
}


# Build the contracts
pnpm nx run-many -t build  --projects "standard-contracts/**"
wait

echo "------------------------- Deploying Forwarder Contract ---------------------"
FORWARDER_CONTRACT=$(pnpm run deploy @eve-frontier/forwarder | grep -C 2 "ForwarderAddress:");
trimmed=$(echo $FORWARDER_CONTRACT | tr -d ' ')
# pnpm nx run-many -t deploy --projects "standard-contracts/**"

# print_instruction "Deploying Mud Contracts"
# #echo "-------------------------------------- Deploying base world ---------------------------------------------"
# WORLD_OUTPUT=$(pnpm nx deploy:local @frontier/base-world | grep -C 2 "worldAddress");
# trimmed=$(echo $WORLD_OUTPUT | tr -d ' ')
# json_text=$(echo "$trimmed" | sed -E 's/([a-zA-Z0-9_]+):/"\1":/g; s/([0-9]+):/"\1":/g' | tr "'" '"')

# # Remove asci decorators from string because we are fishing this out of a node console output
# sanitized_string=$(echo "$json_text" | sed -E 's/\x1B\[[0-9;]*[JKmsu]//g')
# WORLD_ADDRESS=$(node -pe 'JSON.stringify(JSON.parse(process.argv[1]).worldAddress)' "$(echo $sanitized_string)")
# echo $WORLD_ADDRESS

# echo "------------------------- Deploying init components into world: $WORLD_ADDRRESS ---------------------"
# pnpm nx run-many -t deploy:local --projects "world/forwarder/**" -- --worldAddress $WORLD_ADDRESS

# echo "--------------------------------------- Building foundation modules ---------------------------------------"
# pnpm nx run-many -t build  --projects "core/**"
wait

