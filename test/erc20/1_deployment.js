const { expect } = require("chai");
const { ethers } = require("hardhat");
const { admin } = require("../../scripts/config");
const {
  BRAINSTEMS_TOKEN_NAME,
  BRAINSTEMS_TOKEN_SYMBOL,
} = require("../consts");
const { verifyEvents } = require("../utils");

let BrainstemsToken;

describe("ERC20: Deployment", function () {
  before(async () => {
    [owner] = await ethers.getSigners();

    BrainstemsToken = await ethers.getContractFactory("BrainstemsToken");
  });

  describe("should deploy successfully", function () {
    it("with valid parameters", async function () {
      const brainstemsToken = await upgrades.deployProxy(BrainstemsToken, [
        admin
      ]);
      await brainstemsToken.waitForDeployment();

      const name = await brainstemsToken.name();
      expect(name).to.eq(BRAINSTEMS_TOKEN_NAME);

      const symbol = await brainstemsToken.symbol();
      expect(symbol).to.eq(BRAINSTEMS_TOKEN_SYMBOL);

      const adminRole = await brainstemsToken.DEFAULT_ADMIN_ROLE();
      const adminHasAdminRole = await brainstemsToken.hasRole(adminRole, admin);
      expect(adminHasAdminRole).to.be.true;

      const maxSupply = await brainstemsToken.MAX_SUPPLY();
      expect(maxSupply).to.eq(BRAINSTEMS_TOKEN_MAX_SUPPLY);
    });
  });
});
