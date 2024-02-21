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
  assets,
  assetId,
  baseAssetId,
  contributors,
  ipfsHash,
  metadata;

describe("Assets: Creation", function () {
  before(async () => {
    [owner, user1, user2, user3] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    const brainstemsToken = await TestErc20.deploy(
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

    assetId = 13n;
    baseAssetId = 0n;
    contributors = {
      creator: user1.address,
      marketing: user2.address,
      presale: user3.address,
      creatorRate: 5000n,
      marketingRate: 2000n,
      presaleRate: 3000n,
    };
    ipfsHash = "bafybeihkoviema7g3gxyt6la7vd5ho32ictqbilu3wnlo3rs7ewhnp7lly";
    metadata = {
      name: "testAsset",
      version: 1n,
      description: "test description",
      fingerprint: ethers.randomBytes(32),
      trained: false,
      watermarkFingerprint: ethers.randomBytes(32),
      performance: 73n,
    };
  });

  describe("should be able to create assets", function () {
    it("with valid parameters", async function () {
      const tx = await assets.createAsset(
        assetId,
        baseAssetId,
        contributors,
        ipfsHash,
        metadata
      );
      await tx.wait();

      const expectedAsset = [
        baseAssetId,
        [
          metadata.name,
          metadata.version,
          metadata.description,
          ethers.hexlify(metadata.fingerprint),
          metadata.trained,
          ethers.hexlify(metadata.watermarkFingerprint),
          metadata.performance,
        ],
        [
          contributors.creator,
          contributors.marketing,
          contributors.presale,
          contributors.creatorRate,
          contributors.marketingRate,
          contributors.presaleRate,
        ],
        ipfsHash,
      ];

      await verifyEvents(tx, assets, "AssetCreated", [
        { assetId: assetId, asset: expectedAsset },
      ]);

      const assetExists = await assets.assetExists(assetId);
      expect(assetExists).to.be.true;

      const contractAsset = await assets.getAsset(assetId);

      expect(contractAsset).to.eql(expectedAsset);

      const assetCreator = await assets.creatorOf(assetId);
      expect(assetCreator).to.eq(contributors.creator);

      const assetUri = await assets.uri(assetId);
      expect(assetUri).to.eq("https://ipfs.io/ipfs/" + ipfsHash);
    });
  });

  describe("should fail to create assets", function () {
    it("with invalid parameters", async function () {
      await expect(
        assets.createAsset(
          assetId,
          baseAssetId,
          contributors,
          ipfsHash,
          metadata
        )
      ).to.be.revertedWith("asset already exists");

      const newAssetId = assetId + 1n;
      await expect(
        assets.createAsset(
          newAssetId,
          baseAssetId,
          { ...contributors, creator: ethers.ZeroAddress },
          ipfsHash,
          metadata
        )
      ).to.be.revertedWith("invalid creator");

      await expect(
        assets.createAsset(
          newAssetId,
          baseAssetId + 1n,
          contributors,
          ipfsHash,
          metadata
        )
      ).to.be.revertedWith("invalid base asset");

      await expect(
        assets.createAsset(
          newAssetId,
          baseAssetId,
          { ...contributors, creatorRate: contributors.creatorRate + 1n },
          ipfsHash,
          metadata
        )
      ).to.be.revertedWith("invalid contributor rates");

      await expect(
        assets.createAsset(newAssetId, baseAssetId, contributors, ipfsHash, {
          ...metadata,
          name: "",
        })
      ).to.be.revertedWith("invalid metadata");

      await expect(
        assets.createAsset(newAssetId, baseAssetId, contributors, ipfsHash, {
          ...metadata,
          description: "",
        })
      ).to.be.revertedWith("invalid metadata");

      await expect(
        assets.createAsset(newAssetId, baseAssetId, contributors, ipfsHash, {
          ...metadata,
          version: 2n,
        })
      ).to.be.revertedWith("invalid metadata");

      await expect(
        assets
          .connect(user1)
          .createAsset(assetId, baseAssetId, contributors, ipfsHash, metadata)
      ).to.be.revertedWithCustomError(
        assets,
        "AccessControlUnauthorizedAccount"
      );

      const assetExists = await assets.assetExists(newAssetId);
      expect(assetExists).to.be.false;

      await expect(assets.getAsset(newAssetId)).to.be.revertedWith(
        "asset not found"
      );

      await expect(assets.creatorOf(newAssetId)).to.be.revertedWith(
        "asset not found"
      );

      await expect(assets.uri(newAssetId)).to.be.revertedWith(
        "asset not found"
      );
    });
  });
});
