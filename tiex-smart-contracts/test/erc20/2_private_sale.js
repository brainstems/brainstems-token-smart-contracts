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
} = require("../consts");
const { verifyEvents } = require("../utils");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");

let owner, buyer1, buyer2, buyer3, whitelistTree;

describe("ERC20: Private Sale", function () {
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

    // merkle tree construction in order to whitelist 2 buyers
    const leaves = [];
    for (const buyer of [buyer1, buyer2]) {
      let address = buyer.address;
      leaves.push([address]);
    }

    whitelistTree = StandardMerkleTree.of(leaves, ["address"]);
    await intellToken.setWhitelistRoot(whitelistTree.root);

    return { intellToken, usdCoin };
  }

  describe("should be able to buy private tokens", function () {
    it("with valid parameters", async function () {
      const { intellToken, usdCoin } = await loadFixture(setupFixture);

      // move to Private Sale
      await intellToken.moveToNextStage();

      const whitelist = [
        { buyer: buyer1, proof: whitelistTree.getProof(0), amount: 150n },
        { buyer: buyer2, proof: whitelistTree.getProof(1), amount: 300n },
      ];

      for await (const entry of whitelist) {
        const buyer = entry.buyer;
        const proof = entry.proof;
        const amount = entry.amount;

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

        const tx = await intellToken
          .connect(buyer)
          .buyWhitelistedTokens(amount, proof);
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
              stage: INTELLTOKEN_STAGES.PRIVATE_SALE,
            },
          ]
        );
      }
    });
  });

  describe("should fail to", function () {
    it("set whitelist root with invalid parameters", async function () {
      const { intellToken } = await loadFixture(setupFixture);

      const buyer = buyer3;
      const tree = StandardMerkleTree.of([[buyer.address]], ["address"]);
      const root = tree.root;

      await expect(
        intellToken.connect(buyer).setWhitelistRoot(root)
      ).to.be.revertedWithCustomError(
        intellToken,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("buy private tokens during an invalid stage", async function () {
      const { intellToken } = await loadFixture(setupFixture);
      const amount = 10n;
      const proof = whitelistTree.getProof(0);

      // Whitelisting
      await expect(
        intellToken.connect(buyer1).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWith("invalid stage");

      // Public Sale
      await intellToken.moveToNextStage();
      await intellToken.moveToNextStage();
      await expect(
        intellToken.connect(buyer1).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWith("invalid stage");

      // Finished
      await intellToken.moveToNextStage();
      await expect(
        intellToken.connect(buyer1).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWith("invalid stage");
    });

    it("buy private tokens with invalid parameters", async function () {
      const { intellToken } = await loadFixture(setupFixture);

      const amount = 100n;
      const proof = whitelistTree.getProof(0);

      // move to Private Sale
      await intellToken.moveToNextStage();

      await expect(
        intellToken.connect(buyer1).buyWhitelistedTokens(0, proof)
      ).to.be.revertedWith("amount is 0");

      await intellToken.pause();

      await expect(
        intellToken.connect(buyer1).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWithCustomError(intellToken, "EnforcedPause");

      await intellToken.unpause();

      await expect(
        intellToken.connect(buyer3).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWith("not whitelisted");

      const lockedAmount = INTELLTOKEN_SALES_CAP - amount + 1n;
      await intellToken
        .connect(buyer2)
        .buyWhitelistedTokens(lockedAmount, whitelistTree.getProof(1));

      await expect(
        intellToken.connect(buyer1).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWith("insufficient available tokens");

      await intellToken.distribute(
        owner,
        INTELLTOKEN_MAX_SUPPLY - lockedAmount
      );

      await expect(
        intellToken.connect(buyer1).buyWhitelistedTokens(1n, proof)
      ).to.be.revertedWith("exceeds maximum supply");
    });
  });
});
