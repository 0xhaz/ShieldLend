// Protocol constants — mirrors contracts/src/utils/constants.cairo
export const WAD = BigInt("1000000000000000000"); // 1e18
export const RAY = BigInt("1000000000000000000000000000"); // 1e27
export const BPS = BigInt("10000");

// Flash loan fee
export const FLASH_LOAN_FEE_BPS = 9n; // 0.09%

// Risk parameters
export const MIN_LTV_BPS = 1000n;
export const MAX_LTV_BPS = 9500n;

// eMode
export const EMODE_LTV_BPS = 9500n;
export const EMODE_LIQUIDATION_THRESHOLD_BPS = 9700n;

// Starknet network
export const CHAIN_ID = (process.env.NEXT_PUBLIC_STARKNET_NETWORK || "sepolia") as string;

// Contract addresses — reads from .env.local, falls back to 0x0
export const CONTRACTS = {
  marketFactory: process.env.NEXT_PUBLIC_MARKET_FACTORY || "0x0",
  flashLoanVault: process.env.NEXT_PUBLIC_FLASH_LOAN_VAULT || "0x0",
  liquidationEngine: process.env.NEXT_PUBLIC_LIQUIDATION_ENGINE || "0x0",
  auction: process.env.NEXT_PUBLIC_AUCTION || "0x0",
  oracle: process.env.NEXT_PUBLIC_ORACLE || "0x0",
  commitmentStore: process.env.NEXT_PUBLIC_COMMITMENT_STORE || "0x0",
  nullifierRegistry: process.env.NEXT_PUBLIC_NULLIFIER_REGISTRY || "0x0",
  zkVerifier: process.env.NEXT_PUBLIC_ZK_VERIFIER || "0x0",
} as const;

// Token addresses — reads from .env.local, falls back to 0x0
export const TOKENS = {
  strkBTC: process.env.NEXT_PUBLIC_STRK_BTC || "0x0",
  tBTC: process.env.NEXT_PUBLIC_TBTC || "0x0",
  USDC: process.env.NEXT_PUBLIC_USDC || "0x0",
} as const;

// Market pool addresses — each market has its own LendingPool
export const MARKET_POOLS = {
  "strkBTC/USDC": process.env.NEXT_PUBLIC_POOL_STRKBTC_USDC || "0x0",
  "tBTC/USDC": process.env.NEXT_PUBLIC_POOL_TBTC_USDC || "0x0",
  "strkBTC/tBTC": process.env.NEXT_PUBLIC_POOL_STRKBTC_TBTC || "0x0",
} as const;

// Token metadata
export const TOKEN_META: Record<string, { symbol: string; decimals: number; address: string }> = {
  strkBTC: { symbol: "strkBTC", decimals: 18, address: TOKENS.strkBTC },
  tBTC: { symbol: "tBTC", decimals: 18, address: TOKENS.tBTC },
  USDC: { symbol: "USDC", decimals: 18, address: TOKENS.USDC },
};

// Yield tokenizer addresses — per-market
export const YIELD_TOKENIZERS = [
  {
    tokenizer: process.env.NEXT_PUBLIC_YIELD_TOKENIZER_1 || "0x0",
    ptToken: process.env.NEXT_PUBLIC_PT_TOKEN_1 || "0x0",
    ytToken: process.env.NEXT_PUBLIC_YT_TOKEN_1 || "0x0",
  },
  {
    tokenizer: process.env.NEXT_PUBLIC_YIELD_TOKENIZER_2 || "0x0",
    ptToken: process.env.NEXT_PUBLIC_PT_TOKEN_2 || "0x0",
    ytToken: process.env.NEXT_PUBLIC_YT_TOKEN_2 || "0x0",
  },
  {
    tokenizer: process.env.NEXT_PUBLIC_YIELD_TOKENIZER_3 || "0x0",
    ptToken: process.env.NEXT_PUBLIC_PT_TOKEN_3 || "0x0",
    ytToken: process.env.NEXT_PUBLIC_YT_TOKEN_3 || "0x0",
  },
] as const;

// Maturity timestamp: June 30, 2026 00:00 UTC
export const YIELD_MATURITY = 1782777600;

// UI constants
export const HEALTH_FACTOR_SAFE = 2.0;
export const HEALTH_FACTOR_WARNING = 1.5;
export const HEALTH_FACTOR_DANGER = 1.1;
