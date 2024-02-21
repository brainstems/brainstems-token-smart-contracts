BRAINSTEMS_TOKEN_NAME = "Brainstems Token";
BRAINSTEMS_TOKEN_SYMBOL = "STEMS";
BRAINSTEMS_TOKEN_STAGES = {
  WHITELISTING: 0n,
  PRIVATE_SALE: 1n,
  PUBLIC_SALE: 2n,
  FINISHED: 3n,
};
BRAINSTEMS_TOKEN_EVENTS = {
  PRICE_UPDATED: "PriceUpdated",
  ENTERED_STAGE: "EnteredStage",
  WHITELIST_UPDATED: "WhitelistUpdated",
  INVESTOR_ADDED: "InvestorAdded",
  TOKENS_PURCHASED: "TokensPurchased",
  TOKENS_CLAIMED: "TokensClaimed",
  TOKENS_DISTRIBUTED: "TokensDistributed",
  EARNINGS_CLAIMED: "EarningsClaimed",
};
BRAINSTEMS_TOKEN_MAX_SUPPLY = BigInt(1000e6) * BigInt(1e18);
BRAINSTEMS_TOKEN_INVESTORS_CAP = BigInt(100e6) * BigInt(1e18);
BRAINSTEMS_TOKEN_SALES_CAP = BigInt(70e6) * BigInt(1e18);
BRAINSTEMS_TOKEN_TO_USDC = 10n;
BRAINSTEMS_TOKEN_DECIMALS = 18;
USDCOIN_NAME = "USD Coin";
USDCOIN_SYMBOL = "USDC";
USDCOIN_DECIMALS = 6;

module.exports = {
  BRAINSTEMS_TOKEN_NAME,
  BRAINSTEMS_TOKEN_SYMBOL,
  BRAINSTEMS_TOKEN_STAGES,
  BRAINSTEMS_TOKEN_EVENTS,
  BRAINSTEMS_TOKEN_MAX_SUPPLY,
  BRAINSTEMS_TOKEN_INVESTORS_CAP,
  BRAINSTEMS_TOKEN_SALES_CAP,
  BRAINSTEMS_TOKEN_TO_USDC,
  BRAINSTEMS_TOKEN_DECIMALS,
  USDCOIN_NAME,
  USDCOIN_SYMBOL,
  USDCOIN_DECIMALS,
};
