# Brainstems ERC 20 Token

- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Usage](#usage)
- [Deployment to a testnet or mainnet](#deployment-to-a-testnet-or-mainnet)


# Getting Started

## Requirements

- [Nodejs (v19.6.1)](https://nodejs.org/dist/v19.6.1/node-v19.6.1-x64.msi)
  - You'll know you've installed nodejs right if you can run:
    - `node --version` and get an ouput like `v19.6.1`
## Quickstart

```
git https://github.com/brainstems/brainstems-token-smart-contracts.git
npm install
```

Add a `.env` file in the root of the project, and as stated in the `.env.example` add:
```sh
TESTNET_PRIVATE_KEY=000000000000000000000000000000000000000000000000000000000000003c
MAINNET_PRIVATE_KEY=000000000000000000000000000000000000000000000000000000000000003c
```


# Compile & Test

### Clean:
To clear the cache and delete the artifacts.
```sh
npm run clean
```


### Compile:

Compile the smart contracts with Hardhat:

```sh
npm run build
```

### Test

Run the tests:

```sh
npm run test
```

# Deployment to a testnet or mainnet

For localhost, you can start your own hardhat node by running:
```sh
npx hardhat node
```

<br>

For contracts deployment you can run the script:
```sh
npm run deploy-contracts -- [args]
```

<br>

With the following possible Arguments:

- `--network [network]` --> This can be 'localhost', 'fuji', etc.
- `-token` --> Deploys the Brainstems Token Contract.

<br>

Example command to run all contracts in localhost:
```sh
npx run deploy-contracts -- --network localhost -token
```
