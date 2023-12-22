const { expect } = require("chai");
const { ethers } = require("hardhat");
const { admin, usdcToken, tokenToUsdc } = require("../scripts/config");
const {
  INTELLTOKEN_NAME,
  INTELLTOKEN_SYMBOL,
  INTELLTOKEN_STAGES,
  INTELLTOKEN_EVENTS,
  INTELLTOKEN_MAX_SUPPLY,
  INTELLTOKEN_INVESTORS_CAP,
  INTELLTOKEN_SALES_CAP,
} = require("./consts");
const { verifyEvents } = require("./utils");

let owner, IntellToken;

describe("Deployment", function () {
  before(async () => {
    [owner] = await ethers.getSigners();

    IntellToken = await ethers.getContractFactory("IntelligenceToken");
  });

  describe("should fail to deploy with", function () {
    it("invalid token/USDC conversion", async function () {
      await expect(
        upgrades.deployProxy(IntellToken, [admin, usdcToken, 0n])
      ).to.be.revertedWith("invalid conversion");
    });

    it("invalid USDC token contract", async function () {
      await expect(
        upgrades.deployProxy(IntellToken, [
          admin,
          ethers.ZeroAddress,
          tokenToUsdc,
        ])
      ).to.be.revertedWith("invalid contract param");
    });
  });

  describe("should deploy successfully", function () {
    it("with valid parameters", async function () {
      const intellToken = await upgrades.deployProxy(IntellToken, [
        admin,
        usdcToken,
        tokenToUsdc,
      ]);
      const tx = await intellToken.waitForDeployment();
      const deploymentTx = tx.deploymentTransaction();

      const name = await intellToken.name();
      expect(name).to.eq(INTELLTOKEN_NAME);

      const symbol = await intellToken.symbol();
      expect(symbol).to.eq(INTELLTOKEN_SYMBOL);

      const adminRole = await intellToken.DEFAULT_ADMIN_ROLE();
      const adminHasAdminRole = await intellToken.hasRole(adminRole, admin);
      expect(adminHasAdminRole).to.be.true;

      const usdcTokenContract = await intellToken.usdcToken();
      expect(usdcTokenContract).to.eq(usdcToken);

      const tokenUsdcConversion = await intellToken.tokenToUsdc();
      expect(tokenUsdcConversion).to.eq(tokenToUsdc);

      const stage = await intellToken.currentStage();
      expect(stage).to.eq(INTELLTOKEN_STAGES.WHITELISTING);

      const maxSupply = await intellToken.MAX_SUPPLY();
      expect(maxSupply).to.eq(INTELLTOKEN_MAX_SUPPLY);

      const investorsCap = await intellToken.INVESTORS_CAP();
      expect(investorsCap).to.eq(INTELLTOKEN_INVESTORS_CAP);

      const salesCap = await intellToken.SALES_CAP();
      expect(salesCap).to.eq(INTELLTOKEN_SALES_CAP);

      await verifyEvents(
        deploymentTx,
        intellToken,
        INTELLTOKEN_EVENTS.PRICE_UPDATED,
        [{ tokenToUsdc: tokenToUsdc }]
      );

      await verifyEvents(
        deploymentTx,
        intellToken,
        INTELLTOKEN_EVENTS.ENTERED_STAGE,
        [{ stage: INTELLTOKEN_STAGES.WHITELISTING }]
      );
    });
  });
});
