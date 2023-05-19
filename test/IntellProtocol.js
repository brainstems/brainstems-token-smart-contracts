// const {
//   time,
//   loadFixture,
// } = require("@nomicfoundation/hardhat-network-helpers");
// const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
// const { expect } = require("chai");
// const { ethers } = require("hardhat");
// const { BigNumber } = require("ethers");

// describe("IntellProtocol", function () {
//   // We define a fixture to reuse the same setup in every test.
//   // We use loadFixture to run this setup once, snapshot that state,
//   // and reset Hardhat Network to that snapshot in every test.
//   async function deployIntelligenceExchangeProtocolFixture() {
//     const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
//     const ONE_GWEI = 1_000_000_000;
//     const TOTAL_SUPPLY = 1_000_000_000;
//     const DECIAMLS = 18;
//     const TOKEN_NAME = "Intelligence Investment Token";
//     const TOKEN_SYMBOL = "INTELL";

//     const lockedAmount = ONE_GWEI;
//     const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

//     // Contracts are deployed using the first signer/account by default
//     const [owner, otherAccount] = await ethers.getSigners();

//     const IntelligenceInvestmentToken = await ethers.getContractFactory("IntelligenceInvestmentToken");
//     const IntellSetting = await ethers.getContractFactory("IntellSetting");
//     const IntellModelNFTContract = await ethers.getContractFactory("IntellModelNFTContract");
//     const IntellFactoryContract = await ethers.getContractFactory("IntellFactoryContract");



//     const intelligenceInvestmentToken = await IntelligenceInvestmentToken.deploy();
//     const intellSetting = await IntellSetting.deploy();
//     const intellModelNFTContract = await IntellModelNFTContract.deploy("the intelligence exchange", intellSetting.address);
//     const intellFactoryContract = await IntellFactoryContract.deploy(intellSetting.address, intelligenceInvestmentToken.address);

//     await intellSetting.setIntellTokenAddr(intelligenceInvestmentToken.address);
//     await intellSetting.setIntellModelNFTContractAddr(intellModelNFTContract.address);
//     await intellSetting.setFactoryContractAddr(intellFactoryContract.address);



//     return { owner, otherAccount, intelligenceInvestmentToken, intellSetting, intellModelNFTContract, intellFactoryContract, TOTAL_SUPPLY, DECIAMLS, TOKEN_NAME, TOKEN_SYMBOL };
//   }

//   describe("Deployment", function () {
//     describe("INTELL Token Deployment", function () {
//       it("Should set the right owner of INTELL token", async function () {
//         const { intelligenceInvestmentToken, owner } = await loadFixture(deployIntelligenceExchangeProtocolFixture);
//         expect(await intelligenceInvestmentToken.owner()).to.equal(owner.address);
//       });

//       it("Should set the right total supply", async function() {
//         const { intelligenceInvestmentToken, TOTAL_SUPPLY, DECIAMLS } = await loadFixture(deployIntelligenceExchangeProtocolFixture);
//         const _totalsuppl = TOTAL_SUPPLY * 10 ** DECIAMLS;

//         console.log(BigNumber.from(await intelligenceInvestmentToken.totalSupply()).toHexString());
//         console.log(parseInt(1000, 16))

//         // expect(BigNumber.from(await intelligenceInvestmentToken.totalSupply()).toHexString()).to.equal(parseInt(TOTAL_SUPPLY * 10 ** DECIAMLS, 16))
//       })
//     })

//   });
// });
