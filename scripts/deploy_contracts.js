const hre = require("hardhat");
const { admin } = require("./config");

async function main() {
  if (process.env.DEPLOY_TOKEN === "true") {
    await deployBrainstemsTokenContract();
  }
}

async function deployBrainstemsTokenContract() {
  console.log("deploying Brainstems Token Contract....");

  const BrainstemsToken = await hre.ethers.getContractFactory(
    "BrainstemsToken"
  );
  const brainstemsToken = await upgrades.deployProxy(BrainstemsToken, [
    admin
  ]);
  await brainstemsToken.waitForDeployment();

  console.log("deployed to :", await brainstemsToken.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});