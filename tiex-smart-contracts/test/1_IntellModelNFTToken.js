const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const crypto = require('crypto');
const { getHardhatPrivateKey, h2d } = require("./helper");
const deploy_config = require("../scripts/deploy_config");

describe("TIExShareCollections", () => {

  let deployer;
  let admin;
  let truthHolder;
  let recipient;
  let signer0;
  let signer1;
  let signer2;
  let models;
  let truthHolderPrivateKey;
  let tiexShareCollections;
  let intellToken;

  const i2b = i => ethers.BigNumber.from(i);

  before(async () => {
    [deployer, admin, truthHolder, recipient, signer0, signer1, signer2] = await ethers.getSigners();
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
        creator: signer0.address,
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        contributors: [],
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true
      },
      {
        modelId: 3,
        creator: signer0.address,
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        contributors: [],
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true
      },
      {
        modelId: 4,
        creator: signer0.address,
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        contributors: [],
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true
      },
      {
        modelId: 5,
        creator: signer0.address,
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        contributors: [],
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        forOnlyUSInvestors: true
      },
    ]

    await tiexShareCollections.initialize(truthHolder.address, intellToken.address, admin.address);

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

      expect(await tiexShareCollections.name()).to.eq(deploy_config.tiex_share_collection_name);
      expect(await tiexShareCollections.symbol()).to.eq(deploy_config.tiex_share_collection_symbol);
      expect(await tiexShareCollections.paymentToken()).to.eq(intellToken.address);
      expect(await tiexShareCollections.truthHolder()).to.eq(truthHolder.address);
      expect(await tiexShareCollections.hasRole(default_amdin_role, admin.address)).to.eq(true);
    });
  })

  describe("TIExBaseIPAllocation", async () => {
    beforeEach(async () => {
      await tiexShareCollections.connect(admin).giveCreatorTIExIP(
        models[0].modelId,
        models[0].creator,
        models[0].ipfsHash,
        models[0].contributors
      );
    })

    it("should give a creator TIExIP", async () => {
      const model_detail = await tiexShareCollections.getModelDetail(models[0].modelId);

      expect(await tiexShareCollections.creatorOf(models[0].modelId)).to.eq(models[0].creator);
      expect(await model_detail[0]).to.eq(models[0].creator);
      expect(await model_detail[1]).to.eq(models[0].ipfsHash);
      models[0].contributors.map(async (c, i) => {
        expect(await model_detail[2][i][0]).to.eq(ethers.BigNumber.from(models[0].contributors[i][0]));
        expect(await model_detail[2][i][1]).to.eq(ethers.BigNumber.from(models[0].contributors[i][1]));
      })
    })


  })

  describe("TIExShareCollection", async () => {
    before(async () => {
      await tiexShareCollections.connect(admin).releaseShareCollection(
        models[0].maxSupply,
        models[0].modelId,
        models[0].price,
        models[0].maxSharePurchase,
        models[0].forOnlyUSInvestors
      )

      await tiexShareCollections.connect(admin).setUnpause(models[0].modelId);
    })

    it("should release new share collection", async () => {
      const shareCollection = await tiexShareCollections.shareCollection(models[0].modelId);

      expect(shareCollection[0][0]).to.eq(ethers.BigNumber.from(models[0].maxSupply));
      expect(shareCollection[0][3]).to.eq(models[0].price);
      expect(shareCollection[0][5]).to.eq(ethers.BigNumber.from(models[0].maxSharePurchase));
      expect(shareCollection[0][8]).to.eq(models[0].forOnlyUSInvestors);
      expect(await tiexShareCollections.shareCollectionExists(models[0].modelId)).to.eq(true);

    })

    it("should buy shares with INTELL tokens", async () => {
      const provider = ethers.getDefaultProvider();
      const truthHolderSigner = new ethers.Wallet(truthHolderPrivateKey, provider);
      const nonce = h2d(crypto.randomBytes(8).toString("hex"));

      const payload = ethers.utils.defaultAbiCoder.encode(
        ["address", "bool", "bool", "address", "uint256"],
        [signer0.address,
          true,
          true,
        tiexShareCollections.address,
          nonce
        ]);
      const payloadHash = ethers.utils.keccak256(payload);
      const signature = await truthHolderSigner.signMessage(ethers.utils.arrayify(payloadHash));
      const shares = i2b(1000);
      
      const intellBalanceOfSigner0Before = await intellToken.balanceOf(signer0.address);
      const shareBalanceOfSigner0Before = await tiexShareCollections.balanceOf(signer0.address, models[0].modelId);
      const intellBalanceOfTiexShareContractBefore = await intellToken.balanceOf(tiexShareCollections.address);

      await intellToken.connect(signer0).approve(tiexShareCollections.address, ethers.constants.MaxUint256);
      await tiexShareCollections.connect(signer0).buyShares(models[0].modelId, shares, nonce, true, signature);
      
      expect(intellBalanceOfSigner0Before.sub(shares.mul(models[0].price))).to.eq(await intellToken.balanceOf(signer0.address));
      expect(shareBalanceOfSigner0Before.add(shares)).to.eq(await tiexShareCollections.balanceOf(signer0.address, models[0].modelId));
      expect(intellBalanceOfTiexShareContractBefore.add(shares.mul(models[0].price))).to.eq(await intellToken.balanceOf(tiexShareCollections.address));

    })

    it("Should transfer shares between accounts", async () => {
      const shareBalanceOfSigner0Before = await tiexShareCollections.balanceOf(signer0.address, models[0].modelId);
      const shareBalanceOfSigner1Before = await tiexShareCollections.balanceOf(signer1.address, models[0].modelId);
      const toSendShares = i2b(10);

      await tiexShareCollections.connect(signer0).safeTransferFrom(signer0.address, signer1.address, models[0].modelId, 10, "0x");

      const shareBalanceOfSigner0After = await tiexShareCollections.balanceOf(signer0.address, models[0].modelId);
      const shareBalanceOfSigner1After = await tiexShareCollections.balanceOf(signer1.address, models[0].modelId);

      expect(shareBalanceOfSigner0Before.sub(toSendShares)).to.eq(shareBalanceOfSigner0After);
      expect(shareBalanceOfSigner1Before.add(toSendShares)).to.eq(shareBalanceOfSigner1After);

    })

  })

})