const hre = require("hardhat");
const { admin, usdcToken } = require("./config");

async function main() {
  if (process.env.DEPLOY_ALL==="true" || process.env.DEPLOY_TOKEN === "true") {
    await deployBrainstemsTokenContract();
  }

  if (process.env.DEPLOY_ALL==="true" || process.env.DEPLOY_MEMBERSHIP === "true") {
    await deployMembershipContract();
  }
 
  if (process.env.DEPLOY_ALL==="true" || process.env.DEPLOY_ASSETS === "true") {
    await deployAssetsContract();
  }
/*
  if (process.env.DEPLOY_ALL==="true" || process.env.DEPLOY_BRAINSTEM === "true") {
    await deployBrainstemContract();
  }

  if (process.env.DEPLOY_ALL==="true" || process.env.DEPLOY_EXECUTION === "true") {
    await deployExecutionContract();
  }

  if (process.env.DEPLOY_ALL==="true" || process.env.DEPLOY_VALIDATION === "true") {
    await deployValidationContract();
    
  }
  if (process.env.DEPLOY_ALL==="true" || process.env.DEPLOY_ACCESS === "true") {
    await deployAccessContract();
  }
*/
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

async function deployValidationContract() {
  console.log("deploying Validation Contract....");

  const Validation = await hre.ethers.getContractFactory(
    "Validation"
  );
  const validation = await upgrades.deployProxy(Validation, [
    // Constructor args.
  ]);
  await validation.waitForDeployment();

  console.log("deployed to :", await validation.getAddress());
}

async function deployMembershipContract() {
  console.log("deploying Membership Contract....");

  const Membership = await hre.ethers.getContractFactory(
    "Membership"
  );
  const membership = await upgrades.deployProxy(Membership, [admin
    // Constructor args.
  ]);
  await membership.waitForDeployment();

  console.log("deployed to :", await membership.getAddress());
}

async function deployExecutionContract() {
  console.log("deploying Execution Contract....");

  const Execution = await hre.ethers.getContractFactory(
    "Execution"
  );
  const execution = await upgrades.deployProxy(Execution, [
    // Constructor args.
  ]);
  await execution.waitForDeployment();

  console.log("deployed to :", await execution.getAddress());
}

async function deployBrainstemContract() {
  console.log("deploying Brainstem Contract....");

  const Brainstem = await hre.ethers.getContractFactory(
    "Brainstem"
  );
  const brainstem = await upgrades.deployProxy(Brainstem, [
    // Constructor args.
  ]);
  await brainstem.waitForDeployment();

  console.log("deployed to :", await brainstem.getAddress());
}

async function deployAssetsContract() {
  console.log("deploying Assets Contract....");

  const Assets = await hre.ethers.getContractFactory(
    "Assets"
  );
  const assets = await upgrades.deployProxy(Assets, [
    admin,
    usdcToken
  ]);
  await assets.waitForDeployment();

  console.log("deployed to :", await assets.getAddress());
}

async function deployAccessContract() {
  console.log("deploying Access Contract....");

  const Access = await hre.ethers.getContractFactory(
    "Access"
  );
  const access = await upgrades.deployProxy(Access, [
    // Constructor args.
  ]);
  await access.waitForDeployment();

  console.log("deployed to :", await access.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});