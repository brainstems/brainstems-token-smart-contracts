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

    // merkle tree construction in order to whitelist 2 buyers
    const leaves = [];
    for (const buyer of [buyer1, buyer2]) {
      let address = buyer.address;
      leaves.push([address]);
    }

    whitelistTree = StandardMerkleTree.of(leaves, ["address"]);
    await brainstemsToken.setWhitelistRoot(whitelistTree.root);

    return { brainstemsToken, usdCoin };
  }

  describe("should be able to buy private tokens", function () {
    it("with valid parameters", async function () {
      const { brainstemsToken, usdCoin } = await loadFixture(setupFixture);

      // move to Private Sale
      await brainstemsToken.moveToNextStage();

      const whitelist = [
        { buyer: buyer1, proof: whitelistTree.getProof(0), amount: 150n },
        { buyer: buyer2, proof: whitelistTree.getProof(1), amount: 300n },
      ];

      for await (const entry of whitelist) {
        const buyer = entry.buyer;
        const proof = entry.proof;
        const amount = entry.amount;

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

        const tx = await brainstemsToken
          .connect(buyer)
          .buyWhitelistedTokens(amount, proof);
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
              stage: BRAINSTEMS_TOKEN_STAGES.PRIVATE_SALE,
            },
          ]
        );
      }
    });
  });

  describe("should fail to", function () {
    it("set whitelist root with invalid parameters", async function () {
      const { brainstemsToken } = await loadFixture(setupFixture);

      const buyer = buyer3;
      const tree = StandardMerkleTree.of([[buyer.address]], ["address"]);
      const root = tree.root;

      await expect(
        brainstemsToken.connect(buyer).setWhitelistRoot(root)
      ).to.be.revertedWithCustomError(
        brainstemsToken,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("buy private tokens during an invalid stage", async function () {
      const { brainstemsToken } = await loadFixture(setupFixture);
      const amount = 10n;
      const proof = whitelistTree.getProof(0);

      // Whitelisting
      await expect(
        brainstemsToken.connect(buyer1).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWith("invalid stage");

      // Public Sale
      await brainstemsToken.moveToNextStage();
      await brainstemsToken.moveToNextStage();
      await expect(
        brainstemsToken.connect(buyer1).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWith("invalid stage");

      // Finished
      await brainstemsToken.moveToNextStage();
      await expect(
        brainstemsToken.connect(buyer1).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWith("invalid stage");
    });

    it("buy private tokens with invalid parameters", async function () {
      const { brainstemsToken } = await loadFixture(setupFixture);

      const amount = 100n;
      const proof = whitelistTree.getProof(0);

      // move to Private Sale
      await brainstemsToken.moveToNextStage();

      await expect(
        brainstemsToken.connect(buyer1).buyWhitelistedTokens(0, proof)
      ).to.be.revertedWith("amount is 0");

      await brainstemsToken.pause();

      await expect(
        brainstemsToken.connect(buyer1).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWithCustomError(brainstemsToken, "EnforcedPause");

      await brainstemsToken.unpause();

      await expect(
        brainstemsToken.connect(buyer3).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWith("not whitelisted");

      const lockedAmount = BRAINSTEMS_TOKEN_SALES_CAP - amount + 1n;
      await brainstemsToken
        .connect(buyer2)
        .buyWhitelistedTokens(lockedAmount, whitelistTree.getProof(1));

      await expect(
        brainstemsToken.connect(buyer1).buyWhitelistedTokens(amount, proof)
      ).to.be.revertedWith("insufficient available tokens");

      await brainstemsToken.distribute(
        owner,
        BRAINSTEMS_TOKEN_MAX_SUPPLY - lockedAmount
      );

      await expect(
        brainstemsToken.connect(buyer1).buyWhitelistedTokens(1n, proof)
      ).to.be.revertedWith("exceeds maximum supply");
    });
  });
});
