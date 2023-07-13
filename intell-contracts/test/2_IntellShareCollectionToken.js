const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  parseUnits,
  DECIMALS,
  bigNumberToDecimal,
  getHardhatPrivateKey,
  hexToDecimal,
} = require("./helper");
const Web3 = require("web3");

const web3 = new Web3(new Web3.providers.HttpProvider());

describe("IntellShareCollectionToken", async function () {
  async function deployIntelligenceExchangeProtocolFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, truthHolder, signer0, signer1] = await ethers.getSigners();
    const truthHolderPrivateKey = getHardhatPrivateKey(1);

    const modelRegisterationPrice = 10000;
    const intellShareCollectionLaunchPrice = 20000;

    // Deploys intell token, intellSetting, intellModelNFT, intellShareCollection contracts
    const intelligenceInvestmentToken = await ethers.deployContract(
      "IntelligenceInvestmentToken"
    );
    const intellSetting = await ethers.deployContract("IntellSetting");
    const intellModelNFTContract = await ethers.deployContract(
      "IntellModelNFTContract",
      ["ipfs://intelligence-exchange-metadata/", intellSetting.address]
    );
    const intellShareCollection = await ethers.deployContract(
      "IntellShareCollectionContract",
      [intellSetting.address]
    );

    // Sets addresses of contracts deployed in intellSetting
    await intellSetting.setIntellTokenAddr(intelligenceInvestmentToken.address);
    await intellSetting.setIntellModelNFTContractAddr(
      intellModelNFTContract.address
    );
    await intellSetting.setIntellShareCollectionContractAddr(
      intellShareCollection.address
    );
    await intellSetting.setTruthHolder(truthHolder.address);
    await intellSetting.setAdmin(owner.address);
    await intellSetting.setModelRegisterationPrice(
      parseUnits(modelRegisterationPrice)
    );
    await intellSetting.setIntellShareCollectionLaunchPrice(
      parseUnits(intellShareCollectionLaunchPrice)
    );

    // ------------------ 1. Gets Intell Model NFT token as Copyright/base IP for creator. ----------------------

    // The following params (model_id, model_progress_status, etc.) are from backend(off-chain) and database (My SQL)
    const model_id = 1; // model identification number from backend (off-chain)
    const model_progress_status = 10; // a installation progress status of the model on machine learning server
    const user_addr = signer0.address; // if the user passed verifying KYC as creator(data scientist)
    const verified_as_creator = true; // if the user account is suspended
    const user_suspended = false; // if the user account is suspended
    const model_upload = true; // if the model is already uploaded to StorJ Storage.
    const approved = true; // if admin approved to allow creator to releases new share collection for investment.
    const hasShare = true; // if the model has share to get the investment from investors
    const paymentTokenAddr = intelligenceInvestmentToken.address; // INTELL token address

    const maxTotalSupply = 1000; // Hardcap
    const mintPrice = 100; // INTELL tokens
    const duration = 3600 * 24 * 365; // 1 year
    const softcap = 500; // softcap
    const forOnlyUSInvestor = true; // for only U.S. investors
    const ipfsHash = "ipfs://QmQ2ZPKdgh5i5pVPVEheCJrCyoNQhMSQ63TxxCgEyQEyAT"; // ipfs hash for metadata

    // The truth holder is signer as TIEX DAO admin role
    const truthHolderSigner = web3.eth.accounts.privateKeyToAccount(
      truthHolderPrivateKey
    );

    // Encoding params from database(My SQL) and backend (off-chain)
    const statusMessage = web3.eth.abi.encodeParameters(
      ["uint256", "uint256", "address", "bool", "bool", "bool"],
      [
        model_id,
        model_progress_status,
        user_addr,
        verified_as_creator,
        user_suspended,
        model_upload,
      ]
    );

    // Converting params encoded into hash byte
    const statusMessageHash = web3.utils.keccak256(statusMessage);

    // Generates signature by truth holder to sign above params from backend and database
    let { signature } = truthHolderSigner.sign(statusMessageHash);

    // Transfers INTELL tokens from owner(INTELL token deployer) to user(creator)
    await intelligenceInvestmentToken.transfer(
      signer0.address,
      parseUnits(modelRegisterationPrice + intellShareCollectionLaunchPrice)
    );

    //Approves for transferFrom function in intellModelNFTContract
    await intelligenceInvestmentToken.connect(signer0).approve(
      intellModelNFTContract.address,
      parseUnits(modelRegisterationPrice)
      // bigNumberToDecimal(ethers.constants.MaxUint256)
    );

    await intelligenceInvestmentToken.connect(signer0).approve(
      intellShareCollection.address,
      parseUnits(intellShareCollectionLaunchPrice)
      // bigNumberToDecimal(ethers.constants.MaxUint256)
    );

    // Gets new NFT token as Copyright/base IP for creator.
    await intellModelNFTContract
      .connect(signer0)
      .adopt(statusMessage, signature);

    expect(
      bigNumberToDecimal(
        await intellModelNFTContract.balanceOf(signer0.address)
      )
    ).to.equal(1);

    expect(
      bigNumberToDecimal(
        await intellModelNFTContract.tokenIdByModelId(model_id)
      )
    ).to.equal(1);

    // --------------------------- 2. Release new share collection ------------------------------

    const intellModelNFTTokenId = bigNumberToDecimal(
      await intellModelNFTContract.tokenIdByModelId(model_id)
    );

    // Encoding params from database(My SQL) and backend (off-chain)
    const __shareCollectionParam = web3.eth.abi.encodeParameters(
      [
        "address",
        "uint256",
        "uint256",
        "uint256",
        "uint256",
        "uint256",
        "bool",
        "string",
      ],
      [
        paymentTokenAddr,
        intellModelNFTTokenId,
        maxTotalSupply,
        parseUnits(mintPrice),
        duration,
        softcap,
        forOnlyUSInvestor,
        ipfsHash,
      ]
    );

    // Converting params encoded into hash byte
    const __shareCollectionHash = web3.utils.keccak256(__shareCollectionParam);

    // Generates signature by truth holder to sign above params from backend and database
    let __shareCollectionSignature = truthHolderSigner.sign(
      __shareCollectionHash
    ).signature;

    // Encoding params from database(My SQL) and backend (off-chain)
    const __validation = web3.eth.abi.encodeParameters(
      ["address", "uint256", "bool", "bool", "bool"],
      [user_addr, intellModelNFTTokenId, user_suspended, approved, hasShare]
    );

    // Converting params encoded into hash byte
    const __validationHash = web3.utils.keccak256(__validation);

    // Generates signature by truth holder to sign above params from backend and database
    let __validationSignature =
      truthHolderSigner.sign(__validationHash).signature;

    await intellShareCollection
      .connect(signer0)
      .releaseShareCollection(
        __shareCollectionParam,
        __shareCollectionSignature,
        __validation,
        __validationSignature
      );

    const lastIntellShareCollectionId = bigNumberToDecimal(
      await intellShareCollection.nextIntellShareCollectionId()
    );

    return {
      owner,
      truthHolder,
      signer0,
      signer1,
      intelligenceInvestmentToken,
      intellSetting,
      intellModelNFTContract,
      intellShareCollection,
      intellShareCollectionLaunchPrice,
      modelRegisterationPrice,
      truthHolderPrivateKey,
      lastIntellShareCollectionId,
      paymentTokenAddr,
      mintPrice,
      maxTotalSupply,
      ipfsHash,
      softcap,
      intellModelNFTTokenId,
    };
  }

  describe("Transactions", function () {
    it("Should release new share collection with Intell Model NFT token", async () => {
      const {
        intellShareCollection,
        lastIntellShareCollectionId,
        paymentTokenAddr,
        maxTotalSupply,
        mintPrice,
        ipfsHash,
        softcap,
        intellModelNFTTokenId,
      } = await loadFixture(deployIntelligenceExchangeProtocolFixture);

      expect(
        await intellShareCollection.shareCollectionExists(
          lastIntellShareCollectionId
        )
      ).to.equal(true);

      expect(
        (
          await intellShareCollection.shareCollections(
            lastIntellShareCollectionId
          )
        )[0] // exports payment token address (INTELL token address)
      ).to.equal(paymentTokenAddr);
      expect(
        bigNumberToDecimal(
          (
            await intellShareCollection.shareCollections(
              lastIntellShareCollectionId
            )
          )[1] // softcap
        )
      ).to.equal(softcap);
      expect(
        bigNumberToDecimal(
          (
            await intellShareCollection.shareCollections(
              lastIntellShareCollectionId
            )
          )[2] // maxtotalsupply
        )
      ).to.equal(maxTotalSupply);
      expect(
        (
          await intellShareCollection.shareCollections(
            lastIntellShareCollectionId
          )
        )[4] // price per a share
      ).to.equal(parseUnits(mintPrice));
      expect(
        bigNumberToDecimal(
          (
            await intellShareCollection.shareCollections(
              lastIntellShareCollectionId
            )
          )[6] // intell model nft token id
        )
      ).to.equal(intellModelNFTTokenId);
      expect(
        (
          await intellShareCollection.shareCollections(
            lastIntellShareCollectionId
          )
        )[10] // for U.S investors?
      ).to.equal(true);
      expect(
        (
          await intellShareCollection.shareCollections(
            lastIntellShareCollectionId
          )
        )[12] // ipfs hash for metadata
      ).to.equal(ipfsHash);

      expect(
        await intellShareCollection.uri(lastIntellShareCollectionId)
      ).to.equal("ipfs://" + ipfsHash);

      expect(
        bigNumberToDecimal(
          await intellShareCollection.getStatus(lastIntellShareCollectionId)
        )
      ).to.equal(3); // In progress
    });

    it("Should cancel the share collection sale", async () => {
      const { intellShareCollection, lastIntellShareCollectionId, signer0 } =
        await loadFixture(deployIntelligenceExchangeProtocolFixture);

      await intellShareCollection
        .connect(signer0)
        .cancel(lastIntellShareCollectionId);
      expect(
        bigNumberToDecimal(
          await intellShareCollection.getStatus(lastIntellShareCollectionId)
        )
      ).to.equal(1);
    });

    it("Should mint shares by calling [adopt function]", async () => {
      const {
        signer1,
        lastIntellShareCollectionId,
        truthHolderPrivateKey,
        intellShareCollection,
        mintPrice,
        intelligenceInvestmentToken,
      } = await loadFixture(deployIntelligenceExchangeProtocolFixture);

      const __userAddr = signer1.address;
      const __kycVerificationAsInvestor = true;
      const __userSuspended = false;
      const __fromUS = true;
      const __amount = 100;
      const __shareCollectionId = lastIntellShareCollectionId;

      // The truth holder is signer as TIEX DAO admin role
      const truthHolderSigner = web3.eth.accounts.privateKeyToAccount(
        truthHolderPrivateKey
      );

      const __adoptParams = web3.eth.abi.encodeParameters(
        ["address", "bool", "bool", "bool", "uint256", "uint256"],
        [
          __userAddr,
          __kycVerificationAsInvestor,
          __userSuspended,
          __fromUS,
          __amount,
          __shareCollectionId,
        ]
      );

      // Converting params encoded into hash byte
      const __adoptParamsHash = web3.utils.keccak256(__adoptParams);

      // Generates signature by truth holder to sign above params from backend and database
      let __adoptParamsSignature =
        truthHolderSigner.sign(__adoptParamsHash).signature;

      // Transfers INTELL tokens from owner(INTELL token deployer) to user(investor - signer1)
      await intelligenceInvestmentToken.transfer(
        signer1.address,
        parseUnits(__amount * mintPrice)
      );

      //Approves for transferFrom function in intellModelNFTContract
      await intelligenceInvestmentToken
        .connect(signer1)
        .approve(
          intellShareCollection.address,
          parseUnits(__amount * mintPrice)
        );

      await intellShareCollection
        .connect(signer1)
        .adopt(__adoptParams, __adoptParamsSignature);

      expect(
        bigNumberToDecimal(
          await intellShareCollection.balanceOf(
            signer1.address,
            lastIntellShareCollectionId
          )
        )
      ).to.equal(__amount); // In progress
    });
  });
});
