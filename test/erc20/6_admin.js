const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  BRAINSTEMS_TOKEN_TO_USDC,
  USDCOIN_NAME,
  USDCOIN_SYMBOL,
  USDCOIN_DECIMALS,
  BRAINSTEMS_TOKEN_EVENTS,
  BRAINSTEMS_TOKEN_STAGES,
  BRAINSTEMS_TOKEN_MAX_SUPPLY,
} = require("../consts");
const { verifyEvents } = require("../utils");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");

let owner, user, brainstemsToken, usdCoin;

describe("ERC20: Admin actions", function () {
  before(async () => {
    [owner, user] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    usdCoin = await TestErc20.deploy(
      USDCOIN_NAME,
      USDCOIN_SYMBOL,
      USDCOIN_DECIMALS
    );
    await usdCoin.waitForDeployment();

    const BrainstemsToken = await ethers.getContractFactory("BrainstemsToken");
    brainstemsToken = await upgrades.deployProxy(BrainstemsToken, [
      owner.address,
      usdCoin.target,
      BRAINSTEMS_TOKEN_TO_USDC,
    ]);
    await brainstemsToken.waitForDeployment();
  });

  describe("should be able to", function () {
    it("set whitelist root with valid parameters", async function () {
      const tree = StandardMerkleTree.of([[owner.address]], ["address"]);

      const tx = await brainstemsToken.setWhitelistRoot(tree.root);
      await tx.wait();

      await verifyEvents(
        tx,
        brainstemsToken,
        BRAINSTEMS_TOKEN_EVENTS.WHITELIST_UPDATED,
        [
          {
            root: tree.root,
          },
        ]
      );

      const contractRoot = await brainstemsToken.whitelistRoot();
      expect(contractRoot).to.eq(tree.root);
    });

    it("set price with valid parameters", async function () {
      const newPrice = BRAINSTEMS_TOKEN_TO_USDC * 2n;

      const tx = await brainstemsToken.setPrice(newPrice);
      await tx.wait();

      await verifyEvents(tx, brainstemsToken, BRAINSTEMS_TOKEN_EVENTS.PRICE_UPDATED, [
        {
          rate: newPrice,
        },
      ]);
    });

    it("move to next stage with valid parameters", async function () {
      for await (const stage of [
        BRAINSTEMS_TOKEN_STAGES.PRIVATE_SALE,
        BRAINSTEMS_TOKEN_STAGES.PUBLIC_SALE,
        BRAINSTEMS_TOKEN_STAGES.FINISHED,
      ]) {
        const tx = await brainstemsToken.moveToNextStage();
        await tx.wait();

        await verifyEvents(tx, brainstemsToken, BRAINSTEMS_TOKEN_EVENTS.ENTERED_STAGE, [
          {
            stage: stage,
          },
        ]);
      }
    });

    it("pause and unpause with valid parameters", async function () {
      await brainstemsToken.pause();

      let isPaused = await brainstemsToken.paused();
      expect(isPaused).to.be.true;

      await brainstemsToken.unpause();

      isPaused = await brainstemsToken.paused();
      expect(isPaused).to.be.false;
    });

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
    it("set whitelist root with invalid parameters", async function () {
      const tree = StandardMerkleTree.of([[owner.address]], ["address"]);

      await expect(
        brainstemsToken.connect(user).setWhitelistRoot(tree.root)
      ).to.be.revertedWithCustomError(
        brainstemsToken,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("set price with invalid parameters", async function () {
      await expect(brainstemsToken.setPrice(0n)).to.be.revertedWith(
        "invalid price"
      );

      await expect(
        brainstemsToken.connect(user).setPrice(BRAINSTEMS_TOKEN_TO_USDC)
      ).to.be.revertedWithCustomError(
        brainstemsToken,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("move to next stage with invalid parameters", async function () {
      await expect(brainstemsToken.moveToNextStage()).to.be.revertedWith(
        "sales finished"
      );

      await expect(
        brainstemsToken.connect(user).moveToNextStage()
      ).to.be.revertedWithCustomError(
        brainstemsToken,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("pause and unpause with valid parameters", async function () {
      await expect(
        brainstemsToken.connect(user).pause()
      ).to.be.revertedWithCustomError(
        brainstemsToken,
        "AccessControlUnauthorizedAccount"
      );

      await expect(
        brainstemsToken.connect(user).unpause()
      ).to.be.revertedWithCustomError(
        brainstemsToken,
        "AccessControlUnauthorizedAccount"
      );
    });

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
