const hre = require("hardhat");
const { admin, usdcToken, tokenToUsdc } = require("./config");

async function main() {
  console.log("deploying Brainstems Token Contract....");

  const BrainstemsToken = await hre.ethers.getContractFactory(
    "BrainstemsToken"
  );
  const brainstemsToken = await upgrades.deployProxy(BrainstemsToken, [
    admin,
    usdcToken,
    tokenToUsdc,
  ]);
  await brainstemsToken.deployed();

  console.log(`deployed to ${brainstemsToken.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
