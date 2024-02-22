const { expect } = require("chai");
const { ethers } = require("hardhat");
const { verifyEvents } = require("../utils");

let owner,
  user1,
  membership,
  ecosystemUnit,
  ecosystemUnit2,
  invalidEcosystemName,
  invalidEcosystemId,
  memberUnit;

describe("Membership: Creation", function () {
  before(async () => {
    [owner, user1] = await ethers.getSigners();

    const Membership = await ethers.getContractFactory("Membership");
    membership = await upgrades.deployProxy(Membership, [
      owner.address
    ]);
    await membership.waitForDeployment();

    ecosystemUnit = {
      id: 1n,
      name: "Ecosystem",
    }

    ecosystemUnit2 = {
      id: 2n,
      name: "Ecosystem2",
    }

    invalidEcosystemName = {
      id: 2n,
      name: "Ecosystem"
    }

    invalidEcosystemId = {
      id: 1n,
      name: "Invalid"
    }

    memberUnit = {
      id: 1n,
      name: "Member",
    }
  });

  describe("should be able to create an ecosystem", function () {
    it("with valid parameters", async function () {
      const tx = await membership.createEcosystem(
        ecosystemUnit
      );
      await tx.wait();

      const expectedEcosystem = [
        ecosystemUnit.id,
        ecosystemUnit.name
      ];

      await verifyEvents(tx, membership, "EcosystemCreated", [
        { id: ecosystemUnit.id, ecosystem: expectedEcosystem },
      ]);

      const contractEcosystem = await membership.getEcosystem(ecosystemUnit.id);
      expect(contractEcosystem.name).to.equal(ecosystemUnit.name);
      expect(contractEcosystem.id).to.equal(ecosystemUnit.id);
    });
  });

  describe("should fail to create an ecosystem", function () {
    it("with invalid parameters", async function () {
      // with id 0
      await expect(
        membership.createEcosystem(
          { id: 0n, name: "Ecosystem" }
        )
      ).to.be.revertedWith("ecosystem id cannot be 0");

      await expect(
        membership.createEcosystem(
          invalidEcosystemName
        )
      ).to.be.revertedWith("ecosystem name already registered");

      await expect(
        membership.createEcosystem(
          invalidEcosystemId
        )
      ).to.be.revertedWith("ecosystem id already registered");

      await expect(
        membership
          .connect(user1)
          .createEcosystem(ecosystemUnit2)
      ).to.be.revertedWithCustomError(
        membership,
        "AccessControlUnauthorizedAccount"
      );
    });
  });

  describe("should be able to create a company", function () {
    it("with valid parameters", async function () {
      const tx = await membership.createCompany(
        memberUnit
      );
      await tx.wait();

      const expectedCompany = [
        memberUnit.id,
        memberUnit.name
      ];

      await verifyEvents(tx, membership, "CompanyCreated", [
        { id: memberUnit.id, company: expectedCompany },
      ]);

      const contractEcosystem = await membership.getCompany(memberUnit.id);
      expect(contractEcosystem.name).to.equal(memberUnit.name);
      expect(contractEcosystem.id).to.equal(memberUnit.id);
    });
  });

  describe("should fail to create a company", function () {
    it("with invalid parameters", async function () {
      await expect(
        membership.createCompany(
          { id: 0n, name: "Company" }
        )
      ).to.be.revertedWith("company id cannot be 0");
      
      await expect(
        membership.createCompany(
          memberUnit
        )
      ).to.be.revertedWith("company id already registered");

      await expect(
        membership
          .connect(user1)
          .createCompany(memberUnit)
      ).to.be.revertedWithCustomError(
        membership,
        "AccessControlUnauthorizedAccount"
      );
    });
  });
});
