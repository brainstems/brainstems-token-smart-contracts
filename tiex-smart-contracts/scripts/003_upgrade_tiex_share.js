// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { green } = require("console-log-colors");

async function main() {
  const PROXY = "0xCC5eC6E9AA058e5684a2D7468d9F518886e55684";
  console.log(green("******** Deploying TIExShareCollections.sol*********"));

  const TIExShareCollections = await hre.ethers.getContractFactory("TIExShareCollections");
  console.log("Upgrading TIExShareCollections...");
  await hre.upgrades.upgradeProxy(PROXY, TIExShareCollections);
  console.log("TIExShareCollections upgraded");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
