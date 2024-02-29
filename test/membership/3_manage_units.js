const { expect } = require("chai");
const { ethers } = require("hardhat");
const { verifyEvents } = require("../utils");

let owner,
  membership,
  ecosystemUnit,
  memberUnit,
  memberUnitTwo;

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

    memberUnit = {
      id: 1n,
      name: "Coca Cola",
    }

    memberUnitTwo = {
      id: 20n,
      name: "Pepsi",
    }

    const ecosystemTx = await membership.createEcosystem(
      ecosystemUnit
    );
    await ecosystemTx.wait();

    const memberTx = await membership.createCompany(
      memberUnit
    );
    await memberTx.wait();

    const memberTxTwo = await membership.createCompany(
      memberUnitTwo
    );
    await memberTxTwo.wait();
  });

  describe("should be able to add a member to an ecosystem", function () {
    it("with valid parameters", async function () {
      const tx = await membership.addMember(
        ecosystemUnit.id,
        memberUnit.id
      );
      await tx.wait();

      await verifyEvents(tx, membership, "MemberAdded", [
        { ecosystemId: ecosystemUnit.id, memberId: memberUnit.id },
      ]);

      const contractCompanyAssociatedToEcosystem = await membership.getEcosystemCompanies(ecosystemUnit.id, memberUnit.id);
      expect(contractCompanyAssociatedToEcosystem.name).to.equal(memberUnit.name);
      expect(contractCompanyAssociatedToEcosystem.id).to.equal(memberUnit.id);

      const tx2 = await membership.addMember(
        ecosystemUnit.id,
        memberUnitTwo.id
      );
      await tx2.wait();

      await verifyEvents(tx2, membership, "MemberAdded", [
        { ecosystemId: ecosystemUnit.id, memberId: memberUnitTwo.id },
      ]);

      const contractCompanyAssociatedToEcosystem2 = await membership.getEcosystemCompanies(ecosystemUnit.id, memberUnitTwo.id);
      expect(contractCompanyAssociatedToEcosystem2.name).to.equal(memberUnitTwo.name);
      expect(contractCompanyAssociatedToEcosystem2.id).to.equal(memberUnitTwo.id);
    });
  });

  describe("should fail to add a member to an ecosystem", function () {
    it("with invalid parameters", async function () {
      const tx = membership.addMember(
        ecosystemUnit.id,
        memberUnit.id
      );
      await expect(tx).to.be.revertedWith("company already part of ecosystem");

      const invalidEcosystemId = 2n;
      const tx2 = membership.addMember(
        invalidEcosystemId,
        memberUnit.id
      );
      await expect(tx2).to.be.revertedWith("ecosystem id not found");

      const invalidMemberId = 2n;
      const tx3 = membership.addMember(
        ecosystemUnit.id,
        invalidMemberId
      );
      await expect(tx3).to.be.revertedWith("company id not found");
    });
  });

  describe("should be able to remove a member from an ecosystem", function () {
    it("with valid parameters", async function () {
      const tx = await membership.removeMember(
        ecosystemUnit.id,
        memberUnit.id
      );
      await tx.wait();

      await verifyEvents(tx, membership, "MemberRemoved", [
        { ecosystemId: ecosystemUnit.id, memberId: memberUnit.id },
      ]);

      const contractCompanyAssociatedToEcosystem = await membership.getEcosystemCompanies(ecosystemUnit.id, memberUnit.id);
      expect(contractCompanyAssociatedToEcosystem.name).to.equal("");
      expect(contractCompanyAssociatedToEcosystem.id).to.equal(0n);
    });
  });

  describe("should fail to remove a member from an ecosystem", function () {
    it("with invalid parameters", async function () {
      const tx = membership.removeMember(
        ecosystemUnit.id,
        memberUnit.id
      );
      await expect(tx).to.be.revertedWith("company not part of ecosystem");

      const invalidEcosystemId = 2n;
      const tx2 = membership.removeMember(
        invalidEcosystemId,
        memberUnit.id
      );
      await expect(tx2).to.be.revertedWith("ecosystem id not found");

      const invalidMemberId = 2n;
      const tx3 = membership.removeMember(
        ecosystemUnit.id,
        invalidMemberId
      );
      await expect(tx3).to.be.revertedWith("company id not found");
    });
  });

  describe("should be able to add a user to a company in ecosystem", function () {
    it("with valid parameters", async function () {
      const tx = await membership.addUser(
        ecosystemUnit.id,
        memberUnitTwo.id,
        user1.address
      );
      await tx.wait();

      await verifyEvents(tx, membership, "UserAdded", [
        { ecosystemId: ecosystemUnit.id, companyId: memberUnitTwo.id, user: user1.address },
      ]);

      const contractUserAssociatedToCompany = await membership.getActiveUser(ecosystemUnit.id, memberUnitTwo.id, user1.address);
      expect(contractUserAssociatedToCompany).to.equal(true);
    });
  });

  describe("should fail to add a user to a company in ecosystem", function () {
    it("with invalid parameters", async function () {
      const tx = membership.addUser(
        ecosystemUnit.id,
        memberUnitTwo.id,
        user1.address
      );
      await expect(tx).to.be.revertedWith("user already part of company");

      const invalidEcosystemId = 2n;
      const tx2 = membership.addUser(
        invalidEcosystemId,
        memberUnitTwo.id,
        user1.address
      );
      await expect(tx2).to.be.revertedWith("ecosystem id not found");

      const invalidMemberId = 2n;
      const tx3 = membership.addUser(
        ecosystemUnit.id,
        invalidMemberId,
        user1.address
      );
      await expect(tx3).to.be.revertedWith("company id not found");

      const tx4 = membership.addUser(
        ecosystemUnit.id,
        memberUnit.id,
        owner.address
      );
      await expect(tx4).to.be.revertedWith("company not part of ecosystem");
    });
  });

  describe("should be able to remove a user from a company in ecosystem", function () {
    it("with valid parameters", async function () {
      const tx = await membership.removeUser(
        ecosystemUnit.id,
        memberUnitTwo.id,
        user1.address
      );
      await tx.wait();

      await verifyEvents(tx, membership, "UserRemoved", [
        { ecosystemId: ecosystemUnit.id, companyId: memberUnitTwo.id, user: user1.address },
      ]);

      const contractUserAssociatedToCompany = await membership.getActiveUser(ecosystemUnit.id, memberUnitTwo.id, user1.address);
      expect(contractUserAssociatedToCompany).to.equal(false);
    });
  });

  describe("should fail to remove a user from a company in ecosystem", function () {
    it("with invalid parameters", async function () {
      const tx = membership.removeUser(
        ecosystemUnit.id,
        memberUnitTwo.id,
        user1.address
      );
      await expect(tx).to.be.revertedWith("user not part of company");

      const invalidEcosystemId = 2n;
      const tx2 = membership.removeUser(
        invalidEcosystemId,
        memberUnitTwo.id,
        user1.address
      );
      await expect(tx2).to.be.revertedWith("ecosystem id not found");

      const invalidMemberId = 2n;
      const tx3 = membership.removeUser(
        ecosystemUnit.id,
        invalidMemberId,
        user1.address
      );
      await expect(tx3).to.be.revertedWith("company id not found");

      const tx4 = membership.removeUser(
        ecosystemUnit.id,
        memberUnit.id,
        owner.address
      );
      await expect(tx4).to.be.revertedWith("company not part of ecosystem");
    });
  });
});
