const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  INTELLTOKEN_MAX_SUPPLY,
  INTELLTOKEN_SALES_CAP,
  INTELLTOKEN_TO_USDC,
  USDCOIN_NAME,
  USDCOIN_SYMBOL,
  USDCOIN_DECIMALS,
  INTELLTOKEN_EVENTS,
  INTELLTOKEN_STAGES,
} = require("./consts");
const { verifyEvents } = require("./utils");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

let owner, buyer1, buyer2, buyer3;

describe("Public Sale", function () {
  async function setupFixture() {
    [owner, buyer1, buyer2, buyer3] = await ethers.getSigners();

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

  describe("should be able to buy public tokens", function () {
    it("with valid parameters", async function () {
      const { intellToken, usdCoin } = await loadFixture(setupFixture);

      // move to Public Sale
      await intellToken.moveToNextStage();
      await intellToken.moveToNextStage();

      const amount = 250n;

      for await (const buyer of [buyer1, buyer2, buyer3]) {
        const previousBuyerIntellTokenBalance = await intellToken.balanceOf(
          buyer
        );
        const previousBuyerUsdcBalance = await usdCoin.balanceOf(buyer);
        const previousContractUsdcBalance = await usdCoin.balanceOf(
          intellToken.target
        );
        const previousTokenSupply = await intellToken.totalSupply();
        const previousSoldTokens = await intellToken.tokensSold();

        const price = amount * INTELLTOKEN_TO_USDC;

        const tx = await intellToken.connect(buyer).buyPublicTokens(amount);
        await tx.wait();

        const newBuyerIntellTokenBalance = await intellToken.balanceOf(buyer);
        const newBuyerUsdcBalance = await usdCoin.balanceOf(buyer);
        const newContractUsdcBalance = await usdCoin.balanceOf(
          intellToken.target
        );
        const newTokenSupply = await intellToken.totalSupply();
        const newSoldTokens = await intellToken.tokensSold();

        expect(
          newBuyerIntellTokenBalance - previousBuyerIntellTokenBalance
        ).to.eq(amount);
        expect(previousBuyerUsdcBalance - newBuyerUsdcBalance).to.eq(price);
        expect(newContractUsdcBalance - previousContractUsdcBalance).to.eq(
          price
        );
        expect(newTokenSupply - previousTokenSupply).to.eq(amount);
        expect(newSoldTokens - previousSoldTokens).to.eq(amount);

        await verifyEvents(
          tx,
          intellToken,
          INTELLTOKEN_EVENTS.TOKENS_PURCHASED,
          [
            {
              buyer: buyer.address,
              amount: amount,
              price: price,
              stage: INTELLTOKEN_STAGES.PUBLIC_SALE,
            },
          ]
        );
      }
    });
  });

  describe("should fail to buy public tokens", function () {
    it("during an invalid stage", async function () {
      const { intellToken } = await loadFixture(setupFixture);
      const amount = 10n;

      // Whitelisting
      await expect(
        intellToken.connect(buyer1).buyPublicTokens(amount)
      ).to.be.revertedWith("invalid stage");

      // Private Sale
      await intellToken.moveToNextStage();
      await expect(
        intellToken.connect(buyer1).buyPublicTokens(amount)
      ).to.be.revertedWith("invalid stage");

      // Finished
      await intellToken.moveToNextStage();
      await intellToken.moveToNextStage();
      await expect(
        intellToken.connect(buyer1).buyPublicTokens(amount)
      ).to.be.revertedWith("invalid stage");
    });

    it("with invalid parameters", async function () {
      const { intellToken } = await loadFixture(setupFixture);

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
