FROM --platform=linux/amd64 debian:bookworm-slim

ARG IMAGE_TAG
ENV IMAGE_TAG=${IMAGE_TAG}

# Install basic dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    jq \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x
RUN curl -fsSL https://nodejs.org/dist/v18.16.0/node-v18.16.0-linux-x64.tar.gz | \
    tar -xz -C /usr/local --strip-components=1

# Install pnpm
RUN npm install -g pnpm@8.9.2

# Install Foundry
RUN curl -L https://foundry.paradigm.xyz | bash && \
    export PATH="$PATH:$HOME/.foundry/bin" && \
    echo 'export PATH="$PATH:$HOME/.foundry/bin"' >> $HOME/.bashrc && \
    $HOME/.foundry/bin/foundryup

# Add Foundry to PATH
ENV PATH="$PATH:/root/.foundry/bin"

# Set up working directory
WORKDIR /monorepo
COPY . .

RUN rm -rf node_modules

# Install module dependencies
RUN CI=1 pnpm install --frozen-lockfile

# Building all other modules
RUN pnpm nx run-many -t build

# Make entrypoint script executable
RUN chmod +x ./build/package/entrypoint.sh

ENTRYPOINT ["./build/package/entrypoint.sh"]
