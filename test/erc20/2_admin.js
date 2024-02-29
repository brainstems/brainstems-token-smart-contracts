const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  BRAINSTEMS_TOKEN_EVENTS,
  BRAINSTEMS_TOKEN_MAX_SUPPLY,
} = require("../consts");
const { verifyEvents } = require("../utils");

let owner, user, brainstemsToken;

describe("ERC20: Admin actions", function () {
  before(async () => {
    [owner, user] = await ethers.getSigners();

    const BrainstemsToken = await ethers.getContractFactory("BrainstemsToken");
    brainstemsToken = await upgrades.deployProxy(BrainstemsToken, [
      owner.address
    ]);
    await brainstemsToken.waitForDeployment();
  });

  describe("should be able to", function () {
    it("distribute tokens with valid parameters", async function () {
      const recipient = user;
      const amount = 100000000000n;

      const previousRecipientBrainstemsTokenBalance = await brainstemsToken.balanceOf(
        recipient
      );

      const tx = await brainstemsToken.distribute(recipient, amount);
      await tx.wait();

      await verifyEvents(
        tx,
        brainstemsToken,
        BRAINSTEMS_TOKEN_EVENTS.TOKENS_DISTRIBUTED,
        [
          {
            recipient: recipient.address,
            amount: amount,
          },
        ]
      );

      const newRecipientBrainstemsTokenBalance = await brainstemsToken.balanceOf(
        recipient
      );

      expect(
        newRecipientBrainstemsTokenBalance - previousRecipientBrainstemsTokenBalance
      ).to.eq(amount);
    });
  });

  describe("should fail to", function () {
    it("distribute tokens with invalid parameters", async function () {
      const recipient = user;
      const amount = BRAINSTEMS_TOKEN_MAX_SUPPLY;

      await expect(
        brainstemsToken.connect(user).distribute(recipient, amount)
      ).to.be.revertedWithCustomError(
        brainstemsToken,
        "AccessControlUnauthorizedAccount"
      );

      await expect(
        brainstemsToken.distribute(recipient, amount)
      ).to.be.revertedWith("exceeds maximum supply");
    });
  });
});
