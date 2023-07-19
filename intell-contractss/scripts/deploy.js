// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { green } = require("console-log-colors");
const { parseUnits } = require("../test/helper");

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
  const intellModelNFTContract = await IntellModelNFTContract.deploy(
    "ipfs://intelligence-exchange-metadata/",
    intellSetting.address
  );

  await intellModelNFTContract.deployed();

  console.log(green(`Deployed to ${intellModelNFTContract.address}`));
  try {
    await hre.run("verify:verify", {
      address: intellModelNFTContract.address,
      constructorArguments: [
        "ipfs://intelligence-exchange-metadata/",
        intellSetting.address,
      ],
    });
  } catch (error) {}

  console.log(
    "-------------------------- [ Deploy IntellShareCollectionContract.sol ] ----------------------------"
  );

  const IntellShareCollectionContract = await hre.ethers.getContractFactory(
    "IntellShareCollectionContract"
  );
  const intellShareCollectionContract =
    await IntellShareCollectionContract.deploy(intellSetting.address);

  await intellShareCollectionContract.deployed();

  console.log(green(`Deployed to ${intellShareCollectionContract.address}`));
  try {
    await hre.run("verify:verify", {
      address: intellShareCollectionContract.address,
      constructorArguments: [intellSetting.address],
    });
  } catch (error) {}


  // Sets addresses of contracts and some parameters deployed in intellSetting

  const modelRegisterationPrice = 10000;
  const intellShareCollectionLaunchPrice = 20000;

  await intellSetting.setIntellTokenAddr(intelligenceInvestmentToken.address);
  await intellSetting.setIntellModelNFTContractAddr(
    intellModelNFTContract.address
  );
  await intellSetting.setIntellShareCollectionContractAddr(
    intellShareCollectionContract.address
  );
  await intellSetting.setTruthHolder("0xF8AbE936Ff2bCc9774Db7912554c4f38368e05A2");
  await intellSetting.setAdmin("0x171c8C090511bc95886c9AAc505dB3081FE72F97");
  await intellSetting.setModelRegisterationPrice(
    parseUnits(modelRegisterationPrice)
  );
  await intellSetting.setIntellShareCollectionLaunchPrice(
    parseUnits(intellShareCollectionLaunchPrice)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
