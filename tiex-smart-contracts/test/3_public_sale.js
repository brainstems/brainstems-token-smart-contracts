const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  INTELLTOKEN_NAME,
  INTELLTOKEN_SYMBOL,
  INTELLTOKEN_STAGES,
  INTELLTOKEN_EVENTS,
  INTELLTOKEN_MAX_SUPPLY,
  INTELLTOKEN_SALES_CAP,
  INTELLTOKEN_TO_USDC,
  USDCOIN_NAME,
  USDCOIN_SYMBOL,
  USDCOIN_DECIMALS,
} = require("./consts");
const { verifyEvents } = require("./utils");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

let owner, buyer1, buyer2, buyer3, user;

describe("Public Sale", function () {
  async function setupFixture() {
    [owner, buyer1, buyer2, buyer3, user] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    const usdCoin = await TestErc20.deploy(
      USDCOIN_NAME,
      USDCOIN_SYMBOL,
      USDCOIN_DECIMALS
    );
    await usdCoin.waitForDeployment();

    for await (const addr of [owner, buyer1, buyer2, buyer3]) {
      await usdCoin.mint(addr, 1000000000000000000000000000n);
    }

    const IntellToken = await ethers.getContractFactory("IntelligenceToken");
    const intellToken = await upgrades.deployProxy(IntellToken, [
      owner.address,
      usdCoin.target,
      INTELLTOKEN_TO_USDC,
    ]);
    await intellToken.waitForDeployment();

    for await (const addr of [owner, buyer1, buyer2, buyer3]) {
      await usdCoin
        .connect(addr)
        .approve(intellToken.target, ethers.MaxUint256);
    }

    return { intellToken, usdCoin };
  }

  describe("should fail to buy tokens", function () {
    it("during an invalid stage", async function () {
      const { intellToken } = await loadFixture(setupFixture);

      // Whitelisting
      await expect(
        intellToken.connect(buyer1).buyPublicTokens(10)
      ).to.be.revertedWith("invalid stage");

      // Private Sale
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

    it("with invalid parameters", async function () {
      const { intellToken, usdCoin } = await loadFixture(setupFixture);

      const amount = 100n;

      // move to Public Sale
      await intellToken.moveToNextStage();
      await intellToken.moveToNextStage();

      await expect(
        intellToken.connect(buyer1).buyPublicTokens(0)
      ).to.be.revertedWith("amount is 0");

      await intellToken.pause();

      await expect(
        intellToken.connect(buyer1).buyPublicTokens(amount)
      ).to.be.revertedWithCustomError(intellToken, "EnforcedPause");

      await intellToken.unpause();

      const lockedAmount = INTELLTOKEN_SALES_CAP - amount + 1n;
      await intellToken.buyPublicTokens(lockedAmount);

      await expect(
        intellToken.connect(buyer1).buyPublicTokens(amount)
      ).to.be.revertedWith("insufficient available tokens");

      await intellToken.distribute(
        owner,
        INTELLTOKEN_MAX_SUPPLY - lockedAmount
      );

      await expect(
        intellToken.connect(buyer1).buyPublicTokens(1n)
      ).to.be.revertedWith("exceeds maximum supply");
    });
  });
});
