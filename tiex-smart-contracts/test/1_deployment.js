const { expect } = require("chai");
const { ethers } = require("hardhat");
const { admin, usdcToken, tokenToUsdc } = require("../scripts/config");
const {
  INTELLTOKEN_NAME,
  INTELLTOKEN_SYMBOL,
  INTELLTOKEN_STAGES,
  INTELLTOKEN_EVENTS,
} = require("./consts");
const { verifyEvents } = require("./utils");

let owner, user, IntellToken;

describe("Deployment", function () {
  before(async () => {
    [owner, user] = await ethers.getSigners();

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

      await verifyEvents(
        deploymentTx,
        intellToken,
        INTELLTOKEN_EVENTS.RATE_UPDATED,
        [{ tokenToUsdc: tokenToUsdc }]
      );
    });
  });
});
