#!/bin/bash

# Fresh install
pnpm install


# Build every core contract
CORE_SCOPE=$(npx lerna list --all --parseable --long | grep core | cut -d ':' -f 2 | sed 's/^/--scope=/' | xargs)
npx lerna run build $CORE_SCOPE
wait

#TODO find a way to split node logs and deploy output logs
# Run local node
./scripts/run-local-anvil-chain.sh


    

