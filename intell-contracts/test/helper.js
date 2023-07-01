const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

const DECIMALS = 18;
const parseUnits = (__num) => ethers.utils.parseUnits(__num.toString(), DECIMALS)


const hexToDecimal = hex => parseInt(hex, 16);

const bigNumberToDecimal = bigNumber => hexToDecimal(bigNumber._hex, 16);

module.exports = {
    parseUnits,
    DECIMALS,
    hexToDecimal,
    bigNumberToDecimal
}
