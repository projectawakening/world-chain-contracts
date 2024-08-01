# Use the latest foundry image as of April 11th 2024
FROM --platform=linux/amd64 ghcr.io/foundry-rs/foundry@sha256:8b843eb65cc7b155303b316f65d27173c862b37719dc095ef3a2ef27ce8d3c00


ARG IMAGE_TAG
ENV IMAGE_TAG=${IMAGE_TAG}

# Install node and pnpm
RUN cat /etc/apk/repositories
RUN apk add  --update nodejs-current=18.9.1-r0 npm jq curl

RUN npm install -g pnpm@8.9.2

# Set up working directory
WORKDIR /monorepo
COPY . . 

RUN rm -rf node_modules

# Install module dependencies
RUN CI=1 pnpm install --frozen-lockfile

# Building all modules
RUN pnpm nx run-many -t build


ENTRYPOINT ["./build/package/deploy-in-docker.sh"]
