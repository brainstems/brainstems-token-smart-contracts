// const {
//     time,
//     loadFixture,
// } = require("@nomicfoundation/hardhat-network-helpers");
// const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
// const { expect } = require("chai");
// const { ethers } = require("hardhat");
// const { BigNumber } = require("ethers");

// describe("DoodlesDrops", function () {
//     // We define a fixture to reuse the same setup in every test.
//     // We use loadFixture to run this setup once, snapshot that state,
//     // and reset Hardhat Network to that snapshot in every test.
//     async function deployIntelligenceExchangeProtocolFixture() {

//         // Contracts are deployed using the first signer/account by default
//         const [owner, otherAccount] = await ethers.getSigners();

//         const DoodlesDrops = await ethers.getContractFactory("DoodlesDrops");

//         const doodlesDrops = await DoodlesDrops.deploy();

//         return { owner, otherAccount, doodlesDrops };
//     }

//     describe("Deployment", function () {
//         it("Should set the right owner of INTELL token", async function () {
//             const { doodlesDrops, owner } = await loadFixture(deployIntelligenceExchangeProtocolFixture);
            
//         });

//         it("Should set the right total supply", async function () {
//             const { intelligenceInvestmentToken, TOTAL_SUPPLY, DECIAMLS } = await loadFixture(deployIntelligenceExchangeProtocolFixture);
//             const _totalsuppl = TOTAL_SUPPLY * 10 ** DECIAMLS;

//             console.log(BigNumber.from(await intelligenceInvestmentToken.totalSupply()).toHexString());
//             console.log(parseInt(1000, 16))

//             // expect(BigNumber.from(await intelligenceInvestmentToken.totalSupply()).toHexString()).to.equal(parseInt(TOTAL_SUPPLY * 10 ** DECIAMLS, 16))
//         })

//     });
// });
