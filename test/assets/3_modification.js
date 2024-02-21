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
  user5,
  assets,
  assetId,
  baseAssetId,
  contributors,
  ipfsHash,
  metadata;

describe("Assets: Modification", function () {
  before(async () => {
    [owner, user1, user2, user3, user4, user5] =
      await ethers.getSigners();

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

    await assets.createAsset(
      assetId,
      baseAssetId,
      contributors,
      ipfsHash,
      metadata
    );
  });

  describe("should be able to", function () {
    it("upgrade assets with valid parameters", async function () {
      const newMetadata = {
        ...metadata,
        version: 2n,
        description: "upgraded test asset",
        fingerprint: ethers.randomBytes(32),
        performance: 10n,
      };
      const newIpfsHash =
        "bafybeid6doxhzck3me366265u3ony6rbuzv7dze7pjuptxeln24b2qvur4?filename=trautwein2";
      const tx = await assets.upgradeAsset(assetId, newMetadata, newIpfsHash);
      await tx.wait();

      const expectedAsset = [
        baseAssetId,
        [
          newMetadata.name,
          newMetadata.version,
          newMetadata.description,
          ethers.hexlify(newMetadata.fingerprint),
          newMetadata.trained,
          ethers.hexlify(newMetadata.watermarkFingerprint),
          newMetadata.performance,
        ],
        [
          contributors.creator,
          contributors.marketing,
          contributors.presale,
          contributors.creatorRate,
          contributors.marketingRate,
          contributors.presaleRate,
        ],
        newIpfsHash,
      ];
      const expectedMetadata = expectedAsset[1];

      await verifyEvents(tx, assets, "AssetUpgraded", [
        { assetId: assetId, metadata: expectedMetadata, ipfsHash: newIpfsHash },
      ]);

      const assetExists = await assets.assetExists(assetId);
      expect(assetExists).to.be.true;

      const contractAsset = await assets.getAsset(assetId);

      expect(contractAsset).to.eql(expectedAsset);

      const assetCreator = await assets.creatorOf(assetId);
      expect(assetCreator).to.eq(contributors.creator);

      const assetUri = await assets.uri(assetId);
      expect(assetUri).to.eq("https://ipfs.io/ipfs/" + newIpfsHash);
    });

    it("edit asset URI with valid parameters", async function () {
      const newIpfsHash =
        "QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR?x-ipfs-companion-no-redirect";
      const tx = await assets.editUri(assetId, newIpfsHash);
      await tx.wait();

      await verifyEvents(tx, assets, "AssetUriUpdated", [
        { assetId: assetId, ipfsHash: newIpfsHash },
      ]);

      const assetUri = await assets.uri(assetId);
      expect(assetUri).to.eq("https://ipfs.io/ipfs/" + newIpfsHash);
    });

    it("update marketing address with valid parameters", async function () {
      let contractAsset = await assets.getAsset(assetId);

      const newMarketingAddress = user4.address;
      const tx = await assets.updateMarketingAddress(
        assetId,
        newMarketingAddress
      );
      await tx.wait();

      await verifyEvents(tx, assets, "AssetMarketingAddressUpdated", [
        { assetId: assetId, marketing: newMarketingAddress },
      ]);

      const expectedAsset = [
        contractAsset[0],
        contractAsset[1],
        [
          contractAsset[2][0],
          newMarketingAddress,
          contractAsset[2][2],
          contractAsset[2][3],
          contractAsset[2][4],
          contractAsset[2][5],
        ],
        contractAsset[3],
      ];

      contractAsset = await assets.getAsset(assetId);

      expect(contractAsset).to.eql(expectedAsset);
    });

    it("update presale address with valid parameters", async function () {
      let contractAsset = await assets.getAsset(assetId);
      const newPresaleAddress = user5.address;

      const tx = await assets.updatePresaleAddress(assetId, newPresaleAddress);
      await tx.wait();

      await verifyEvents(tx, assets, "AssetPresaleAddressUpdated", [
        { assetId: assetId, presale: newPresaleAddress },
      ]);

      const expectedAsset = [
        contractAsset[0],
        contractAsset[1],
        [
          contractAsset[2][0],
          contractAsset[2][1],
          newPresaleAddress,
          contractAsset[2][3],
          contractAsset[2][4],
          contractAsset[2][5],
        ],
        contractAsset[3],
      ];

      contractAsset = await assets.getAsset(assetId);

      expect(contractAsset).to.eql(expectedAsset);
    });

    it("update investment distribution rate with valid parameters", async function () {
      let contractAsset = await assets.getAsset(assetId);

      const distributionRates = {
        creator: 8000n,
        marketing: 1000n,
        presale: 1000n,
      };

      const tx = await assets.updateInvestmentDistributionRate(
        assetId,
        distributionRates.creator,
        distributionRates.marketing,
        distributionRates.presale
      );
      await tx.wait();

      await verifyEvents(tx, assets, "AssetRatesUpdated", [
        {
          assetId: assetId,
          creatorRate: distributionRates.creator,
          marketingRate: distributionRates.marketing,
          presaleRate: distributionRates.presale,
        },
      ]);

      const expectedAsset = [
        contractAsset[0],
        contractAsset[1],
        [
          contractAsset[2][0],
          contractAsset[2][1],
          contractAsset[2][2],
          distributionRates.creator,
          distributionRates.marketing,
          distributionRates.presale,
        ],
        contractAsset[3],
      ];
      contractAsset = await assets.getAsset(assetId);

      expect(contractAsset).to.eql(expectedAsset);
    });
  });

  describe("should fail to", function () {
    it("upgrade assets with invalid parameters", async function () {
      await expect(
        assets.upgradeAsset(assetId + 1n, metadata, ipfsHash)
      ).to.be.revertedWith("asset not found");

      await expect(
        assets.upgradeAsset(assetId, metadata, ipfsHash)
      ).to.be.revertedWith("invalid metadata");

      await expect(
        assets.upgradeAsset(assetId, { ...metadata, name: "" }, ipfsHash)
      ).to.be.revertedWith("invalid metadata");

      await expect(
        assets.upgradeAsset(assetId, { ...metadata, description: "" }, ipfsHash)
      ).to.be.revertedWith("invalid metadata");

      await expect(
        assets.connect(user1).upgradeAsset(assetId, metadata, ipfsHash)
      ).to.be.revertedWithCustomError(
        assets,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("edit asset URI with invalid parameters", async function () {
      await expect(
        assets.connect(user1).editUri(assetId, ipfsHash)
      ).to.be.revertedWithCustomError(
        assets,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("update marketing address with invalid parameters", async function () {
      await expect(
        assets.connect(user1).updateMarketingAddress(assetId, user1)
      ).to.be.revertedWithCustomError(
        assets,
        "AccessControlUnauthorizedAccount"
      );

      const contractAsset = await assets.getAsset(assetId);
      const marketingAddress = contractAsset[2][1];

      await expect(
        assets.updateMarketingAddress(assetId, marketingAddress)
      ).to.be.revertedWith("no change to address");
    });

    it("update presale address with invalid parameters", async function () {
      await expect(
        assets.connect(user1).updatePresaleAddress(assetId, user1)
      ).to.be.revertedWithCustomError(
        assets,
        "AccessControlUnauthorizedAccount"
      );

      const contractAsset = await assets.getAsset(assetId);
      const presaleAddress = contractAsset[2][2];

      await expect(
        assets.updatePresaleAddress(assetId, presaleAddress)
      ).to.be.revertedWith("no change to address");
    });

    it("update investment distribution rate with invalid parameters", async function () {
      let invalidDistributionRates = {
        creator: 10000n,
        marketing: 1000n,
        presale: 1000n,
      };

      await expect(
        assets
          .connect(user1)
          .updateInvestmentDistributionRate(
            assetId,
            invalidDistributionRates.creator,
            invalidDistributionRates.marketing,
            invalidDistributionRates.presale
          )
      ).to.be.revertedWithCustomError(
        assets,
        "AccessControlUnauthorizedAccount"
      );

      await expect(
        assets.updateInvestmentDistributionRate(
          assetId,
          invalidDistributionRates.creator,
          invalidDistributionRates.marketing,
          invalidDistributionRates.presale
        )
      ).to.be.revertedWith("invalid rates");

      invalidDistributionRates = {
        creator: 1000n,
        marketing: 9500n,
        presale: 4000n,
      };

      await expect(
        assets.updateInvestmentDistributionRate(
          assetId,
          invalidDistributionRates.creator,
          invalidDistributionRates.marketing,
          invalidDistributionRates.presale
        )
      ).to.be.revertedWith("invalid rates");
    });
  });
});
