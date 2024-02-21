const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  BRAINSTEMS_TOKEN_MAX_SUPPLY,
  BRAINSTEMS_TOKEN_TO_USDC,
  USDCOIN_NAME,
  USDCOIN_SYMBOL,
  USDCOIN_DECIMALS,
  BRAINSTEMS_TOKEN_EVENTS,
  BRAINSTEMS_TOKEN_INVESTORS_CAP,
} = require("../consts");
const { verifyEvents } = require("../utils");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

let owner, investor1, investor2, user, balances;

describe("ERC20: Investors", function () {
  async function setupFixture() {
    [owner, investor1, investor2, user] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    const usdCoin = await TestErc20.deploy(
      USDCOIN_NAME,
      USDCOIN_SYMBOL,
      USDCOIN_DECIMALS
    );
    await usdCoin.waitForDeployment();

    const BrainstemsToken = await ethers.getContractFactory("BrainstemsToken");
    const brainstemsToken = await upgrades.deployProxy(BrainstemsToken, [
      owner.address,
      usdCoin.target,
      BRAINSTEMS_TOKEN_TO_USDC,
    ]);
    await brainstemsToken.waitForDeployment();

    balances = [
      { investor: investor1, balance: 25000n },
      { investor: investor2, balance: 300000n },
    ];

    return { brainstemsToken, usdCoin };
  }

  describe("should be able to", function () {
    it("add investors with valid parameters", async function () {
      const { brainstemsToken } = await loadFixture(setupFixture);

      for await (const balance of balances) {
        // investors should be able to be added during any stage
        await brainstemsToken.moveToNextStage();

        const previousAllocatedTokens =
          await brainstemsToken.investorTokensAllocated();

        const tx = await brainstemsToken.addInvestor(
          balance.investor,
          balance.balance
        );
        await tx.wait();

        await verifyEvents(tx, brainstemsToken, BRAINSTEMS_TOKEN_EVENTS.INVESTOR_ADDED, [
          {
            investor: balance.investor.address,
            balance: balance.balance,
          },
        ]);

        const newAllocatedTokens = await brainstemsToken.investorTokensAllocated();
        expect(newAllocatedTokens - previousAllocatedTokens).to.eq(
          balance.balance
        );

        const contractInvestor = await brainstemsToken.investors(
          balance.investor.address
        );
        expect(contractInvestor).to.deep.eq([true, balance.balance]);
      }
    });

    it("claim investor tokens with valid parameters", async function () {
      const { brainstemsToken } = await loadFixture(setupFixture);

      for await (const balance of balances) {
        await brainstemsToken.addInvestor(balance.investor, balance.balance);
      }

      for await (const balance of balances) {
        const tx = await brainstemsToken
          .connect(balance.investor)
          .claimInvestorTokens();
        await tx.wait();

        await verifyEvents(tx, brainstemsToken, BRAINSTEMS_TOKEN_EVENTS.TOKENS_CLAIMED, [
          {
            investor: balance.investor.address,
            amount: balance.balance,
          },
        ]);
      }
    });
  });

  describe("should fail to", function () {
    it("add investors with invalid parameters", async function () {
      const { brainstemsToken } = await loadFixture(setupFixture);
      const investor = user;
      const balance = 100n;

      await expect(
        brainstemsToken.connect(investor).addInvestor(investor, balance)
      ).to.be.revertedWithCustomError(
        brainstemsToken,
        "AccessControlUnauthorizedAccount"
      );

      await expect(
        brainstemsToken.addInvestor(ethers.ZeroAddress, balance)
      ).to.be.revertedWith("invalid investor");

      await expect(brainstemsToken.addInvestor(investor, 0n)).to.be.revertedWith(
        "invalid balance"
      );

      await brainstemsToken.addInvestor(owner, BRAINSTEMS_TOKEN_INVESTORS_CAP);
      await expect(brainstemsToken.addInvestor(owner, balance)).to.be.revertedWith(
        "investor already added"
      );

      await expect(
        brainstemsToken.addInvestor(investor, balance)
      ).to.be.revertedWith("insufficient investor tokens");
    });

    it("claim investor tokens with invalid parameters", async function () {
      const { brainstemsToken } = await loadFixture(setupFixture);

      for await (const balance of balances) {
        await brainstemsToken.addInvestor(balance.investor, balance.balance);
      }

      await expect(
        brainstemsToken.connect(user).claimInvestorTokens()
      ).to.be.revertedWith("not investor");

      let investor = balances[0].investor;
      await brainstemsToken.connect(investor).claimInvestorTokens();
      await expect(
        brainstemsToken.connect(investor).claimInvestorTokens()
      ).to.be.revertedWith("no balance");

      await brainstemsToken.distribute(
        owner,
        BRAINSTEMS_TOKEN_MAX_SUPPLY - balances[0].balance
      );

      investor = balances[1].investor;
      await expect(
        brainstemsToken.connect(investor).claimInvestorTokens()
      ).to.be.revertedWith("exceeds maximum supply");
    });
  });
});
