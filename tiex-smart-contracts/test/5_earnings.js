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
  INTELLTOKEN_INVESTORS_CAP,
} = require("./consts");
const { verifyEvents } = require("./utils");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

let owner, buyer1, buyer2, buyer3, user, intellToken, usdCoin, earnings;

describe("Earnings", function () {
  before(async () => {
    [owner, buyer1, buyer2, buyer3, user] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    usdCoin = await TestErc20.deploy(
      USDCOIN_NAME,
      USDCOIN_SYMBOL,
      USDCOIN_DECIMALS
    );
    await usdCoin.waitForDeployment();

    for await (const addr of [owner, buyer1, buyer2, buyer3]) {
      await usdCoin.mint(addr, 1000000000000000000000000000n);
    }

    const IntellToken = await ethers.getContractFactory("IntelligenceToken");
    intellToken = await upgrades.deployProxy(IntellToken, [
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

    // move to Public Sale
    await intellToken.moveToNextStage();
    await intellToken.moveToNextStage();

    const purchases = [
      { buyer: buyer1, balance: 100n },
      { buyer: buyer2, balance: 2000n },
      { buyer: buyer3, balance: 100000n },
      { buyer: buyer1, balance: 4890003n },
    ];

    earnings = 0n;
    for await (const purchase of purchases) {
      await intellToken
        .connect(purchase.buyer)
        .buyPublicTokens(purchase.balance);

      const price = purchase.balance * INTELLTOKEN_TO_USDC;
      earnings += price;
    }
  });

  describe("should be able to", function () {
    it("claim earnings with valid parameters", async function () {
      const recipient = user;
      const previousContractUsdcBalance = await usdCoin.balanceOf(
        intellToken.target
      );
      const previousRecipientUsdcBalance = await usdCoin.balanceOf(
        recipient.address
      );

      const tx = await intellToken.claimEarnings(recipient);
      await tx.wait();

      await verifyEvents(tx, intellToken, INTELLTOKEN_EVENTS.EARNINGS_CLAIMED, [
        {
          recipient: recipient.address,
          amount: earnings,
        },
      ]);

      const newContractUsdcBalance = await usdCoin.balanceOf(
        intellToken.target
      );
      const newRecipientUsdcBalance = await usdCoin.balanceOf(
        recipient.address
      );

      expect(previousContractUsdcBalance - newContractUsdcBalance).to.eq(
        earnings
      );
      expect(newRecipientUsdcBalance - previousRecipientUsdcBalance).to.eq(
        earnings
      );
    });
  });

  describe("should fail to", function () {
    it("claim earnings with invalid parameters", async function () {
      await expect(
        intellToken.connect(user).claimEarnings(user)
      ).to.be.revertedWithCustomError(
        intellToken,
        "AccessControlUnauthorizedAccount"
      );

      await expect(intellToken.claimEarnings(owner)).to.be.revertedWith(
        "no earnings"
      );
    });
  });
});
