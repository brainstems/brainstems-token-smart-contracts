const hre = require("hardhat");
const { green } = require("console-log-colors");
const { admin, usdcToken, tokenToUsdc } = require("./deploy_config");

async function main() {
  console.log(green("Deploying Intell Token Contract...."));

  const IntelligenceToken = await hre.ethers.getContractFactory(
    "IntelligenceToken"
  );
  const intelligenceToken = await upgrades.deployProxy(IntelligenceToken, [
    admin,
    usdcToken,
    tokenToUsdc
  ]);
  await intelligenceToken.deployed();

  console.log(green(`Deployed to ${intelligenceToken.address}`));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
