# Frontier World deployer image

This image contains the packaged source code required to build, test and deploy the Frontier world as a whole.

## Building the image


## Installation 
Pull the image from our docker registry (URL TBD).

and run it with the command: 

```bash
 docker run --name frontier-world-deployer -it frontier-image  --rpc-url http://host.docker.internal:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

```

Make sure to have a running EVM node available and pass the appropriate url as a parameter. If you are running the node locally on a Mac or Windows you will need to reference it with the `host.docker.internal` host. On Linux machines you can use `--net=host` as a parameter instead.

To ABIs from this deployer image you can run: 

```bash
docker cp frontier-world-deployer:/monorepo/abis .
```
This copies the directory containing the ABIs from the deployment into your current directory.

