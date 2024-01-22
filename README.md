# Game Chain Contracts

Disclaimer: This is very much a work in progess.

# Development

The development stack consists of:

- An anvil node for etherum local development
- Scripts deploying a mud world and all or selected modules for developments

We are running the anvil node explicitly ourselves for three reasons:

- Making the development environment as similar to live ones as possible
- Decoupling from MUD's opinionated dev tools
- Having a stand alone development node allows us to deploy modules in a deterministic an selective manner

To start developing against the world and all of the CCP modules run:

```
pnpm run dev
```

You can also run

```
./dev module1,module2  # comma separated list of modules to load into the base world
```
