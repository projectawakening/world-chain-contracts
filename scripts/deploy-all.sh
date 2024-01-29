#!/bin/bash

# Fresh install
pnpm install


# Build every core contract
CORE_SCOPE=$(npx lerna list --all --parseable --long | grep core | cut -d ':' -f 2 | sed 's/^/--scope=/' | xargs)
npx lerna run build $CORE_SCOPE
wait

echo "-------------------------------------- Deploying base world ---------------------------------------------"
WORLD_OUTPUT=$(npx lerna run deploy:local --scope=@frontier/base-world | grep -C 2 "worldAddress");
trimmed=$(echo $WORLD_OUTPUT | tr -d ' ')
json_text=$(echo "$trimmed" | sed -E 's/([a-zA-Z0-9_]+):/"\1":/g; s/([0-9]+):/"\1":/g' | tr "'" '"')

# Remove asci decorators from string because we are fishing this out of a node console output
sanitized_string=$(echo "$json_text" | sed -E 's/\x1B\[[0-9;]*[JKmsu]//g')
WORLD_ADDRESS=$(echo $sanitized_string | jq .worldAddress)
echo $WORLD_ADDRESS



CORE_FOUNDATION_SCOPE=$(npx lerna list --all --parseable --long | grep foundation | cut -d ':' -f 2 | sed 's/^/--scope=/' | xargs)

echo "----------------------------- Building foundation modules $WORLD_ADDRRESS ----------------------------"
npx lerna run build $CORE_FOUNDATION_SCOPE
wait

echo "------------------------- Deploying foundation modules into world $WORLD_ADDRRESS ---------------------"
npx lerna run --stream --concurrency 1 deploy:local $CORE_FOUNDATION_SCOPE -- --worldAddress $WORLD_ADDRESS