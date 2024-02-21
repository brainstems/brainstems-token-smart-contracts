const { expect } = require("chai");
const { ethers } = require("hardhat");
const { admin, usdcToken, tokenToUsdc } = require("../../scripts/config");
const {
  BRAINSTEMS_TOKEN_NAME,
  BRAINSTEMS_TOKEN_SYMBOL,
  BRAINSTEMS_TOKEN_STAGES,
  BRAINSTEMS_TOKEN_EVENTS,
  BRAINSTEMS_TOKEN_MAX_SUPPLY,
  BRAINSTEMS_TOKEN_INVESTORS_CAP,
  BRAINSTEMS_TOKEN_SALES_CAP,
} = require("../consts");
const { verifyEvents } = require("../utils");

let BrainstemsToken;

describe("ERC20: Deployment", function () {
  before(async () => {
    [owner] = await ethers.getSigners();

    BrainstemsToken = await ethers.getContractFactory("BrainstemsToken");
  });

  describe("should fail to deploy with", function () {
    it("invalid token/USDC conversion", async function () {
      await expect(
        upgrades.deployProxy(BrainstemsToken, [admin, usdcToken, 0n])
      ).to.be.revertedWith("invalid conversion");
    });

    it("invalid USDC token contract", async function () {
      await expect(
        upgrades.deployProxy(BrainstemsToken, [
          admin,
          ethers.ZeroAddress,
          tokenToUsdc,
        ])
      ).to.be.revertedWith("invalid contract param");
    });
  });

  describe("should deploy successfully", function () {
    it("with valid parameters", async function () {
      const brainstemsToken = await upgrades.deployProxy(BrainstemsToken, [
        admin,
        usdcToken,
        tokenToUsdc,
      ]);
      const tx = await brainstemsToken.waitForDeployment();
      const deploymentTx = tx.deploymentTransaction();

      const name = await brainstemsToken.name();
      expect(name).to.eq(BRAINSTEMS_TOKEN_NAME);

      const symbol = await brainstemsToken.symbol();
      expect(symbol).to.eq(BRAINSTEMS_TOKEN_SYMBOL);

      const adminRole = await brainstemsToken.DEFAULT_ADMIN_ROLE();
      const adminHasAdminRole = await brainstemsToken.hasRole(adminRole, admin);
      expect(adminHasAdminRole).to.be.true;

      const usdcTokenContract = await brainstemsToken.usdcToken();
      expect(usdcTokenContract).to.eq(usdcToken);

      const tokenUsdcConversion = await brainstemsToken.tokenToUsdc();
      expect(tokenUsdcConversion).to.eq(tokenToUsdc);

      const stage = await brainstemsToken.currentStage();
      expect(stage).to.eq(BRAINSTEMS_TOKEN_STAGES.WHITELISTING);

      const maxSupply = await brainstemsToken.MAX_SUPPLY();
      expect(maxSupply).to.eq(BRAINSTEMS_TOKEN_MAX_SUPPLY);

      const investorsCap = await brainstemsToken.INVESTORS_CAP();
      expect(investorsCap).to.eq(BRAINSTEMS_TOKEN_INVESTORS_CAP);

      const salesCap = await brainstemsToken.SALES_CAP();
      expect(salesCap).to.eq(BRAINSTEMS_TOKEN_SALES_CAP);

      await verifyEvents(
        deploymentTx,
        brainstemsToken,
        BRAINSTEMS_TOKEN_EVENTS.PRICE_UPDATED,
        [{ tokenToUsdc: tokenToUsdc }]
      );

      await verifyEvents(
        deploymentTx,
        brainstemsToken,
        BRAINSTEMS_TOKEN_EVENTS.ENTERED_STAGE,
        [{ stage: BRAINSTEMS_TOKEN_STAGES.WHITELISTING }]
      );
    });
  });
});
