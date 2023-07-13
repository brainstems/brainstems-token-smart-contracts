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

describe("IntellModelNFTContract", async function () {
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
    };
  }

  describe("Deployment", function () {
    it("Should set the address of INTELL token in intellSetting contract", async function () {
      const { intelligenceInvestmentToken, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.intellTokenAddr()).to.equal(
        intelligenceInvestmentToken.address
      );
    });

    it("Should set the address of IntellModelNFT contract in intellSetting contract", async function () {
      const { intellModelNFTContract, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.intellModelNFTContractAddr()).to.equal(
        intellModelNFTContract.address
      );
    });

    it("Should set the address of IntellShareCollection contract in intellSetting contract", async function () {
      const { intellShareCollection, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.intellShareCollectionContractAddr()).to.equal(
        intellShareCollection.address
      );
    });

    it("Should set the address of truth holder in intellSetting contract", async function () {
      const { truthHolder, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.truthHolder()).to.equal(truthHolder.address);
    });

    it("Should set the admin address in intellSetting contract", async function () {
      const { owner, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.admin()).to.equal(owner.address);
    });

    it("Should set the commission (Plan) to register model in intellSetting contract", async function () {
      const { modelRegisterationPrice, intellSetting } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intellSetting.modelRegisterationPrice()).to.equal(
        parseUnits(modelRegisterationPrice)
      );
    });

    it("Should set the commission (Plan) to launch new intell share collection in intellSetting contract", async function () {
      const { intellSetting, intellShareCollectionLaunchPrice } =
        await loadFixture(deployIntelligenceExchangeProtocolFixture);
      expect(await intellSetting.intellShareCollectionLaunchPrice()).to.equal(
        parseUnits(intellShareCollectionLaunchPrice)
      );
    });
  });

  describe("Transactions", function () {
    it("Should mint new NFT as a copyright/base IP when registering new model on TIEX DAO [adopt function]", async () => {
      const {
        intellModelNFTContract,
        intelligenceInvestmentToken,
        owner,
        modelRegisterationPrice,
        truthHolderPrivateKey,
        signer0,
      } = await loadFixture(deployIntelligenceExchangeProtocolFixture);

      // The following params (model_id, model_progress_status, etc.) are from backend(off-chain) and database (My SQL)
      const model_id = 1; // model identification number from backend (off-chain)
      const model_progress_status = 10; // a installation progress status of the model on machine learning server
      const user_addr = signer0.address; // if the user passed verifying KYC as creator(data scientist)
      const verified_as_creator = true; // if the user account is suspended
      const user_suspended = false; // if the user account is suspended
      const model_upload = true; // if the model is already uploaded to StorJ Storage.

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
        parseUnits(modelRegisterationPrice)
      );

      //Approves for transferFrom function in intellModelNFTContract
      await intelligenceInvestmentToken
        .connect(signer0)
        .approve(
          intellModelNFTContract.address,
          parseUnits(modelRegisterationPrice)
        );

      // Generates new NFT token as Copyright/base IP for creator
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
    });

    it("Should withdraw all INTELL token from IntellModelNFTContract to TIEX DAO Admin", async () => {
      const { intelligenceInvestmentToken, intellModelNFTContract, owner } =
        await loadFixture(deployIntelligenceExchangeProtocolFixture);

      // testAmount
      const testAmount = 10000; //(INTELL);

      // Deposits INTELL tokens from owner to IntellModelNFTContract
      await intelligenceInvestmentToken.transfer(
        intellModelNFTContract.address,
        parseUnits(testAmount)
      );

      await expect(intellModelNFTContract.withdraw()).to.changeTokenBalances(
        intelligenceInvestmentToken,
        [intellModelNFTContract.address, owner.address],
        [parseUnits(-testAmount), parseUnits(testAmount)]
      );
    });

    it("Should burn NFT (Copyright/Base IP) when renouncing the ownership of model", async () => {
      const {
        intellModelNFTContract,
        intelligenceInvestmentToken,
        owner,
        modelRegisterationPrice,
        truthHolderPrivateKey,
        signer0,
      } = await loadFixture(deployIntelligenceExchangeProtocolFixture);

      // The following params (model_id, model_progress_status, etc.) are from backend(off-chain) and database (My SQL)
      const model_id = 1; // model identification number from backend (off-chain)
      const model_progress_status = 10; // a installation progress status of the model on machine learning server
      const user_addr = signer0.address; // if the user passed verifying KYC as creator(data scientist)
      const verified_as_creator = true; // if the user account is suspended
      const user_suspended = false; // if the user account is suspended
      const model_upload = true; // if the model is already uploaded to StorJ Storage.

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
        parseUnits(modelRegisterationPrice)
      );

      //Approves for transferFrom function in intellModelNFTContract
      await intelligenceInvestmentToken
        .connect(signer0)
        .approve(
          intellModelNFTContract.address,
          parseUnits(modelRegisterationPrice)
        );

      // Generates new NFT token as Copyright/base IP for creator
      await intellModelNFTContract
        .connect(signer0)
        .adopt(statusMessage, signature);

      await intellModelNFTContract
        .connect(signer0)
        .setApprovalForAll(intellModelNFTContract.address, true);

      const nfts = await intellModelNFTContract.walletOfOwner(signer0.address);
      const totalSupply = await intellModelNFTContract.totalSupply();
      const balance = await intellModelNFTContract.balanceOf(signer0.address);

      await intellModelNFTContract
        .connect(signer0)
        .burn(bigNumberToDecimal(nfts[0]));

      expect(await intellModelNFTContract.totalSupply()).to.equal(
        bigNumberToDecimal(totalSupply) - 1
      );
      expect(await intellModelNFTContract.balanceOf(signer0.address)).to.equal(
        bigNumberToDecimal(balance) - 1
      );
    });
  });
});
