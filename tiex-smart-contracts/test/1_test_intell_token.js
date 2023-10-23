const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseUnits, DECIMALS } = require("./helper");

describe("IntelligenceInvestmentToken", function () {
  async function deployIntelligenceExchangeProtocolFixture() {
    const TOTAL_SUPPLY = 1_000_000_000;
    const TOKEN_NAME = "Intelligence Investment Token";
    const TOKEN_SYMBOL = "INTELL";

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const IntelligenceInvestmentToken = await ethers.getContractFactory(
      "IntelligenceInvestmentToken"
    );
    const intelligenceInvestmentToken =
      await IntelligenceInvestmentToken.deploy(owner.address);

    return {
      owner,
      otherAccount,
      intelligenceInvestmentToken,
      DECIMALS,
      TOTAL_SUPPLY,
      TOKEN_NAME,
      TOKEN_SYMBOL,
    };
  }

  describe("Deployment", function () {
    it("Should set the right Name of INTELL token", async function () {
      const { intelligenceInvestmentToken, TOKEN_NAME } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intelligenceInvestmentToken.name()).to.equal(TOKEN_NAME);
    });

    it("Should set the right Symbol of INTELL token", async function () {
      const { intelligenceInvestmentToken, TOKEN_SYMBOL } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );
      expect(await intelligenceInvestmentToken.symbol()).to.equal(TOKEN_SYMBOL);
    });

    it("Should set the right decimals", async function () {
      const { intelligenceInvestmentToken, DECIMALS } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );

      expect(await intelligenceInvestmentToken.decimals()).to.equal(DECIMALS);
    });

    it("Should set the right total supply", async function () {
      const { intelligenceInvestmentToken, TOTAL_SUPPLY } = await loadFixture(
        deployIntelligenceExchangeProtocolFixture
      );

      expect(await intelligenceInvestmentToken.totalSupply()).to.equal(
        parseUnits(TOTAL_SUPPLY)
      );
    });

    it("Should set [balanceOf(owner) == totalSupply()] when the owner deploys token", async function () {
      const { intelligenceInvestmentToken, TOTAL_SUPPLY, DECIMALS, owner } =
        await loadFixture(deployIntelligenceExchangeProtocolFixture);

      expect(
        await intelligenceInvestmentToken.balanceOf(owner.address)
      ).to.equal(parseUnits(TOTAL_SUPPLY));
    });
  });

  describe("Transactions", function () {
    it("Should transfer tokens between accounts", async function () {
      const { intelligenceInvestmentToken, owner, otherAccount } =
        await loadFixture(deployIntelligenceExchangeProtocolFixture);
      const amount = 100;

      await expect(
        intelligenceInvestmentToken.transfer(
          otherAccount.address,
          parseUnits(100)
        )
      ).to.changeTokenBalances(
        intelligenceInvestmentToken,
        [owner, otherAccount],
        [parseUnits(-amount), parseUnits(amount)]
      );
    });

    it("Should fail if sender doesn’t have enough tokens", async function () {
      const { intelligenceInvestmentToken, owner, otherAccount } =
        await loadFixture(deployIntelligenceExchangeProtocolFixture);

      const initialOwnerBalance = await intelligenceInvestmentToken.balanceOf(
        owner.address
      );

      await expect(
        intelligenceInvestmentToken.transfer(
          otherAccount.address,
          initialOwnerBalance + 0x01
        )
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");

      expect(
        await intelligenceInvestmentToken.balanceOf(owner.address)
      ).to.equal(initialOwnerBalance);
    });

    it("Should update allowance based on `approve`", async function () {
      const { intelligenceInvestmentToken, owner, otherAccount } =
        await loadFixture(deployIntelligenceExchangeProtocolFixture);

      await intelligenceInvestmentToken.approve(otherAccount.address, 100);
      expect(
        await intelligenceInvestmentToken.allowance(
          owner.address,
          otherAccount.address
        )
      ).to.equal(100);
    });

    it("Should update allowance based on `permit`", async () => {
      const { intelligenceInvestmentToken, otherAccount, owner } = await loadFixture(deployIntelligenceExchangeProtocolFixture);
      const nonce = await intelligenceInvestmentToken.nonces(owner.address);
      const amount = ethers.constants.MaxUint256;
      const SECOND = 1000;
      const deadline = Math.trunc((Date.now() + 1200 * SECOND) / SECOND);
      const domain = {
        name: "Intelligence Investment Token",
        version: "1",
        chainId: 1337,
        verifyingContract: intelligenceInvestmentToken.address
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
        owner: owner.address,
        spender: otherAccount.address,
        value: amount,
        nonce,
        deadline,
      };

      const signature = await owner._signTypedData(domain, types, value);
      let sig = ethers.utils.splitSignature(signature);

      const verifiedAddress = ethers.utils.verifyTypedData(domain, {
        Permit: types.Permit
      }, value, signature);

      expect(verifiedAddress).to.eq(owner.address);

      await intelligenceInvestmentToken.permit(
        owner.address,
        otherAccount.address,
        amount,
        deadline,
        sig.v,
        sig.r,
        sig.s
      );

      expect(await intelligenceInvestmentToken.allowance(owner.address, otherAccount.address)).to.eq(ethers.constants.MaxUint256);

    })

    it("Should transfer tokens from one account to another with allowance", async function () {
      const { intelligenceInvestmentToken, owner, otherAccount, DECIMALS } =
        await loadFixture(deployIntelligenceExchangeProtocolFixture);

      const testAmount = 100; //INTELL as unit

      await intelligenceInvestmentToken.approve(
        otherAccount.address,
        parseUnits(testAmount)
      );

      await expect(
        intelligenceInvestmentToken
          .connect(otherAccount)
          .transferFrom(owner.address, otherAccount.address, parseUnits(100))
      ).to.changeTokenBalances(
        intelligenceInvestmentToken,
        [owner, otherAccount],
        [parseUnits(-testAmount), parseUnits(testAmount)]
      );

      expect(
        await intelligenceInvestmentToken.allowance(
          owner.address,
          otherAccount.address
        )
      ).to.equal(0);
    });

    it("Should fail if sender doesn’t have enough allowance", async function () {
      const { intelligenceInvestmentToken, owner, otherAccount, DECIMALS } =
        await loadFixture(deployIntelligenceExchangeProtocolFixture);

      const approveAmount = parseUnits(99); // INTELL as unit
      const transferAmount = parseUnits(100); // INTELL as unit

      await intelligenceInvestmentToken.approve(
        otherAccount.address,
        approveAmount
      );

      await expect(
        intelligenceInvestmentToken
          .connect(otherAccount)
          .transferFrom(owner.address, otherAccount.address, transferAmount)
      ).to.be.revertedWith("ERC20: insufficient allowance");
    });

    it("Should burn some tokens to address(0)", async function () {
      const { intelligenceInvestmentToken, owner, TOTAL_SUPPLY } =
        await loadFixture(deployIntelligenceExchangeProtocolFixture);
      const burnAmount = 1000;

      await expect(
        intelligenceInvestmentToken.burn(parseUnits(burnAmount))
      ).to.changeTokenBalance(
        intelligenceInvestmentToken,
        owner,
        parseUnits(-burnAmount)
      );

      expect(await intelligenceInvestmentToken.totalSupply()).to.equal(
        parseUnits(TOTAL_SUPPLY - burnAmount)
      );
    });
  });

});
