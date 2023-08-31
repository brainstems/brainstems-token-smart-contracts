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
  let tiexShareCollections;
  let intellToken;

  const i2b = i => ethers.BigNumber.from(i);
  const generateSignatureForPermit = async (_owner, _other, _required) => {
    const allowance  = await intellToken.allowance(_owner.address, _other.address);
      if(_required <= allowance) return "0x";
      const nonce = await intellToken.nonces(_owner.address);
      const amount = ethers.constants.MaxUint256;
      const SECOND = 1000;
      const deadline = Math.trunc((Date.now() + 1200 * SECOND) / SECOND);
      const domain = {
        name: "Intelligence Investment Token",
        version: "1",
        chainId: 1337,
        verifyingContract: intellToken.address
      };

      // The named list of all type definitions
      const types = {
        Permit: [
          {
            name: "owner",
            type: "address",
          },
          {
            name: "spender",
            type: "address",
          },
          {
            name: "value",
            type: "uint256",
          },
          {
            name: "nonce",
            type: "uint256",
          },
          {
            name: "deadline",
            type: "uint256",
          },
        ],
      };


      // The data to sign
      const value = {
        owner: _owner.address,
        spender: _other.address,
        value: amount,
        nonce,
        deadline,
      };

      const signature = await _owner._signTypedData(domain, types, value);
      let sig = ethers.utils.splitSignature(signature);

      const verifiedAddress = ethers.utils.verifyTypedData(domain, {
        Permit: types.Permit
      }, value, signature);

      expect(verifiedAddress).to.eq(_owner.address);

      const permitMessage = ethers.utils.defaultAbiCoder.encode(["uint8", "bytes32", "bytes32", "uint256"], [sig.v, sig.r, sig.s, deadline]);
      return permitMessage;

  };

  before(async () => {
    [deployer, admin, truthHolder, recipient, signer0, signer1, signer2, reserve, presale, marketing] = await ethers.getSigners();
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

        for (var j = 0; j < models[i].contributors.length; j++) {
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
        const signature = await truthHolder.signMessage(ethers.utils.arrayify(payloadHash));
        // let sig = ethers.utils.splitSignature(signature);
        // console.log(
        //   sig.v, sig.r, sig.s
        // );
        const shares = i2b(1000);
        const paymentAmount = shares.mul(models[i].price);

        const intellBalanceOfSigner0Before = await intellToken.balanceOf(signer0.address);
        const shareBalanceOfSigner0Before = await tiexShareCollections.balanceOf(signer0.address, models[i].modelId);
        const intellBalanceOfTiexShareContractBefore = await intellToken.balanceOf(tiexShareCollections.address);
        const shareCollectionBefore = await tiexShareCollections.shareCollection(models[i].modelId);

        await tiexShareCollections.connect(admin).emergency();
        let permitMessage =  await generateSignatureForPermit(signer0, tiexShareCollections, paymentAmount);
        

        await expect(tiexShareCollections.connect(signer0).buyShares(models[i].modelId, shares, nonce, true, signature, permitMessage)).to.be.reverted;
        await tiexShareCollections.connect(admin).resume();


        await tiexShareCollections.connect(admin).setBlock(models[i].modelId);
        permitMessage =  await generateSignatureForPermit(signer0, tiexShareCollections, paymentAmount);
        

        await expect(tiexShareCollections.connect(signer0).buyShares(models[i].modelId, shares, nonce, true, signature, permitMessage)).to.be.reverted;
        await tiexShareCollections.connect(admin).setUnblock(models[i].modelId);

        await tiexShareCollections.connect(admin).setPause(models[i].modelId);
        permitMessage =  await generateSignatureForPermit(signer0, tiexShareCollections, paymentAmount);
        
        await expect(tiexShareCollections.connect(signer0).buyShares(models[i].modelId, shares, nonce, true, signature, permitMessage)).to.be.reverted;
        await tiexShareCollections.connect(admin).setUnpause(models[i].modelId);

        permitMessage =  await generateSignatureForPermit(signer0, tiexShareCollections, paymentAmount);
        
        await tiexShareCollections.connect(signer0).buyShares(models[i].modelId, shares, nonce, true, signature, permitMessage);

        const intellBalanceOfSigner0After = await intellToken.balanceOf(signer0.address);
        const shareBalanceOfSigner0After = await tiexShareCollections.balanceOf(signer0.address, models[i].modelId);
        const intellBalanceOfTiexShareContractAfter = await intellToken.balanceOf(tiexShareCollections.address);
        const shareCollectionAfter = await tiexShareCollections.shareCollection(models[i].modelId);

        expect(intellBalanceOfSigner0Before.sub(paymentAmount)).to.eq(intellBalanceOfSigner0After);
        expect(shareBalanceOfSigner0Before.add(shares)).to.eq(shareBalanceOfSigner0After);
        expect(intellBalanceOfTiexShareContractBefore.add(paymentAmount)).to.eq(intellBalanceOfTiexShareContractAfter);
        expect(shareCollectionBefore[0][1].add(paymentAmount)).to.eq(shareCollectionAfter[0][1]);

        permitMessage =  await generateSignatureForPermit(signer0, tiexShareCollections, paymentAmount);
        
        await expect(tiexShareCollections.connect(signer0).buyShares(models[i].modelId, shares, nonce, true, signature, permitMessage)).to.be.reverted;
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
      for (var i = 0; i < models.length; i++) {
        const marketingBefore = await intellToken.balanceOf(marketing.address);
        const reserveBefore = await intellToken.balanceOf(reserve.address);
        const presaleBefore = await intellToken.balanceOf(presale.address);
        const shareCollectionBefore = await tiexShareCollections.shareCollection(models[i].modelId);

        const restOfAmount = shareCollectionBefore[0][1].sub(shareCollectionBefore[0][2]);
        const toCreators = restOfAmount.mul(creator_rate);
        const toMarketing = restOfAmount.mul(marketing_rate);
        const toPresale = restOfAmount.mul(presale_rate);
        const toReserve = restOfAmount.mul(reserve_rate);
        const creators = [];
        const toEachCreator = {};

        for (var j = 0; j < models[i].contributors.length; j++) {
          const contributor = models[i].contributors[j];
          const creator = await tiexShareCollections.creatorOf(contributor[0]);
          const balanceOfCreatorBefore = await intellToken.balanceOf(creator);
          if (toEachCreator[creator] == undefined) toEachCreator[creator] = i2b(0);
          toEachCreator[creator] = toEachCreator[creator].add(toCreators.mul(contributor[1]).div(10000_0000));
          creators.push({
            creator,
            balanceOfCreatorBefore,
          });
        }

        await tiexShareCollections.connect(admin).distribute(models[i].modelId);

        const marketingAfter = await intellToken.balanceOf(marketing.address);
        const reserveAfter = await intellToken.balanceOf(reserve.address);
        const presaleAfter = await intellToken.balanceOf(presale.address);
        const shareCollectionAfter = await tiexShareCollections.shareCollection(models[i].modelId);

        for (var j = 0; j < models[i].contributors.length; j++) {
          const balanceOfCreatorAfter = await intellToken.balanceOf(creators[j].creator);
          expect(creators[j].balanceOfCreatorBefore.add(toEachCreator[creators[j].creator])).to.eq(balanceOfCreatorAfter);
        }

        expect(marketingBefore.add(toMarketing.div(10000))).to.eq(marketingAfter);
        expect(reserveBefore.add(toReserve.div(10000))).to.eq(reserveAfter);
        expect(presaleBefore.add(toPresale.div(10000))).to.eq(presaleAfter);
        expect(shareCollectionAfter[0][1]).to.eq(shareCollectionAfter[0][2]);

        await expect(tiexShareCollections.distribute(models[i].modelId)).to.be.reverted;

      }
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