"use client";

import { useEffect, useState, useCallback } from "react";
import { RpcProvider } from "starknet";
import type { MarketInfo, MarketData } from "@/lib/types";
import { MARKET_POOLS, TOKENS } from "@/lib/constants";

const RPC_URL =
  process.env.NEXT_PUBLIC_RPC_URL ||
  "https://starknet-sepolia.public.blastapi.io/rpc/v0_7";

const provider = new RpcProvider({ nodeUrl: RPC_URL });

// SL token addresses (deposit receipt tokens) — reads from .env.local
const SL_TOKENS = [
  process.env.NEXT_PUBLIC_SL_TOKEN_1 || "0x0",
  process.env.NEXT_PUBLIC_SL_TOKEN_2 || "0x0",
  process.env.NEXT_PUBLIC_SL_TOKEN_3 || "0x0",
];

// Static market configuration — pool addresses, token names, risk params
const MARKET_CONFIGS: MarketInfo[] = [
  {
    id: 1,
    poolAddress: MARKET_POOLS["strkBTC/USDC"],
    collateralToken: "strkBTC",
    loanToken: "USDC",
    ltvBps: 7500,
    liquidationThresholdBps: 8000,
    isActive: true,
    isEMode: false,
    slTokenAddress: SL_TOKENS[0],
  },
  {
    id: 2,
    poolAddress: MARKET_POOLS["tBTC/USDC"],
    collateralToken: "tBTC",
    loanToken: "USDC",
    ltvBps: 7000,
    liquidationThresholdBps: 7500,
    isActive: true,
    isEMode: false,
    slTokenAddress: SL_TOKENS[1],
  },
  {
    id: 3,
    poolAddress: MARKET_POOLS["strkBTC/tBTC"],
    collateralToken: "strkBTC",
    loanToken: "tBTC",
    ltvBps: 9500,
    liquidationThresholdBps: 9700,
    isActive: true,
    isEMode: true,
    slTokenAddress: SL_TOKENS[2],
  },
];

// Per-market rate model params (these are configured at deployment time)
const RATE_MODELS = [
  { baseRate: 2, slope1: 4, slope2: 75, optimalUtil: 80 },
  { baseRate: 3, slope1: 5, slope2: 100, optimalUtil: 75 },
  { baseRate: 1, slope1: 2, slope2: 40, optimalUtil: 90 },
];

// Default fallback data when contract reads fail
const FALLBACK_DATA: MarketData[] = [
  {
    totalDeposits: BigInt("74800000000000000000"),
    totalBorrows: BigInt("37200000000000000000"),
    utilizationRate: 50,
    supplyAPY: 3.2,
    borrowAPY: 6.8,
    collateralPrice: BigInt("67500000000000000000000"),
    loanPrice: BigInt("1000000000000000000"),
    rateModel: RATE_MODELS[0],
  },
  {
    totalDeposits: BigInt("18500000000000000000"),
    totalBorrows: BigInt("7400000000000000000"),
    utilizationRate: 40,
    supplyAPY: 2.1,
    borrowAPY: 5.4,
    collateralPrice: BigInt("67300000000000000000000"),
    loanPrice: BigInt("1000000000000000000"),
    rateModel: RATE_MODELS[1],
  },
  {
    totalDeposits: BigInt("12300000000000000000"),
    totalBorrows: BigInt("9200000000000000000"),
    utilizationRate: 75,
    supplyAPY: 1.5,
    borrowAPY: 2.0,
    collateralPrice: BigInt("67500000000000000000000"),
    loanPrice: BigInt("67300000000000000000000"),
    rateModel: RATE_MODELS[2],
  },
];

const RAY_F = 1e27; // rates from IRM are in RAY precision

/** Parse u256 from two felt hex strings (low, high) */
function feltPairToU256(low: string, high: string): bigint {
  return BigInt(low) + (BigInt(high) << 128n);
}

/**
 * Parse raw get_market_data response (14 hex felt strings = 7 u256 fields):
 *   total_deposits, total_borrows, utilization_rate_bps,
 *   borrow_rate, supply_rate, borrow_index, supply_index
 */
function parseMarketData(raw: string[], rateModelIdx: number): MarketData {
  const totalDeposits = feltPairToU256(raw[0], raw[1]);
  const totalBorrows = feltPairToU256(raw[2], raw[3]);
  const utilBps = feltPairToU256(raw[4], raw[5]);
  const borrowRate = feltPairToU256(raw[6], raw[7]);
  const supplyRate = feltPairToU256(raw[8], raw[9]);

  const borrowAPY = (Number(borrowRate) / RAY_F) * 100;
  const supplyAPY = (Number(supplyRate) / RAY_F) * 100;
  const utilizationRate = Number(utilBps) / 100; // BPS to %

  // Use fallback prices (oracle is mock — prices set at deploy time)
  const fallback = FALLBACK_DATA[rateModelIdx];

  return {
    totalDeposits,
    totalBorrows,
    utilizationRate,
    supplyAPY,
    borrowAPY,
    collateralPrice: fallback.collateralPrice,
    loanPrice: fallback.loanPrice,
    rateModel: RATE_MODELS[rateModelIdx],
  };
}

export function useMarkets() {
  const [markets, setMarkets] = useState<
    (MarketInfo & { data: MarketData })[]
  >([]);
  const [loading, setLoading] = useState(true);

  const fetchMarketData = useCallback(async () => {
    try {
      const results = await Promise.allSettled(
        MARKET_CONFIGS.map(async (config, idx) => {
          const raw = await provider.callContract(
            {
              contractAddress: config.poolAddress,
              entrypoint: "get_market_data",
              calldata: [],
            },
            "latest"
          );
          return parseMarketData(raw, idx);
        })
      );

      const combined = MARKET_CONFIGS.map((config, idx) => {
        const res = results[idx];
        const data =
          res.status === "fulfilled" ? res.value : FALLBACK_DATA[idx];
        return { ...config, data };
      });

      setMarkets(combined);
    } catch {
      // Full fallback
      setMarkets(
        MARKET_CONFIGS.map((config, idx) => ({
          ...config,
          data: FALLBACK_DATA[idx],
        }))
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchMarketData();

    // Refresh every 30 seconds
    const interval = setInterval(fetchMarketData, 30_000);
    return () => clearInterval(interval);
  }, [fetchMarketData]);

  const totalTVL = markets.reduce(
    (sum, m) => sum + m.data.totalDeposits,
    0n
  );
  const totalBorrows = markets.reduce(
    (sum, m) => sum + m.data.totalBorrows,
    0n
  );

  return { markets, loading, totalTVL, totalBorrows };
}

export function useMarket(marketId: number) {
  const { markets, loading } = useMarkets();
  const market = markets.find((m) => m.id === marketId);
  return { market, loading };
}

// Resolve token symbol to its deployed address
export function getTokenAddress(symbol: string): string {
  switch (symbol) {
    case "strkBTC":
      return TOKENS.strkBTC;
    case "tBTC":
      return TOKENS.tBTC;
    case "USDC":
      return TOKENS.USDC;
    default:
      return "0x0";
  }
}
