// Shared types for the ShieldLend frontend

export interface MarketInfo {
  id: number;
  poolAddress: string;
  collateralToken: string;
  loanToken: string;
  ltvBps: number;
  liquidationThresholdBps: number;
  isActive: boolean;
  isEMode: boolean;
  slTokenAddress: string;
  debtTokenAddress: string;
}

export interface RateModelParams {
  baseRate: number;   // e.g. 2 for 2%
  slope1: number;     // e.g. 4 for 4%
  slope2: number;     // e.g. 75 for 75%
  optimalUtil: number; // e.g. 80 for 80%
}

export interface MarketData {
  totalDeposits: bigint;
  totalBorrows: bigint;
  utilizationRate: number; // 0-100
  supplyAPY: number;
  borrowAPY: number;
  collateralPrice: bigint;
  loanPrice: bigint;
  rateModel: RateModelParams;
}

export interface UserPosition {
  deposited: bigint;
  borrowed: bigint;
  healthFactor: number;
  slTokenBalance: bigint;
  debtTokenBalance: bigint;
}

export interface ShieldedNote {
  commitment: string;
  encryptedAmount: string;
  noteType: number; // 0=deposit, 1=borrow
  pool: string;
  leafIndex: number;
}

export interface YieldPosition {
  ptBalance: bigint;
  ytBalance: bigint;
  maturity: number;
  accruedYield: bigint;
}

export interface AuctionInfo {
  auctionId: number;
  seller: string;
  collateralToken: string;
  loanToken: string;
  collateralAmount: bigint;
  startPrice: bigint;
  endPrice: bigint;
  startTime: number;
  duration: number;
  isActive: boolean;
  currentPrice: bigint;
}

export type PrivacyMode = "transparent" | "shielded";

export type TxStatus = "idle" | "pending" | "confirming" | "success" | "error";
