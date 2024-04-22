# Frontier world end to end testing suite

This package contains scripts intended to perform end to end tests for the game chain contracts. 


# How to test
1. Make sure you have a blockchain node available pointing to a blockchain with the game chain contracts installed.
2. Make sure enviornment values are set for your target environment.
2.1. `.env.local` and `.env.devnet` are available in the root of this package.
3. Run your tests by invoking npm scripts.


The npm scripts follow a naming convention for a `<FUNCTIONALIT>:<ENVIRONMENT>` e.g. in order to create a smart character on local chain you can run: 

```bash
pnpm run createSmartCharacter:local

```


# Environment values
Environment values are used for external values that we are dependant on the target environment. 
Test paramameters should should not be defined as environment variables for reproduceability purposes.
## PRIVATE_KEY
The `PRIVATE_KEY` variable should be a 32 bytes/256 bits data represented as a 64 hexadecimal character string.

Note: The Externally owned account (EOA) for which this private key belongs to will become the owner of entities created by the test scripts.
## RPC_URL

A valid url for the RPC endpoint of the target environment.

## WORLD_ADDRESS

A hexadecimal string representing the EVM address of the Mud world smart contract entry point.

