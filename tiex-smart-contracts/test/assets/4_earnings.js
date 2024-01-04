const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  INTELLTOKEN_NAME,
  INTELLTOKEN_SYMBOL,
  INTELL_TOKEN_DECIMALS,
} = require("../consts");
const { verifyEvents } = require("../utils");

let owner,
  user1,
  user2,
  user3,
  user4,
  intellToken,
  assets,
  registeredAssets,
  balances;

describe.only("Assets: Earnings", function () {
  before(async () => {
    [owner, user1, user2, user3, user4] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    intellToken = await TestErc20.deploy(
      INTELLTOKEN_NAME,
      INTELLTOKEN_SYMBOL,
      INTELL_TOKEN_DECIMALS
    );
    await intellToken.waitForDeployment();

    const Assets = await ethers.getContractFactory("Assets");
    assets = await upgrades.deployProxy(Assets, [
      owner.address,
      intellToken.target,
    ]);
    await assets.waitForDeployment();

    registeredAssets = [
      {
        assetId: 29n,
        baseAssetId: 0n,
        contributors: {
          creator: user3.address,
          marketing: user2.address,
          presale: user1.address,
          creatorRate: 6000n,
          marketingRate: 1000n,
          presaleRate: 3000n,
        },
        ipfsHash: "bafybeihkoviema7g3gxyt6la7vd5ho32ictqbilu3wnlo3rs7ewhnp7lly",
        metadata: {
          name: "testAsset #1",
          version: 1n,
          description: "test description",
          fingerprint: ethers.randomBytes(32),
          trained: true,
          watermarkFingerprint: ethers.randomBytes(32),
          performance: 66n,
        },
      },
      {
        assetId: 199n,
        baseAssetId: 29n,
        contributors: {
          creator: user4.address,
          marketing: user1.address,
          presale: user3.address,
          creatorRate: 9900n,
          marketingRate: 60n,
          presaleRate: 40n,
        },
        ipfsHash:
          "QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR?x-ipfs-companion-no-redirect",
        metadata: {
          name: "testAsset #2",
          version: 1n,
          description: "test description",
          fingerprint: ethers.randomBytes(32),
          trained: false,
          watermarkFingerprint: ethers.randomBytes(32),
          performance: 0n,
        },
      },
    ];

    balances = {};

    for await (const asset of registeredAssets) {
      await assets.createAsset(
        asset.assetId,
        asset.baseAssetId,
        asset.contributors,
        asset.ipfsHash,
        asset.metadata
      );

      balances[asset.contributors.creator] = 0n;
      balances[asset.contributors.marketing] = 0n;
      balances[asset.contributors.presale] = 0n;
    }

    // fund admin
    await intellToken.mint(owner, 100000000n);
    await intellToken.connect(owner).approve(assets.target, ethers.MaxUint256);
  });

  describe("should be able to", function () {
    it("deposit with valid parameters", async function () {
      const deposits = [
        { assetId: registeredAssets[0].assetId, amount: 500000n },
        { assetId: registeredAssets[1].assetId, amount: 124306n },
        { assetId: registeredAssets[0].assetId, amount: 3n },
      ];
      for await (const deposit of deposits) {
        const previousOwnerBalance = await intellToken.balanceOf(owner);
        const previousContractBalance = await intellToken.balanceOf(
          assets.target
        );

        const amount = deposit.amount;
        const assetId = deposit.assetId;
        const tx = await assets.deposit(assetId, amount);
        await tx.wait();

        const asset = await assets.getAsset(assetId);
        const creatorRate = asset[2][3];
        const marketingRate = asset[2][4];
        const presaleRate = asset[2][5];

        const creatorAmount = (amount * creatorRate) / 10000n;
        const marketingAmount = (amount * marketingRate) / 10000n;
        const presaleAmount = (amount * presaleRate) / 10000n;

        const creator = asset[2][0];
        const marketing = asset[2][1];
        const presale = asset[2][2];

        balances[creator] += creatorAmount;
        balances[marketing] += marketingAmount;
        balances[presale] += presaleAmount;

        await verifyEvents(tx, assets, "AssetEarningsDeposited", [
          {
            assetId,
            creatorAmount,
            marketingAmount,
            presaleAmount,
          },
        ]);

        const newOwnerBalance = await intellToken.balanceOf(owner);
        const newContractBalance = await intellToken.balanceOf(assets.target);

        expect(previousOwnerBalance - newOwnerBalance).to.eq(
          creatorAmount + marketingAmount + presaleAmount
        );
        expect(newContractBalance - previousContractBalance).to.eq(
          creatorAmount + marketingAmount + presaleAmount
        );
      }
    });

    it("withdraw with valid parameters", async function () {});
  });

  describe("should fail to", function () {
    it("deposit with invalid parameters", async function () {
      const asset = registeredAssets[0];

      await expect(
        assets.connect(user1).deposit(asset.assetId, 1000n)
      ).to.be.revertedWithCustomError(
        assets,
        "AccessControlUnauthorizedAccount"
      );

      const adminRole = await assets.DEFAULT_ADMIN_ROLE();
      await assets.grantRole(adminRole, user1);

      await expect(
        assets.connect(user1).deposit(asset.assetId, 100000000n)
      ).to.be.revertedWith("insufficient balance");

      await intellToken.mint(user1, 100000000n);

      await expect(
        assets.connect(user1).deposit(asset.assetId, 100000000n)
      ).to.be.revertedWith("insufficient allowance");
    });

    it("withdraw with invalid parameters", async function () {});
  });
});
