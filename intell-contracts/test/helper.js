const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");
const { config } = require("hardhat");

const DECIMALS = 18;
const parseUnits = (__num) =>
  ethers.utils.parseUnits(__num.toString(), DECIMALS);

const hexToDecimal = (hex) => parseInt(hex, 16);

const bigNumberToDecimal = (bigNumber) => hexToDecimal(bigNumber._hex, 16);

const getHardhatPrivateKey = (index) => {
  const accounts = config.networks.hardhat.accounts;
  const wallet = ethers.Wallet.fromMnemonic(
    accounts.mnemonic,
    accounts.path + `/${index}`
  );

  return wallet.privateKey;
};

module.exports = {
  parseUnits,
  DECIMALS,
  hexToDecimal,
  bigNumberToDecimal,
  getHardhatPrivateKey
};
