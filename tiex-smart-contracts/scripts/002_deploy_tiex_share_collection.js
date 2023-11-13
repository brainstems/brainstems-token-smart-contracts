// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { green } = require("console-log-colors");
const {
  truthHolder,
  paymentToken,
  admin,
  creator_rate,
  marketing_rate,
  reserve_rate,
  presale_rate,
  marketing_address,
  reserve_address,
  presale_address,
} = require("./deploy_config");

// TODO: update test variable names
async function main() {
  console.log(green("Deploying TIExShareCollections ...."));

  const TIExShareCollections = await hre.ethers.getContractFactory(
    "AssetsRevenu"
  );
  const _TIExShareCollections = await hre.upgrades.deployProxy(
    TIExShareCollections,
    [
      truthHolder,
      paymentToken,
      admin,
      [
        creator_rate,
        marketing_rate,
        reserve_rate,
        presale_rate,
        marketing_address,
        reserve_address,
        presale_address,
      ],
    ],
    {
      initializer: "initialize",
    }
  );

  await _TIExShareCollections.deployed();

  console.log(
    "TIExShareCollections deployed to:",
    _TIExShareCollections.address
  );

  // try {
  //   await hre.run("verify:verify", {
  //     address: _TIExShareCollections.address,
  //   });
  // } catch (error) {
  //   console.log(error);
  // }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
