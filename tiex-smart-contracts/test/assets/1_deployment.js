const { expect } = require("chai");
const { ethers } = require("hardhat");
const { admin } = require("../../scripts/config");
const {
  INTELLTOKEN_NAME,
  INTELLTOKEN_SYMBOL,
  INTELL_TOKEN_DECIMALS,
} = require("../consts");

let owner, intellToken, Assets;

describe("Assets: Deployment", function () {
  before(async () => {
    [owner] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    intellToken = await TestErc20.deploy(
      INTELLTOKEN_NAME,
      INTELLTOKEN_SYMBOL,
      INTELL_TOKEN_DECIMALS
    );
    await intellToken.waitForDeployment();

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
        intellToken.target,
      ]);
      await assets.waitForDeployment();

      const adminRole = await assets.DEFAULT_ADMIN_ROLE();
      const adminHasAdminRole = await assets.hasRole(adminRole, admin);
      expect(adminHasAdminRole).to.be.true;

      const paymentTokenContract = await assets.paymentToken();
      expect(paymentTokenContract).to.eq(intellToken.target);
    });
  });
});
