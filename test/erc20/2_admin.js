const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  BRAINSTEMS_TOKEN_EVENTS,
  BRAINSTEMS_TOKEN_MAX_SUPPLY,
} = require("../consts");
const { verifyEvents } = require("../utils");

let owner, user, brainstemsToken, testAccount;

describe("ERC20: Admin actions", function () {
  before(async () => {
    [owner, user, testAccount] = await ethers.getSigners();

    const BrainstemsToken = await ethers.getContractFactory("BrainstemsToken");
    brainstemsToken = await upgrades.deployProxy(BrainstemsToken, [
      owner.address
    ]); 
    await brainstemsToken.waitForDeployment();

    await brainstemsToken.grantRole(
      await brainstemsToken.MINTER_ROLE(),
      testAccount
    );
  });

  describe("should be able to", function () {
    it("mint tokens with valid parameters", async function () {
      const recipient = user;
      const amount = 1000000000000n;

      const previousRecipientBrainstemsTokenBalance = await brainstemsToken.balanceOf(
        recipient
      );

      const tx = await brainstemsToken.connect(testAccount).mint(recipient, amount);
      await tx.wait();

      await verifyEvents(
        tx,
        brainstemsToken,
        BRAINSTEMS_TOKEN_EVENTS.TRANSFER,
        [
          {
            from: ethers.ZeroAddress,
            to: recipient.address,
            value: amount
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
    it("mint tokens with invalid parameters", async function () {
      const recipient = user;
      const amount = BRAINSTEMS_TOKEN_MAX_SUPPLY;

      await expect(
        brainstemsToken.connect(owner).mint(recipient, amount)
      ).to.be.revertedWithCustomError(
        brainstemsToken,
        "AccessControlUnauthorizedAccount"
      );

      await expect(
        brainstemsToken.connect(testAccount).mint(recipient, amount)
      ).to.be.revertedWith("exceeds maximum supply");
    });
  });
  
});
