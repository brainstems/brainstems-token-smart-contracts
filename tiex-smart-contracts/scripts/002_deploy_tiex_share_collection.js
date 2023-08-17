// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { green } = require("console-log-colors");

async function main() {
  console.log(green("******** Deploying TIExShareCollections.sol*********"));

  const truthHolder = "0xF8AbE936Ff2bCc9774Db7912554c4f38368e05A2";
  const paymentToken = "0x762030A3bf845513F67583b2B8A4e4bAF2364262"
  const admin = "0x2da2D276FEfe4E9675dD0416Cc0D97Ab6896a3c2";

  const TIExShareCollections = await hre.ethers.getContractFactory("TIExShareCollections");
  const _TIExShareCollections = await hre.upgrades.deployProxy(TIExShareCollections, [truthHolder, paymentToken, admin], {
      initializer: "initialize",
  });
  await _TIExShareCollections.deployed();
  console.log("Calculator deployed to:", _TIExShareCollections.address);

  try {
    await hre.run("verify:verify", {
      address: _TIExShareCollections.address,
    });
  } catch (error) {
    console.log(error);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
