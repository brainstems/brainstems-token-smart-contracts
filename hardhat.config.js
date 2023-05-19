// require("@nomicfoundation/hardhat-verify");
require("@nomicfoundation/hardhat-toolbox");
// require('@openzeppelin/hardhat-upgrades');

const ARBITRUM_KEY = "KNQKKXEIU1F9K7A15BAF8JBWKCRZ9SRTCM";
const GOERLI_TESTNET_PRIVATE_KEY =
  "27614733a96ebe9f80cf1b2d487b991c2fede6aead5090ceedfa6f5a9d703b3a";

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1337,
    },
    arbitrumGoerli: {
      url: "https://goerli-rollup.arbitrum.io/rpc",
      chainId: 421613,
      accounts: [GOERLI_TESTNET_PRIVATE_KEY],
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.18",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
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
  etherscan: {
    apiKey: ARBITRUM_KEY,
  },
};
