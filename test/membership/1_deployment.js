const { expect } = require("chai");
const { ethers } = require("hardhat");
const { admin } = require("../../scripts/config");

let Membership;

describe("Membership: Deployment", function () {
  before(async () => {
    [owner] = await ethers.getSigners();

    Membership = await ethers.getContractFactory("Membership");
  });

  describe("membership should deploy successfully", function () {
    it("with valid parameters", async function () {
      const membership = await upgrades.deployProxy(Membership, [
        admin
      ]);
      await membership.waitForDeployment();

      const adminRole = await membership.DEFAULT_ADMIN_ROLE();
      const adminHasAdminRole = await membership.hasRole(adminRole, admin);
      expect(adminHasAdminRole).to.be.true;
    });
  });
});
