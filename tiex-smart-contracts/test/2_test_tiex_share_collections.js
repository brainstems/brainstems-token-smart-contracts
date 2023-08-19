const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const crypto = require('crypto');
const { getHardhatPrivateKey, h2d } = require("./helper");
const { creator_rate, tiex_share_collection_name, tiex_share_collection_symbol, marketing_rate, reserve_rate, presale_rate } = require("../scripts/deploy_config");

describe("TIExShareCollections", () => {

  let deployer;
  let admin;
  let truthHolder;
  let recipient;
  let signer0;
  let signer1;
  let signer2;
  let reserve;
  let presale;
  let marketing;
  let models;
  let truthHolderPrivateKey;
  let tiexShareCollections;
  let intellToken;

  const i2b = i => ethers.BigNumber.from(i);

  before(async () => {
    [deployer, admin, truthHolder, recipient, signer0, signer1, signer2, reserve, presale, marketing] = await ethers.getSigners();
    truthHolderPrivateKey = getHardhatPrivateKey(2);
    intellToken = await ethers.deployContract("IntelligenceInvestmentToken", [recipient.address]);
    tiexShareCollections = await ethers.deployContract("TIExShareCollections");
    models = [
      {
        modelId: 1,
        creator: signer0.address,
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        contributors: [[1, 10000]],
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true
      },
      {
        modelId: 2,
        creator: signer1.address,
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        contributors: [[1, 5000], [2, 5000]],
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true
      },
      {
        modelId: 3,
        creator: signer2.address,
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        contributors: [[1, 5000], [2, 3000], [3, 2000]],
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true
      },
      {
        modelId: 4,
        creator: signer0.address,
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        contributors: [[1, 1000], [2, 3000], [4, 6000]],
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true
      },
      {
        modelId: 5,
        creator: signer1.address,
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        contributors: [[1, 1000], [2, 3000], [5, 5000], [4, 1000]],
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true
      },
    ]

    await tiexShareCollections.initialize(truthHolder.address, intellToken.address, admin.address, [creator_rate, marketing_rate, reserve_rate, presale_rate, marketing.address, reserve.address, presale.address]);

    const toSend = ethers.utils.parseEther("100000000");
    await intellToken.connect(recipient).transfer(signer0.address, toSend);
    await intellToken.connect(recipient).transfer(signer1.address, toSend);
    await intellToken.connect(recipient).transfer(signer2.address, toSend);

  })

  describe("Deployment", function () {
    it("Should deploy TIExShareCollections", async () => {
      expect(tiexShareCollections.address).to.exist;
    })

    it("Should set right symbol and name, payment token, truth holder, admin role.", async function () {
      const default_amdin_role = await tiexShareCollections.DEFAULT_ADMIN_ROLE();
      const investmentDistribution = await tiexShareCollections.investmentDistribution();

      expect(investmentDistribution[0]).to.eq(i2b(creator_rate));
      expect(investmentDistribution[1]).to.eq(i2b(marketing_rate));
      expect(investmentDistribution[2]).to.eq(i2b(reserve_rate));
      expect(investmentDistribution[3]).to.eq(i2b(presale_rate));
      expect(investmentDistribution[4]).to.eq(marketing.address);
      expect(investmentDistribution[5]).to.eq(reserve.address);
      expect(investmentDistribution[6]).to.eq(presale.address);

      expect(await tiexShareCollections.name()).to.eq(tiex_share_collection_name);
      expect(await tiexShareCollections.symbol()).to.eq(tiex_share_collection_symbol);
      expect(await tiexShareCollections.paymentToken()).to.eq(intellToken.address);
      expect(await tiexShareCollections.truthHolder()).to.eq(truthHolder.address);
      expect(await tiexShareCollections.hasRole(default_amdin_role, admin.address)).to.eq(true);

    });
  })

  describe("TIExBaseIPAllocation", async () => {
    before(async () => {
      for (var i = 0; i < models.length; i++) {
        await tiexShareCollections.connect(admin).giveCreatorTIExIP(
          models[i].modelId,
          models[i].creator,
          models[i].ipfsHash,
          models[i].contributors
        );
      }
    })

    it("should give a creator TIExIP", async () => {
      for (var i = 0; i < models.length; i++) {
        const model_detail = await tiexShareCollections.getModelDetail(models[i].modelId);

        expect(await tiexShareCollections.creatorOf(models[i].modelId)).to.eq(models[i].creator);
        expect(await model_detail[0]).to.eq(models[i].creator);
        expect(await model_detail[1]).to.eq(models[i].ipfsHash);

        for(var j = 0; j < models[i].contributors.length; j++) {
          expect(await model_detail[2][j][0]).to.eq(ethers.BigNumber.from(models[i].contributors[j][0]));
          expect(await model_detail[2][j][1]).to.eq(ethers.BigNumber.from(models[i].contributors[j][1]));
        }
      }
    })


  })

  describe("TIExShareCollection", async () => {

    it("should release new share collection", async () => {

      for (var i = 0; i < models.length; i++) {
        await tiexShareCollections.connect(admin).releaseShareCollection(
          models[i].maxSupply,
          models[i].modelId,
          models[i].price,
          models[i].maxSharePurchase,
          models[i].forOnlyUSInvestors
        )

        await tiexShareCollections.connect(admin).setUnpause(models[i].modelId);


        const shareCollection = await tiexShareCollections.shareCollection(models[i].modelId);

        expect(shareCollection[0][0]).to.eq(ethers.BigNumber.from(models[i].maxSupply));
        expect(shareCollection[0][3]).to.eq(models[i].price);
        expect(shareCollection[0][5]).to.eq(ethers.BigNumber.from(models[i].maxSharePurchase));
        expect(shareCollection[0][8]).to.eq(models[i].forOnlyUSInvestors);
        expect(await tiexShareCollections.shareCollectionExists(models[i].modelId)).to.eq(true);

      }
    })

    it("should buy shares with INTELL tokens", async () => {
      const provider = ethers.getDefaultProvider();
      const truthHolderSigner = new ethers.Wallet(truthHolderPrivateKey, provider);

      for (var i = 0; i < models.length; i++) {
        const nonce = h2d(crypto.randomBytes(8).toString("hex"));

        const payload = ethers.utils.defaultAbiCoder.encode(
          ["address", "bool", "address", "uint256"],
          [signer0.address,
            true,
          tiexShareCollections.address,
            nonce
          ]);
        const payloadHash = ethers.utils.keccak256(payload);
        const signature = await truthHolderSigner.signMessage(ethers.utils.arrayify(payloadHash));
        const shares = i2b(1000);

        const intellBalanceOfSigner0Before = await intellToken.balanceOf(signer0.address);
        const shareBalanceOfSigner0Before = await tiexShareCollections.balanceOf(signer0.address, models[i].modelId);
        const intellBalanceOfTiexShareContractBefore = await intellToken.balanceOf(tiexShareCollections.address);
        const shareCollectionBefore = await tiexShareCollections.shareCollection(models[i].modelId);

        await intellToken.connect(signer0).approve(tiexShareCollections.address, ethers.constants.MaxUint256);

        await tiexShareCollections.connect(admin).emergency();
        await expect(tiexShareCollections.connect(signer0).buyShares(models[i].modelId, shares, nonce, true, signature)).to.be.reverted;
        await tiexShareCollections.connect(admin).resume();

        await tiexShareCollections.connect(admin).setBlock(models[i].modelId);
        await expect(tiexShareCollections.connect(signer0).buyShares(models[i].modelId, shares, nonce, true, signature)).to.be.reverted;
        await tiexShareCollections.connect(admin).setUnblock(models[i].modelId);

        await tiexShareCollections.connect(admin).setPause(models[i].modelId);
        await expect(tiexShareCollections.connect(signer0).buyShares(models[i].modelId, shares, nonce, true, signature)).to.be.reverted;
        await tiexShareCollections.connect(admin).setUnpause(models[i].modelId);


        await tiexShareCollections.connect(signer0).buyShares(models[i].modelId, shares, nonce, true, signature);


        const intellBalanceOfSigner0After = await intellToken.balanceOf(signer0.address);
        const shareBalanceOfSigner0After = await tiexShareCollections.balanceOf(signer0.address, models[i].modelId);
        const intellBalanceOfTiexShareContractAfter = await intellToken.balanceOf(tiexShareCollections.address);
        const shareCollectionAfter = await tiexShareCollections.shareCollection(models[i].modelId);

        expect(intellBalanceOfSigner0Before.sub(shares.mul(models[i].price))).to.eq(intellBalanceOfSigner0After);
        expect(shareBalanceOfSigner0Before.add(shares)).to.eq(shareBalanceOfSigner0After);
        expect(intellBalanceOfTiexShareContractBefore.add(shares.mul(models[i].price))).to.eq(intellBalanceOfTiexShareContractAfter);
        expect(shareCollectionBefore[0][1].add(shares.mul(models[i].price))).to.eq(shareCollectionAfter[0][1]);

        await expect(tiexShareCollections.connect(signer0).buyShares(models[i].modelId, shares, nonce, true, signature)).to.be.reverted;
      }
    })

    it("Should transfer shares between accounts", async () => {
      for (var i = 0; i < models.length; i++) {
        const shareBalanceOfSigner0Before = await tiexShareCollections.balanceOf(signer0.address, models[i].modelId);
        const shareBalanceOfSigner1Before = await tiexShareCollections.balanceOf(signer1.address, models[i].modelId);
        const toSendShares = i2b(10);

        await tiexShareCollections.connect(signer0).safeTransferFrom(signer0.address, signer1.address, models[i].modelId, toSendShares, "0x");

        const shareBalanceOfSigner0After = await tiexShareCollections.balanceOf(signer0.address, models[i].modelId);
        const shareBalanceOfSigner1After = await tiexShareCollections.balanceOf(signer1.address, models[i].modelId);

        expect(shareBalanceOfSigner0Before.sub(toSendShares)).to.eq(shareBalanceOfSigner0After);
        expect(shareBalanceOfSigner1Before.add(toSendShares)).to.eq(shareBalanceOfSigner1After);

        await tiexShareCollections.connect(admin).emergency();
        await expect(tiexShareCollections.connect(signer0).safeTransferFrom(signer0.address, signer1.address, models[i].modelId, toSendShares, "0x")).to.be.reverted;

        await tiexShareCollections.connect(admin).resume();
        await tiexShareCollections.connect(signer0).safeTransferFrom(signer0.address, signer1.address, models[i].modelId, toSendShares, "0x");

        await tiexShareCollections.connect(admin).setBlock(models[i].modelId);
        await expect(tiexShareCollections.connect(signer0).safeTransferFrom(signer0.address, signer1.address, models[i].modelId, toSendShares, "0x")).to.be.reverted;

        await tiexShareCollections.connect(admin).setUnblock(models[i].modelId);
        await tiexShareCollections.connect(signer0).safeTransferFrom(signer0.address, signer1.address, models[i].modelId, toSendShares, "0x");

      }
    })

    it("Should distriibute the funds from investor to creators, marketing, reserve, and presale", async () => {

    })

    it("Should burn shasres to zero address", async () => {
      for (var i = 0; i < models.length; i++) {
        const toBurn = i2b(10);

        const shareBalanceOfSigner0Before = await tiexShareCollections.balanceOf(signer0.address, models[i].modelId);

        await tiexShareCollections.connect(signer0).burn(signer0.address, models[i].modelId, toBurn);

        const shareBalanceOfSigner0After = await tiexShareCollections.balanceOf(signer0.address, models[i].modelId);

        expect(shareBalanceOfSigner0Before.sub(toBurn)).to.eq(shareBalanceOfSigner0After);

        await tiexShareCollections.connect(admin).emergency();
        await tiexShareCollections.connect(signer0).burn(signer0.address, models[i].modelId, toBurn);
        await tiexShareCollections.connect(admin).resume();

        await tiexShareCollections.connect(admin).setBlock(models[i].modelId);
        await tiexShareCollections.connect(signer0).burn(signer0.address, models[i].modelId, toBurn);
        await tiexShareCollections.connect(admin).setUnblock(models[i].modelId);

        await tiexShareCollections.connect(admin).setPause(models[i].modelId);
        await tiexShareCollections.connect(signer0).burn(signer0.address, models[i].modelId, toBurn);
        await tiexShareCollections.connect(admin).setUnpause(models[i].modelId);
      }
    })

  })

})