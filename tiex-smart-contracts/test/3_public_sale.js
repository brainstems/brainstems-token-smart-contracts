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
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

let owner, buyer1, buyer2, buyer3, user;

describe("Public Sale", function () {
  async function setupFixture() {
    [owner, buyer1, buyer2, buyer3, user] = await ethers.getSigners();

    const IntellToken = await ethers.getContractFactory("IntelligenceToken");
    const intellToken = await upgrades.deployProxy(IntellToken, [
      owner.address,
      usdcToken,
      tokenToUsdc,
    ]);
    await intellToken.waitForDeployment();

    return intellToken;
  }

  describe("should fail to buy tokens", function () {
    it("during an invalid stage", async function () {
      const intellToken = await loadFixture(setupFixture);

      // Whitelisting
      await expect(
        intellToken.connect(buyer1).buyPublicTokens(10)
      ).to.be.revertedWith("invalid stage");

      // Private sale
      await intellToken.moveToNextStage();
      await expect(
        intellToken.connect(buyer1).buyPublicTokens(10)
      ).to.be.revertedWith("invalid stage");

      // Finished
      await intellToken.moveToNextStage();
      await intellToken.moveToNextStage();
      await expect(
        intellToken.connect(buyer1).buyPublicTokens(10)
      ).to.be.revertedWith("invalid stage");
    });
  });
});
