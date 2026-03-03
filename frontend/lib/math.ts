// Client-side math utilities — mirrors contracts/src/utils/math.cairo
import { WAD, BPS, RAY } from "./constants";

export function wadMul(a: bigint, b: bigint): bigint {
  return (a * b + WAD / 2n) / WAD;
}

export function wadDiv(a: bigint, b: bigint): bigint {
  if (b === 0n) return 0n;
  return (a * WAD + b / 2n) / b;
}

export function rayMul(a: bigint, b: bigint): bigint {
  return (a * b + RAY / 2n) / RAY;
}

export function rayDiv(a: bigint, b: bigint): bigint {
  if (b === 0n) return 0n;
  return (a * RAY + b / 2n) / b;
}

export function bpsMul(value: bigint, bps: bigint): bigint {
  return (value * bps + BPS / 2n) / BPS;
}

export function utilizationRate(borrows: bigint, deposits: bigint): bigint {
  if (deposits === 0n) return 0n;
  return (borrows * BPS) / deposits;
}

export function healthFactor(
  collateralValue: bigint,
  liqThresholdBps: bigint,
  debtValue: bigint
): number {
  if (debtValue === 0n) return Infinity;
  const hf = (collateralValue * liqThresholdBps) / (debtValue * BPS);
  return Number(hf * 100n) / 100;
}

// Format helpers
export function formatWad(value: bigint, decimals: number = 4): string {
  const intPart = value / WAD;
  if (decimals <= 0) return intPart.toString();
  const fracPart = value % WAD;
  const fracStr = fracPart.toString().padStart(18, "0").slice(0, decimals);
  return `${intPart}.${fracStr}`;
}

export function parseWad(value: string): bigint {
  const [intPart, fracPart = ""] = value.split(".");
  const paddedFrac = fracPart.padEnd(18, "0").slice(0, 18);
  return BigInt(intPart) * WAD + BigInt(paddedFrac);
}

export function formatBps(bps: number | bigint): string {
  const n = typeof bps === "bigint" ? Number(bps) : bps;
  return `${(n / 100).toFixed(2)}%`;
}

export function formatUSD(value: bigint, pricePrecision: bigint = WAD): string {
  const usd = Number(value) / Number(pricePrecision);
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(usd);
}

export function shortenAddress(address: string, chars: number = 4): string {
  if (address.length < chars * 2 + 2) return address;
  return `${address.slice(0, chars + 2)}...${address.slice(-chars)}`;
}
