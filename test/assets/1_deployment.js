const { expect } = require("chai");
const { ethers } = require("hardhat");
const { admin } = require("../../scripts/config");
const {
  BRAINSTEMS_TOKEN_NAME,
  BRAINSTEMS_TOKEN_SYMBOL,
  BRAINSTEMS_TOKEN_DECIMALS,
} = require("../consts");

let brainstemsToken, Assets;

describe("Assets: Deployment", function () {
  before(async () => {
    [owner] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    brainstemsToken = await TestErc20.deploy(
      BRAINSTEMS_TOKEN_NAME,
      BRAINSTEMS_TOKEN_SYMBOL,
      BRAINSTEMS_TOKEN_DECIMALS
    );
    await brainstemsToken.waitForDeployment();

    Assets = await ethers.getContractFactory("Assets");
  });

  describe("should fail to deploy with", function () {
    it("invalid payment token contract", async function () {
      await expect(
        upgrades.deployProxy(Assets, [admin, ethers.ZeroAddress])
      ).to.be.revertedWith("invalid contract address");
    });
  });

  describe("should deploy successfully", function () {
    it("with valid parameters", async function () {
      const assets = await upgrades.deployProxy(Assets, [
        admin,
        brainstemsToken.target,
      ]);
      await assets.waitForDeployment();

      const adminRole = await assets.DEFAULT_ADMIN_ROLE();
      const adminHasAdminRole = await assets.hasRole(adminRole, admin);
      expect(adminHasAdminRole).to.be.true;

      const paymentTokenContract = await assets.paymentToken();
      expect(paymentTokenContract).to.eq(brainstemsToken.target);
    });
  });
});
