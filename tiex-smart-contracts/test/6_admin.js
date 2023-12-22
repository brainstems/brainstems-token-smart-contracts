const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  INTELLTOKEN_TO_USDC,
  USDCOIN_NAME,
  USDCOIN_SYMBOL,
  USDCOIN_DECIMALS,
  INTELLTOKEN_EVENTS,
  INTELLTOKEN_STAGES,
  INTELLTOKEN_MAX_SUPPLY,
} = require("./consts");
const { verifyEvents } = require("./utils");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");

let owner, user, intellToken, usdCoin;

describe("Admin actions", function () {
  before(async () => {
    [owner, user] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    usdCoin = await TestErc20.deploy(
      USDCOIN_NAME,
      USDCOIN_SYMBOL,
      USDCOIN_DECIMALS
    );
    await usdCoin.waitForDeployment();

    const IntellToken = await ethers.getContractFactory("IntelligenceToken");
    intellToken = await upgrades.deployProxy(IntellToken, [
      owner.address,
      usdCoin.target,
      INTELLTOKEN_TO_USDC,
    ]);
    await intellToken.waitForDeployment();
  });

  describe("should be able to", function () {
    it("set whitelist root with valid parameters", async function () {
      const tree = StandardMerkleTree.of([[owner.address]], ["address"]);

      const tx = await intellToken.setWhitelistRoot(tree.root);
      await tx.wait();

      await verifyEvents(
        tx,
        intellToken,
        INTELLTOKEN_EVENTS.WHITELIST_UPDATED,
        [
          {
            root: tree.root,
          },
        ]
      );
    });

    it("set price with valid parameters", async function () {
      const newPrice = INTELLTOKEN_TO_USDC * 2n;

      const tx = await intellToken.setPrice(newPrice);
      await tx.wait();

      await verifyEvents(
        tx,
        intellToken,
        INTELLTOKEN_EVENTS.TOKEN_TO_USDC_UPDATED,
        [
          {
            rate: newPrice,
          },
        ]
      );
    });

    it("move to next stage with valid parameters", async function () {
      for await (const stage of [
        INTELLTOKEN_STAGES.PRIVATE_SALE,
        INTELLTOKEN_STAGES.PUBLIC_SALE,
        INTELLTOKEN_STAGES.FINISHED,
      ]) {
        const tx = await intellToken.moveToNextStage();
        await tx.wait();

        await verifyEvents(tx, intellToken, INTELLTOKEN_EVENTS.ENTERED_STAGE, [
          {
            stage: stage,
          },
        ]);
      }
    });

    it("pause and unpause with valid parameters", async function () {
      await intellToken.pause();

      let isPaused = await intellToken.paused();
      expect(isPaused).to.be.true;

      await intellToken.unpause();

      isPaused = await intellToken.paused();
      expect(isPaused).to.be.false;
    });

    it("distribute tokens with valid parameters", async function () {
      const recipient = user;
      const amount = 100000000000n;

      const previousRecipientIntellTokenBalance = await intellToken.balanceOf(
        recipient
      );

      const tx = await intellToken.distribute(recipient, amount);
      await tx.wait();

      await verifyEvents(
        tx,
        intellToken,
        INTELLTOKEN_EVENTS.TOKENS_DISTRIBUTED,
        [
          {
            recipient: recipient.address,
            amount: amount,
          },
        ]
      );

      const newRecipientIntellTokenBalance = await intellToken.balanceOf(
        recipient
      );

      expect(
        newRecipientIntellTokenBalance - previousRecipientIntellTokenBalance
      ).to.eq(amount);
    });
  });

  describe("should fail to", function () {
    it("set whitelist root with invalid parameters", async function () {
      const tree = StandardMerkleTree.of([[owner.address]], ["address"]);

      await expect(
        intellToken.connect(user).setWhitelistRoot(tree.root)
      ).to.be.revertedWithCustomError(
        intellToken,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("set price with invalid parameters", async function () {
      await expect(intellToken.setPrice(0n)).to.be.revertedWith(
        "invalid price"
      );

      await expect(
        intellToken.connect(user).setPrice(INTELLTOKEN_TO_USDC)
      ).to.be.revertedWithCustomError(
        intellToken,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("move to next stage with invalid parameters", async function () {
      await expect(intellToken.moveToNextStage()).to.be.revertedWith(
        "sales finished"
      );

      await expect(
        intellToken.connect(user).moveToNextStage()
      ).to.be.revertedWithCustomError(
        intellToken,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("pause and unpause with valid parameters", async function () {
      await expect(
        intellToken.connect(user).pause()
      ).to.be.revertedWithCustomError(
        intellToken,
        "AccessControlUnauthorizedAccount"
      );

      await expect(
        intellToken.connect(user).unpause()
      ).to.be.revertedWithCustomError(
        intellToken,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("distribute tokens with invalid parameters", async function () {
      const recipient = user;
      const amount = INTELLTOKEN_MAX_SUPPLY;

      await expect(
        intellToken.connect(user).distribute(recipient, amount)
      ).to.be.revertedWithCustomError(
        intellToken,
        "AccessControlUnauthorizedAccount"
      );

      await expect(
        intellToken.distribute(recipient, amount)
      ).to.be.revertedWith("exceeds maximum supply");
    });
  });
});
