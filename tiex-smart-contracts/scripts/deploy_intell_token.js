const hre = require("hardhat");
const { admin, usdcToken, tokenToUsdc } = require("./config");

async function main() {
  console.log("deploying Intell Token Contract....");

  const IntelligenceToken = await hre.ethers.getContractFactory(
    "IntelligenceToken"
  );
  const intelligenceToken = await upgrades.deployProxy(IntelligenceToken, [
    admin,
    usdcToken,
    tokenToUsdc,
  ]);
  await intelligenceToken.deployed();

  console.log(`deployed to ${intelligenceToken.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
