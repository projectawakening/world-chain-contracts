# Use the latest foundry image as of April 11th 2024
FROM ghcr.io/foundry-rs/foundry@sha256:8b843eb65cc7b155303b316f65d27173c862b37719dc095ef3a2ef27ce8d3c00          

# Install node and pnpm
RUN cat /etc/apk/repositories
RUN apk add  --update nodejs-current=18.9.1-r0 npm jq

RUN npm install -g pnpm

# Set up working directory
WORKDIR /monorepo
COPY . . 

RUN rm -rf node_modules
 
# Install module dependencies
RUN CI=1 pnpm install

# Building all modules
RUN pnpm nx run-many -t build


ENTRYPOINT ["./build/package/deploy-in-docker.sh"]
