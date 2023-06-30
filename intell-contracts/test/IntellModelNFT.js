const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseUnits, DECIMALS } = require("./helper");

describe("IntelligenceInvestmentToken", async function () {
  async function deployIntelligenceExchangeProtocolFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, truthHolder, signer0, signer1] = await ethers.getSigners();

    // Deploys intell token, intellSetting, intellModelNFT, intellShareCollection contracts
    const intelligenceInvestmentToken = await ethers.deployContract(
      "IntelligenceInvestmentToken"
    );
    const intellSetting = await ethers.deployContract("IntellSetting");
    const intellModelNFTContract = await ethers.deployContract(
      "IntellModelNFTContract",
      ["ipfs://intelligence-exchange-metadata/", intellSetting.address]
    );
    const intellShareCollection = await ethers.deployContract(
      "IntellShareCollectionContract",
      ["Intelligence Share Collections", "ISC", intellSetting.address]
    );

    // Sets addresses of contracts deployed in intellSetting
    await intellSetting.setIntellTokenAddr(intelligenceInvestmentToken.address);
    await intellSetting.setIntellModelNFTContractAddr(
      intellModelNFTContract.address
    );
    await intellSetting.setIntellShareCollectionContractAddr(
      intellShareCollection.address
    );
    await intellSetting.setTruthHolder(truthHolder.address);
    await intellSetting.setAdmin(owner.address);

    return {
      owner,
      truthHolder,
      signer0,
      signer1,
      intelligenceInvestmentToken,
      intellSetting,
      intellModelNFTContract,
      intellShareCollection,
    };
  }

  describe("Deployment", function () {
    it("Should set the address of INTELL token in intellSetting contract", async function () {
      const { intelligenceInvestmentToken, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.intellTokenAddr()).to.equal(
        intelligenceInvestmentToken.address
      );
    });

    it("Should set the address of IntellModelNFT contract in intellSetting contract", async function () {
      const { intellModelNFTContract, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.intellModelNFTContractAddr()).to.equal(
        intellModelNFTContract.address
      );
    });

    it("Should set the address of IntellShareCollection contract in intellSetting contract", async function () {
      const { intellShareCollection, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.intellShareCollectionContractAddr()).to.equal(
        intellShareCollection.address
      );
    });

    it("Should set the address of truth holder in intellSetting contract", async function () {
      const { truthHolder, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.truthHolder()).to.equal(
        truthHolder.address
      );
    });

    it("Should set the admin address in intellSetting contract", async function () {
      const { owner, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.admin()).to.equal(
        owner.address
      );
    });

    

    

  });
});
