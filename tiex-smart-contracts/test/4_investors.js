const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  INTELLTOKEN_MAX_SUPPLY,
  INTELLTOKEN_SALES_CAP,
  INTELLTOKEN_TO_USDC,
  USDCOIN_NAME,
  USDCOIN_SYMBOL,
  USDCOIN_DECIMALS,
  INTELLTOKEN_EVENTS,
  INTELLTOKEN_STAGES,
  INTELLTOKEN_INVESTORS_CAP,
} = require("./consts");
const { verifyEvents } = require("./utils");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

let owner, investor1, investor2, user, balances;

describe("Investors", function () {
  async function setupFixture() {
    [owner, investor1, investor2, user] = await ethers.getSigners();

    const TestErc20 = await ethers.getContractFactory("TestERC20");
    const usdCoin = await TestErc20.deploy(
      USDCOIN_NAME,
      USDCOIN_SYMBOL,
      USDCOIN_DECIMALS
    );
    await usdCoin.waitForDeployment();

    const IntellToken = await ethers.getContractFactory("IntelligenceToken");
    const intellToken = await upgrades.deployProxy(IntellToken, [
      owner.address,
      usdCoin.target,
      INTELLTOKEN_TO_USDC,
    ]);
    await intellToken.waitForDeployment();

    balances = [
      { investor: investor1, balance: 25000n },
      { investor: investor2, balance: 300000n },
    ];

    return { intellToken, usdCoin };
  }

  describe("should be able to", function () {
    it("add investors with valid parameters", async function () {
      const { intellToken } = await loadFixture(setupFixture);

      for await (const balance of balances) {
        // investors should be able to be added during any stage
        await intellToken.moveToNextStage();

        const previousAllocatedTokens =
          await intellToken.investorTokensAllocated();

        const tx = await intellToken.addInvestor(
          balance.investor,
          balance.balance
        );
        await tx.wait();

        await verifyEvents(tx, intellToken, INTELLTOKEN_EVENTS.INVESTOR_ADDED, [
          {
            investor: balance.investor.address,
            balance: balance.balance,
          },
        ]);

        const newAllocatedTokens = await intellToken.investorTokensAllocated();
        expect(newAllocatedTokens - previousAllocatedTokens).to.eq(
          balance.balance
        );

        const contractInvestor = await intellToken.investors(
          balance.investor.address
        );
        expect(contractInvestor).to.deep.eq([true, balance.balance]);
      }
    });

    it("claim investor tokens with valid parameters", async function () {
      const { intellToken } = await loadFixture(setupFixture);

      for await (const balance of balances) {
        await intellToken.addInvestor(balance.investor, balance.balance);
      }

      for await (const balance of balances) {
        const tx = await intellToken
          .connect(balance.investor)
          .claimInvestorTokens();
        await tx.wait();

        await verifyEvents(tx, intellToken, INTELLTOKEN_EVENTS.TOKENS_CLAIMED, [
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
      const { intellToken } = await loadFixture(setupFixture);
      const investor = user;
      const balance = 100n;

      await expect(
        intellToken.connect(investor).addInvestor(investor, balance)
      ).to.be.revertedWithCustomError(
        intellToken,
        "AccessControlUnauthorizedAccount"
      );

      await expect(
        intellToken.addInvestor(ethers.ZeroAddress, balance)
      ).to.be.revertedWith("invalid investor");

      await expect(intellToken.addInvestor(investor, 0n)).to.be.revertedWith(
        "invalid balance"
      );

      await intellToken.addInvestor(owner, INTELLTOKEN_INVESTORS_CAP);
      await expect(intellToken.addInvestor(owner, balance)).to.be.revertedWith(
        "investor already added"
      );

      await expect(
        intellToken.addInvestor(investor, balance)
      ).to.be.revertedWith("insufficient investor tokens");
    });

    it("claim investor tokens with invalid parameters", async function () {
      const { intellToken } = await loadFixture(setupFixture);

      for await (const balance of balances) {
        await intellToken.addInvestor(balance.investor, balance.balance);
      }

      await expect(
        intellToken.connect(user).claimInvestorTokens()
      ).to.be.revertedWith("not investor");

      let investor = balances[0].investor;
      await intellToken.connect(investor).claimInvestorTokens();
      await expect(
        intellToken.connect(investor).claimInvestorTokens()
      ).to.be.revertedWith("no balance");

      await intellToken.distribute(
        owner,
        INTELLTOKEN_MAX_SUPPLY - balances[0].balance
      );

      investor = balances[1].investor;
      await expect(
        intellToken.connect(investor).claimInvestorTokens()
      ).to.be.revertedWith("exceeds maximum supply");
    });
  });
});
