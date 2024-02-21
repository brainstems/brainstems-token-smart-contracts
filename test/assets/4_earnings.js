const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  BRAINSTEMS_TOKEN_NAME,
  BRAINSTEMS_TOKEN_SYMBOL,
  BRAINSTEMS_TOKEN_DECIMALS,
} = require("../consts");
const { verifyEvents } = require("../utils");

let owner,
  user1,
  user2,
  user3,
  user4,
  brainstemsToken,
  assets,
  registeredAssets,
  balances;

describe("Assets: Earnings", function () {
  before(async () => {
    [owner, user1, user2, user3, user4] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    brainstemsToken = await TestErc20.deploy(
      BRAINSTEMS_TOKEN_NAME,
      BRAINSTEMS_TOKEN_SYMBOL,
      BRAINSTEMS_TOKEN_DECIMALS
    );
    await brainstemsToken.waitForDeployment();

    const Assets = await ethers.getContractFactory("Assets");
    assets = await upgrades.deployProxy(Assets, [
      owner.address,
      brainstemsToken.target,
    ]);
    await assets.waitForDeployment();

    registeredAssets = [
      {
        assetId: 29n,
        baseAssetId: 0n,
        contributors: {
          creator: user3,
          marketing: user2,
          presale: user1,
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
          creator: user4,
          marketing: user1,
          presale: user3,
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

    for await (const asset of registeredAssets) {
      await assets.createAsset(
        asset.assetId,
        asset.baseAssetId,
        asset.contributors,
        asset.ipfsHash,
        asset.metadata
      );
    }

    balances = {};

    // fund admin
    await brainstemsToken.mint(owner, 100000000n);
    await brainstemsToken.connect(owner).approve(assets.target, ethers.MaxUint256);
  });

  describe("should be able to", function () {
    it("deposit with valid parameters", async function () {
      const deposits = [
        { assetId: registeredAssets[0].assetId, amount: 500000n },
        { assetId: registeredAssets[1].assetId, amount: 124306n },
        { assetId: registeredAssets[0].assetId, amount: 3n },
      ];
      for await (const deposit of deposits) {
        const previousOwnerBalance = await brainstemsToken.balanceOf(owner);
        const previousContractBalance = await brainstemsToken.balanceOf(
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

        if (balances[assetId] === undefined) {
          balances[assetId] = {};
        }
        for (const address of [creator, marketing, presale]) {
          if (balances[assetId][address] === undefined) {
            balances[assetId][address] = 0n;
          }
        }

        balances[assetId][creator] += creatorAmount;
        balances[assetId][marketing] += marketingAmount;
        balances[assetId][presale] += presaleAmount;

        await verifyEvents(tx, assets, "AssetEarningsDeposited", [
          {
            assetId,
            creatorAmount,
            marketingAmount,
            presaleAmount,
          },
        ]);

        const newOwnerBalance = await brainstemsToken.balanceOf(owner);
        const newContractBalance = await brainstemsToken.balanceOf(assets.target);

        expect(previousOwnerBalance - newOwnerBalance).to.eq(
          creatorAmount + marketingAmount + presaleAmount
        );
        expect(newContractBalance - previousContractBalance).to.eq(
          creatorAmount + marketingAmount + presaleAmount
        );
      }
    });

    it("withdraw with valid parameters", async function () {
      for await (const asset of registeredAssets) {
        const creator = asset.contributors.creator;
        const marketing = asset.contributors.marketing;
        const presale = asset.contributors.presale;

        for await (const caller of [creator, marketing, presale]) {
          const previousCallerBalance = await brainstemsToken.balanceOf(caller);
          const previousContractBalance = await brainstemsToken.balanceOf(
            assets.target
          );

          const tx = await assets.connect(caller).withdraw(asset.assetId);
          await tx.wait();

          const balance = balances[asset.assetId][caller.address];

          await verifyEvents(tx, assets, "AssetEarningsWithdrawn", [
            {
              assetId: asset.assetId,
              caller: caller.address,
              balance: balance,
            },
          ]);

          const newCallerBalance = await brainstemsToken.balanceOf(caller);
          const newContractBalance = await brainstemsToken.balanceOf(assets.target);

          expect(newCallerBalance - previousCallerBalance).to.eq(balance);
          expect(previousContractBalance - newContractBalance).to.eq(balance);
        }
      }
    });
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

      await brainstemsToken.mint(user1, 100000000n);

      await expect(
        assets.connect(user1).deposit(asset.assetId, 100000000n)
      ).to.be.revertedWith("insufficient allowance");
    });

    it("withdraw with invalid parameters", async function () {
      const asset = registeredAssets[0];

      await expect(assets.withdraw(asset.assetId)).to.be.revertedWith(
        "caller is not a contributor"
      );

      const creator = asset.contributors.creator;

      await expect(
        assets.connect(creator).withdraw(asset.assetId)
      ).to.be.revertedWith("no balance");
    });
  });
});
