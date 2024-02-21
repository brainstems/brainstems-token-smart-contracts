const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  BRAINSTEMS_TOKEN_MAX_SUPPLY,
  BRAINSTEMS_TOKEN_SALES_CAP,
  BRAINSTEMS_TOKEN_TO_USDC,
  USDCOIN_NAME,
  USDCOIN_SYMBOL,
  USDCOIN_DECIMALS,
  BRAINSTEMS_TOKEN_EVENTS,
  BRAINSTEMS_TOKEN_STAGES,
} = require("../consts");
const { verifyEvents } = require("../utils");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

let owner, buyer1, buyer2, buyer3;

describe("ERC20: Public Sale", function () {
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

    const BrainstemsToken = await ethers.getContractFactory("BrainstemsToken");
    const brainstemsToken = await upgrades.deployProxy(BrainstemsToken, [
      owner.address,
      usdCoin.target,
      BRAINSTEMS_TOKEN_TO_USDC,
    ]);
    await brainstemsToken.waitForDeployment();

    for await (const addr of [owner, buyer1, buyer2, buyer3]) {
      await usdCoin
        .connect(addr)
        .approve(brainstemsToken.target, ethers.MaxUint256);
    }

    return { brainstemsToken, usdCoin };
  }

  describe("should be able to buy public tokens", function () {
    it("with valid parameters", async function () {
      const { brainstemsToken, usdCoin } = await loadFixture(setupFixture);

      // move to Public Sale
      await brainstemsToken.moveToNextStage();
      await brainstemsToken.moveToNextStage();

      const amount = 250n;

      for await (const buyer of [buyer1, buyer2, buyer3]) {
        const previousBuyerBrainstemsTokenBalance = await brainstemsToken.balanceOf(
          buyer
        );
        const previousBuyerUsdcBalance = await usdCoin.balanceOf(buyer);
        const previousContractUsdcBalance = await usdCoin.balanceOf(
          brainstemsToken.target
        );
        const previousTokenSupply = await brainstemsToken.totalSupply();
        const previousSoldTokens = await brainstemsToken.tokensSold();

        const price = amount * BRAINSTEMS_TOKEN_TO_USDC;

        const tx = await brainstemsToken.connect(buyer).buyPublicTokens(amount);
        await tx.wait();

        const newBuyerBrainstemsTokenBalance = await brainstemsToken.balanceOf(buyer);
        const newBuyerUsdcBalance = await usdCoin.balanceOf(buyer);
        const newContractUsdcBalance = await usdCoin.balanceOf(
          brainstemsToken.target
        );
        const newTokenSupply = await brainstemsToken.totalSupply();
        const newSoldTokens = await brainstemsToken.tokensSold();

        expect(
          newBuyerBrainstemsTokenBalance - previousBuyerBrainstemsTokenBalance
        ).to.eq(amount);
        expect(previousBuyerUsdcBalance - newBuyerUsdcBalance).to.eq(price);
        expect(newContractUsdcBalance - previousContractUsdcBalance).to.eq(
          price
        );
        expect(newTokenSupply - previousTokenSupply).to.eq(amount);
        expect(newSoldTokens - previousSoldTokens).to.eq(amount);

        await verifyEvents(
          tx,
          brainstemsToken,
          BRAINSTEMS_TOKEN_EVENTS.TOKENS_PURCHASED,
          [
            {
              buyer: buyer.address,
              amount: amount,
              price: price,
              stage: BRAINSTEMS_TOKEN_STAGES.PUBLIC_SALE,
            },
          ]
        );
      }
    });
  });

  describe("should fail to buy public tokens", function () {
    it("during an invalid stage", async function () {
      const { brainstemsToken } = await loadFixture(setupFixture);
      const amount = 10n;

      // Whitelisting
      await expect(
        brainstemsToken.connect(buyer1).buyPublicTokens(amount)
      ).to.be.revertedWith("invalid stage");

      // Private Sale
      await brainstemsToken.moveToNextStage();
      await expect(
        brainstemsToken.connect(buyer1).buyPublicTokens(amount)
      ).to.be.revertedWith("invalid stage");

      // Finished
      await brainstemsToken.moveToNextStage();
      await brainstemsToken.moveToNextStage();
      await expect(
        brainstemsToken.connect(buyer1).buyPublicTokens(amount)
      ).to.be.revertedWith("invalid stage");
    });

    it("with invalid parameters", async function () {
      const { brainstemsToken } = await loadFixture(setupFixture);

      const amount = 100n;

      // move to Public Sale
      await brainstemsToken.moveToNextStage();
      await brainstemsToken.moveToNextStage();

      await expect(
        brainstemsToken.connect(buyer1).buyPublicTokens(0)
      ).to.be.revertedWith("amount is 0");

      await brainstemsToken.pause();

      await expect(
        brainstemsToken.connect(buyer1).buyPublicTokens(amount)
      ).to.be.revertedWithCustomError(brainstemsToken, "EnforcedPause");

      await brainstemsToken.unpause();

      const lockedAmount = BRAINSTEMS_TOKEN_SALES_CAP - amount + 1n;
      await brainstemsToken.buyPublicTokens(lockedAmount);

      await expect(
        brainstemsToken.connect(buyer1).buyPublicTokens(amount)
      ).to.be.revertedWith("insufficient available tokens");

      await brainstemsToken.distribute(
        owner,
        BRAINSTEMS_TOKEN_MAX_SUPPLY - lockedAmount
      );

      await expect(
        brainstemsToken.connect(buyer1).buyPublicTokens(1n)
      ).to.be.revertedWith("exceeds maximum supply");
    });
  });
});
