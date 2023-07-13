// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { green } = require("console-log-colors");

async function main() {
  console.log(
    "-------------------------- [ Deploy IntellTokenContract.sol ] ----------------------------"
  );
  const IntelligenceInvestmentToken = await hre.ethers.getContractFactory(
    "IntelligenceInvestmentToken"
  );
  const intelligenceInvestmentToken =
    await IntelligenceInvestmentToken.deploy();

  await intelligenceInvestmentToken.deployed();
  console.log(green(`Deployed to ${intelligenceInvestmentToken.address}`));

  try {
    await hre.run("verify:verify", {
      address: intelligenceInvestmentToken.address,
      // constructorArguments: [NAME, SYMBOL],
    });
  } catch (error) {}

  console.log(
    "-------------------------- [ Deploy IntellSetting.sol ] ----------------------------"
  );

  const IntellSetting = await hre.ethers.getContractFactory("IntellSetting");
  const intellSetting = await IntellSetting.deploy();

  await intellSetting.deployed();

  console.log(green(`Deployed to ${intellSetting.address}`));
  try {
    await hre.run("verify:verify", {
      address: intellSetting.address,
      // constructorArguments: [NAME, SYMBOL],
    });
  } catch (error) {}

  console.log(
    "-------------------------- [ Deploy IntellModelNFTContract.sol ] ----------------------------"
  );

  const IntellModelNFTContract = await hre.ethers.getContractFactory(
    "IntellModelNFTContract"
  );
  const intellModelNFTContract = await IntellModelNFTContract.deploy("ipfs://intelligence-exchange-metadata/", intellSetting.address);

  await intellModelNFTContract.deployed();

  console.log(green(`Deployed to ${intellModelNFTContract.address}`));
  try {
    await hre.run("verify:verify", {
      address: intellModelNFTContract.address,
      constructorArguments: ["ipfs://intelligence-exchange-metadata/", intellSetting.address],
    });
  } catch (error) {}



  console.log(
    "-------------------------- [ Deploy IntellShareCollectionContract.sol ] ----------------------------"
  );

  const IntellShareCollectionContract = await hre.ethers.getContractFactory(
    "IntellShareCollectionContract"
  );
  const intellShareCollectionContract = await IntellShareCollectionContract.deploy(intellSetting.address);

  await intellShareCollectionContract.deployed();

  console.log(green(`Deployed to ${intellShareCollectionContract.address}`));
  try {
    await hre.run("verify:verify", {
      address: intellShareCollectionContract.address,
      constructorArguments: [intellSetting.address],
    });
  } catch (error) {}
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
