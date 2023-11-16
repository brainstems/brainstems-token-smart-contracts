const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  creator_rate,
  marketing_rate,
  reserve_rate,
  presale_rate,
} = require("../scripts/deploy_config");
// TODO: revise unused variables
describe("TIExShareCollections", () => {
  let deployer;
  let admin;
  let recipient;
  let signer0;
  let signer1;
  let signer2;
  let reserve;
  let presale;
  let marketing;
  let models;
  let tiexShareCollections;
  let tiexBaseIPAllocation;
  let intellToken;
  let utility;

  const i2b = (i) => ethers.BigNumber.from(i);
  const generateSignatureForPermit = async (_owner, _other, _required) => {
    const allowance = await intellToken.allowance(
      _owner.address,
      _other.address
    );
    if (_required <= allowance) return "0x";
    const nonce = await intellToken.nonces(_owner.address);
    const amount = ethers.constants.MaxUint256;
    const SECOND = 1000;
    const deadline = Math.trunc((Date.now() + 1200 * SECOND) / SECOND);
    const domain = {
      name: "Intelligence Investment Token",
      version: "1",
      chainId: 1337,
      verifyingContract: intellToken.address,
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

    const verifiedAddress = ethers.utils.verifyTypedData(
      domain,
      {
        Permit: types.Permit,
      },
      value,
      signature
    );

    expect(verifiedAddress).to.eq(_owner.address);

    const permitMessage = ethers.utils.defaultAbiCoder.encode(
      ["uint8", "bytes32", "bytes32", "uint256"],
      [sig.v, sig.r, sig.s, deadline]
    );
    return permitMessage;
  };

  before(async () => {
    [
      deployer,
      admin,
      recipient,
      signer0,
      signer1,
      signer2,
      reserve,
      presale,
      marketing,
    ] = await ethers.getSigners();

    utility = await ethers.deployContract("Utility");
    intellToken = await ethers.deployContract("IntelligenceToken", [
      recipient.address,
    ]);
    tiexBaseIPAllocation = await ethers.deployContract("Assets");
    tiexShareCollections = await ethers.deployContract("AssetsRevenue");

    models = [
      {
        modelId: 1,
        contributors: {
          creator: signer0.address,
          marketing: ethers.constants.AddressZero,
          presale: ethers.constants.AddressZero,
          creatorRate: 10000,
          marketingRate: 0,
          presaleRate: 0,
        },
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true,
        metadata: [
          "Predictive Maintenance of Kitchen Equipment",
          1,
          "An AI model can be trained to predict when kitchen equipment is likely to break or underperform, allowing for timely maintenance and reduced downtime.",
          "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          false,
          "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          98,
        ],
      },
      {
        modelId: 2,
        contributors: {
          creator: signer1.address,
          marketing: ethers.constants.AddressZero,
          presale: ethers.constants.AddressZero,
          creatorRate: 10000,
          marketingRate: 0,
          presaleRate: 0,
        },
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true,
        metadata: [
          "Food Safety Monitoring",
          1,
          "AI algorithms can be used to monitor various food safety parameters, such as temperature, humidity, and food handling practices, in real-time. This can help prevent foodborne illnesses and maintain overall food safety.",
          "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          false,
          "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          98,
        ],
      },
      {
        modelId: 3,
        contributors: {
          creator: signer2.address,
          marketing: ethers.constants.AddressZero,
          presale: ethers.constants.AddressZero,
          creatorRate: 10000,
          marketingRate: 0,
          presaleRate: 0,
        },
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true,
        metadata: [
          "Recipe Optimization",
          1,
          "An AI algorithm can be trained to optimize recipes based on customer preferences, health considerations, and other factors. This can help restaurants and food producers create more successful and profitable products.",
          "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          false,
          "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          98,
        ],
      },
      {
        modelId: 4,
        contributors: {
          creator: signer0.address,
          marketing: ethers.constants.AddressZero,
          presale: ethers.constants.AddressZero,
          creatorRate: 10000,
          marketingRate: 0,
          presaleRate: 0,
        },
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true,
        metadata: [
          "Personalized Menu Recommendations",
          1,
          "An AI system can analyze a customer's order history and other personal data to provide personalized menu recommendations. This can improve customer satisfaction and drive menu innovation.",
          "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          false,
          "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          98,
        ],
      },
      {
        modelId: 5,
        contributors: {
          creator: signer1.address,
          marketing: ethers.constants.AddressZero,
          presale: ethers.constants.AddressZero,
          creatorRate: 10000,
          marketingRate: 0,
          presaleRate: 0,
        },
        ipfsHash: "QmSnuWmxptJZdLJpKRarxBMS2Ju2oANVrgbr2xWbie9b2D",
        maxSupply: i2b(100000),
        price: ethers.utils.parseEther("1000"),
        maxSharePurchase: i2b(1000),
        forOnlyUSInvestors: true,
        metadata: [
          "Waste Reduction",
          1,
          "An AI model can be trained to predict food waste based on various factors, such as customer demand and inventory levels. This can help restaurants and food retailers reduce waste and minimize losses due to expiration.",
          "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          false,
          "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          98,
        ],
      },
    ];

    await tiexBaseIPAllocation.initialize(
      admin.address,
      tiexShareCollections.address
    );
    await tiexShareCollections.initialize(
      intellToken.address,
      admin.address,
      utility.address,
      tiexBaseIPAllocation.address
    );

    const toSend = ethers.utils.parseEther("100000000");
    await intellToken.connect(recipient).transfer(signer0.address, toSend);
    await intellToken.connect(recipient).transfer(signer1.address, toSend);
    await intellToken.connect(recipient).transfer(signer2.address, toSend);
  });

  describe("Deployment", function () {
    it("Should deploy TIExShareCollections", async () => {
      expect(tiexShareCollections.address).to.exist;
    });

    it("Should deploy TIExBaseIPAllocatioin", async () => {
      expect(tiexBaseIPAllocation.address).to.exist;
    });

    it("Should deploy Utility", async () => {
      expect(utility.address).to.exist;
    });

    it("Should set right symbol and name, payment token, admin role, tiexBaseIPAllocation in TIExShareCollections", async function () {
      const default_amdin_role =
        await tiexShareCollections.DEFAULT_ADMIN_ROLE();

      expect(await tiexShareCollections.paymentToken()).to.eq(
        intellToken.address
      );
      expect(await tiexShareCollections.assetsContract()).to.eq(
        tiexBaseIPAllocation.address
      );
      expect(
        await tiexShareCollections.hasRole(default_amdin_role, admin.address)
      ).to.eq(true);
    });

    it("Should set right tiexShareCollection, admin role in TIExBaseIPAllocation", async function () {
      const default_amdin_role =
        await tiexBaseIPAllocation.DEFAULT_ADMIN_ROLE();

      expect(await tiexBaseIPAllocation.assetsRevenue()).to.eq(
        tiexShareCollections.address
      );
      expect(
        await tiexBaseIPAllocation.hasRole(default_amdin_role, admin.address)
      ).to.eq(true);
    });
  });

  describe("TIExBaseIPAllocation", async () => {
    before(async () => {
      for (var i = 0; i < models.length; i++) {
        await tiexBaseIPAllocation
          .connect(admin)
          .createAsset(
            models[i].modelId,
            models[i].contributors,
            models[i].ipfsHash,
            models[i].metadata
          );
      }
    });

    it("should give a creator TIExIP", async () => {
      for (var i = 0; i < models.length; i++) {
        const model_detail = await tiexBaseIPAllocation.getAsset(
          models[i].modelId
        );

        expect(await tiexBaseIPAllocation.creatorOf(models[i].modelId)).to.eq(
          models[i].contributors.creator
        );
        expect(await model_detail.contributors.creator).to.eq(
          models[i].contributors.creator
        );
        expect(await model_detail.uri).to.eq(models[i].ipfsHash);

        for (var ii = 0; ii < 9; ii++) {
          expect(model_detail.metadata[ii]).to.eq(models[i].metadata[ii]);
        }
      }
    });
  });

  describe("TIExShareCollection", async () => {
    it.skip("Should distribute the funds from investor to creators, marketing, reserve, and presale", async () => {
      for (var i = 0; i < models.length; i++) {
        const marketingBefore = await intellToken.balanceOf(marketing.address);
        const reserveBefore = await intellToken.balanceOf(reserve.address);
        const presaleBefore = await intellToken.balanceOf(presale.address);
        const shareCollectionBefore =
          await tiexShareCollections.shareCollection(models[i].modelId);

        const restOfAmount = shareCollectionBefore[0][1].sub(
          shareCollectionBefore[0][2]
        );
        const toCreators = restOfAmount.mul(creator_rate);
        const toMarketing = restOfAmount.mul(marketing_rate);
        const toPresale = restOfAmount.mul(presale_rate);
        const toReserve = restOfAmount.mul(reserve_rate);
        const creators = [];
        const toEachCreator = {};

        for (var j = 0; j < models[i].contributors.length; j++) {
          const contributor = models[i].contributors[j];
          const creator = await tiexBaseIPAllocation.creatorOf(contributor[0]);
          const balanceOfCreatorBefore = await intellToken.balanceOf(creator);
          if (toEachCreator[creator] == undefined)
            toEachCreator[creator] = i2b(0);
          toEachCreator[creator] = toEachCreator[creator].add(
            toCreators.mul(contributor[1]).div(10000_0000)
          );
          creators.push({
            creator,
            balanceOfCreatorBefore,
          });
        }

        await tiexShareCollections.connect(admin).distribute(models[i].modelId);

        const marketingAfter = await intellToken.balanceOf(marketing.address);
        const reserveAfter = await intellToken.balanceOf(reserve.address);
        const presaleAfter = await intellToken.balanceOf(presale.address);
        const shareCollectionAfter = await tiexShareCollections.shareCollection(
          models[i].modelId
        );

        for (var j = 0; j < models[i].contributors.length; j++) {
          const balanceOfCreatorAfter = await intellToken.balanceOf(
            creators[j].creator
          );
          expect(
            creators[j].balanceOfCreatorBefore.add(
              toEachCreator[creators[j].creator]
            )
          ).to.eq(balanceOfCreatorAfter);
        }

        expect(marketingBefore.add(toMarketing.div(10000))).to.eq(
          marketingAfter
        );
        expect(reserveBefore.add(toReserve.div(10000))).to.eq(reserveAfter);
        expect(presaleBefore.add(toPresale.div(10000))).to.eq(presaleAfter);
        expect(shareCollectionAfter[0][1]).to.eq(shareCollectionAfter[0][2]);

        await expect(tiexShareCollections.distribute(models[i].modelId)).to.be
          .reverted;
      }
    });
  });
});
