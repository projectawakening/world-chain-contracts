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

# Install Foundry pinned to a version
RUN curl -L https://foundry.paradigm.xyz | bash && \
  /root/.foundry/bin/foundryup --version 1.2.3 && \
  /root/.foundry/bin/foundryup && \
  ln -s /root/.foundry/bin/forge /usr/local/bin/forge && \
  ln -s /root/.foundry/bin/cast /usr/local/bin/cast && \
  ln -s /root/.foundry/bin/anvil /usr/local/bin/anvil

# Add Foundry to PATH
ENV PATH="$PATH:/root/.foundry/bin"

RUN /root/.foundry/bin/forge --version

# Set up working directory
WORKDIR /monorepo
COPY . .

RUN rm -rf node_modules

# Install module dependencies
RUN CI=1 pnpm install --frozen-lockfile

# Building only v2 modules
ENV SKIP_LINT=1
RUN pnpm nx run-many -t build --projects=core-v2,smart-object-framework-v2,world-v2,standard-contracts-v2,end-to-end-tests-v2

# Make entrypoint script executable
RUN chmod +x ./build/package/entrypoint.sh

ENTRYPOINT ["./build/package/entrypoint.sh"]
