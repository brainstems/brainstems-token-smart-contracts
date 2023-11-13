// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { green } = require("console-log-colors");
const { recipient } = require("./deploy_config");

async function main() {
  console.log(green("Deploying IntellTokenContract...."));

  const IntelligenceInvestmentToken = await hre.ethers.getContractFactory(
    "IntelligenceToken"
  );
  const intelligenceInvestmentToken = await IntelligenceInvestmentToken.deploy(
    recipient
  );

  await intelligenceInvestmentToken.deployed();
  console.log(green(`Deployed to ${intelligenceInvestmentToken.address}`));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
