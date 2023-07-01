const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseUnits, DECIMALS, bigNumberToDecimal } = require("./helper");
const Web3 = require("web3");

const web3 = new Web3(new Web3.providers.HttpProvider());

describe("IntelligenceInvestmentToken", async function () {
  async function deployIntelligenceExchangeProtocolFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, truthHolder, signer0, signer1] = await ethers.getSigners();
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
      ["Intelligence Share Collections", "ISC", intellSetting.address]
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
    await intellSetting.setintellShareCollectionLaunchPrice(
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

  describe("IntellModdelNFT", function () {
    it("Should", async () => {
      const { intellModelNFTContract, intelligenceInvestmentToken, owner, modelRegisterationPrice } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      //   (
      //     // model identification number from backend (off-chain)
      //     uint256 _MODEL_ID,
      //     // a installation progress status of the model on machine learning server
      //     uint256 _MODEL_PROGRESS_STATUS,
      //     // user account address from backend and database
      //     address _USER_ADDR,
      //     // if the user passed verifying KYC as creator(data scientist)
      //     bool _VERIFIED_AS_CREATOR,
      //     // if the user account is suspended
      //     bool _USER_SUSPENDED,
      //     // if the model is already uploaded to StorJ Storage.
      //     bool _MODEL_UPLOADED
      // ) = abi.decode(
      //         statusMessage,
      //         (uint256, uint256, address, bool, bool, bool)
      //     );
      const model_id = 1;
      const model_progress_status = 10;
      const user_addr = owner.address;
      const verified_as_creator = true;
      const user_suspended = false;
      const model_upload = true;
      const message = web3.eth.abi.encodeParameters(
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

      await intelligenceInvestmentToken.approve(intellModelNFTContract.address, parseUnits(modelRegisterationPrice));
      await intellModelNFTContract.adopt(message, message);

      expect(bigNumberToDecimal(await intellModelNFTContract.balanceOf(owner.address))).to.equal(
        1
      );
      expect(bigNumberToDecimal(await intellModelNFTContract.tokenIdByModelId(model_id))).to.equal(
        1
      )
    });
  });
});
