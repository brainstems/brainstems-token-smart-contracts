const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  BRAINSTEMS_TOKEN_TO_USDC,
  USDCOIN_NAME,
  USDCOIN_SYMBOL,
  USDCOIN_DECIMALS,
  BRAINSTEMS_TOKEN_EVENTS,
} = require("../consts");
const { verifyEvents } = require("../utils");

let owner, buyer1, buyer2, buyer3, user, brainstemsToken, usdCoin, earnings;

describe("ERC20: Earnings", function () {
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

    const BrainstemsToken = await ethers.getContractFactory("BrainstemsToken");
    brainstemsToken = await upgrades.deployProxy(BrainstemsToken, [
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

    // move to Public Sale
    await brainstemsToken.moveToNextStage();
    await brainstemsToken.moveToNextStage();

    const purchases = [
      { buyer: buyer1, balance: 100n },
      { buyer: buyer2, balance: 2000n },
      { buyer: buyer3, balance: 100000n },
      { buyer: buyer1, balance: 4890003n },
    ];

    earnings = 0n;
    for await (const purchase of purchases) {
      await brainstemsToken
        .connect(purchase.buyer)
        .buyPublicTokens(purchase.balance);

      const price = purchase.balance * BRAINSTEMS_TOKEN_TO_USDC;
      earnings += price;
    }
  });

  describe("should be able to", function () {
    it("claim earnings with valid parameters", async function () {
      const recipient = user;
      const previousContractUsdcBalance = await usdCoin.balanceOf(
        brainstemsToken.target
      );
      const previousRecipientUsdcBalance = await usdCoin.balanceOf(
        recipient.address
      );

      const tx = await brainstemsToken.claimEarnings(recipient);
      await tx.wait();

      await verifyEvents(tx, brainstemsToken, BRAINSTEMS_TOKEN_EVENTS.EARNINGS_CLAIMED, [
        {
          recipient: recipient.address,
          amount: earnings,
        },
      ]);

      const newContractUsdcBalance = await usdCoin.balanceOf(
        brainstemsToken.target
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
        brainstemsToken.connect(user).claimEarnings(user)
      ).to.be.revertedWithCustomError(
        brainstemsToken,
        "AccessControlUnauthorizedAccount"
      );

      await expect(brainstemsToken.claimEarnings(owner)).to.be.revertedWith(
        "no earnings"
      );
    });
  });
});
