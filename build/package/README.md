# World deployer image

This image contains the packaged source code required to build, test and deploy the world as a whole.

## Building the image

To build the image locally you can run:

```bash
docker buildx build --platform <YOUR_PLATFORM_ARCHITECTURE> -t world-deployer --progress=plain . -f ./build/package/world.dockerfile --load
```

Remember to switch out `<YOUR_PLATFORM_ARCHITECTURE>` out for your machine's architecture. For Apple Silicon machines this will be `linux/arm64`.

## Installation and Usage

The image supports four main operations:

### V1 Deployment

```bash
docker run --env-file .env --name world-deployer -it world-deployer deploy-v1 \
  --rpc-url http://host.docker.internal:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### V2 Deployment

```bash
docker run --env-file .env --name world-deployer -it world-deployer deploy-v2 \
  --rpc-url http://host.docker.internal:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Upgrading Existing V1 World

```bash
docker run --env-file .env --name world-upgrader -it world-deployer upgrade-v1 \
  --rpc-url http://host.docker.internal:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --world-address 0x... # Your existing v1 world address
```

### Upgrading Existing V2 World

```bash
docker run --env-file .env --name world-upgrader -it world-deployer upgrade-v2 \
  --rpc-url http://host.docker.internal:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --world-address 0x... # Your existing v2 world address
```

Make sure to have a running EVM node available and pass the appropriate url as a parameter. If you are running the node locally on a Mac or Windows you will need to reference it with the `host.docker.internal` host. On Linux machines you can use `--net=host` as a parameter instead.

## Extracting ABIs

To extract ABIs from the container, you can run:

```bash
docker cp world-deployer:/monorepo/abis .
```

This copies the `abis/` directory containing the ABIs from the deployment into your current directory. The v2 ABIs will be prefixed with `v2-` to distinguish them from v1 ABIs.
