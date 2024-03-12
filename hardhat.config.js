require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-contract-sizer");

require("dotenv").config();

const MAINNET_PRIVATE_KEY = process.env.MAINNET_PRIVATE_KEY;
const TESTNET_PRIVATE_KEY = process.env.TESTNET_PRIVATE_KEY;

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1337,
    },
    fuji: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      gasPrice: 225000000000,
      chainId: 43113,
      accounts: [TESTNET_PRIVATE_KEY],
    },
    mainnet: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      gasPrice: 225000000000,
      chainId: 43114,
      accounts: [MAINNET_PRIVATE_KEY],
    },
    arbitrumGoerli: {
      url: "https://goerli-rollup.arbitrum.io/rpc",
      chainId: 421613,
      accounts: [TESTNET_PRIVATE_KEY]
    },
    goerli: {
      url: "https://goerli.infura.io/v3/4ed535ceb6054775bf2f8a6cf137bbf2",
      chainId: 5,
      accounts: [TESTNET_PRIVATE_KEY]
    }

  },
  solidity: {
    compilers: [
      {
        version: "0.8.21",
        settings: {
          evmVersion: "paris",
          optimizer: {
            enabled: true,
            runs: 1,
          },
          "viaIR": true,
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 40000,
  },
};
