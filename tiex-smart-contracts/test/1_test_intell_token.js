const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseUnits, DECIMALS } = require("./helper");
const { usdcToken } = require("../scripts/deploy_config");

describe("IntelligenceInvestmentToken", function () {
  async function deployIntelligenceExchangeProtocolFixture() {
    const TOTAL_SUPPLY = 1_000_000_000;
    const TOKEN_NAME = "Intelligence Token";
    const TOKEN_SYMBOL = "INTELL";

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const IntelligenceInvestmentToken = await ethers.getContractFactory(
      "IntelligenceToken"
    );
    const intelligenceInvestmentToken =
      await IntelligenceInvestmentToken.deploy();

    await intelligenceInvestmentToken.initialize(owner.address, usdcToken, 1);

    return {
      owner,
      otherAccount,
      intelligenceInvestmentToken,
      DECIMALS,
      TOTAL_SUPPLY,
      TOKEN_NAME,
      TOKEN_SYMBOL,
    };
  }

  describe("Deployment", function () {
    it("Should set the right Name of INTELL token", async function () {
      const { intelligenceInvestmentToken, TOKEN_NAME } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intelligenceInvestmentToken.name()).to.equal(TOKEN_NAME);
    });

    it("Should set the right Symbol of INTELL token", async function () {
      const { intelligenceInvestmentToken, TOKEN_SYMBOL } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intelligenceInvestmentToken.symbol()).to.equal(TOKEN_SYMBOL);
    });

    it("Should set the right decimals", async function () {
      const { intelligenceInvestmentToken, DECIMALS } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );

      expect(await intelligenceInvestmentToken.decimals()).to.equal(DECIMALS);
    });

    it("Should set the right total supply", async function () {
      const { intelligenceInvestmentToken, TOTAL_SUPPLY } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );

      expect(await intelligenceInvestmentToken.MAX_SUPPLY()).to.equal(
        parseUnits(TOTAL_SUPPLY)
      );
    });
  });
});
