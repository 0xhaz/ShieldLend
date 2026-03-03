"use client";

import { useMemo } from "react";
import { Card } from "@/components/shared/Card";
import { StatBox } from "@/components/shared/StatBox";
import { HealthFactor } from "@/components/shared/HealthFactor";
import { PrivacyBadge } from "@/components/privacy/PrivacyBadge";
import { useAppStore } from "@/lib/store";
import { useAccount } from "@starknet-react/core";
import { shortenAddress, formatUSD } from "@/lib/math";
import { useMarkets } from "@/hooks/useMarkets";
import { useTokenBalance } from "@/hooks/useTokenBalance";
import { loadNotes } from "@/lib/shielded";
import { WAD } from "@/lib/constants";

function formatTokenAmount(wei: bigint, decimals: number = 4): string {
  const whole = wei / WAD;
  const frac = wei % WAD;
  if (frac === 0n) return whole.toString();
  const fracStr = frac.toString().padStart(18, "0").slice(0, decimals);
  return `${whole}.${fracStr.replace(/0+$/, "")}`;
}

function formatUSDValue(amountWei: bigint, priceWad: bigint): string {
  // price is in WAD (1e18), amount is in WAD (1e18)
  // usdValue = amount * price / WAD
  const usdWei = (amountWei * priceWad) / WAD;
  const usd = Number(usdWei) / 1e18;
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(usd);
}

export default function PortfolioPage() {
  const { address, isConnected } = useAccount();
  const privacyMode = useAppStore((s) => s.privacyMode);
  const { markets } = useMarkets();

  // Read SL token balances for transparent mode (one per market)
  const { balance: sl1Balance } = useTokenBalance(markets[0]?.slTokenAddress, address);
  const { balance: sl2Balance } = useTokenBalance(markets[1]?.slTokenAddress, address);
  const { balance: sl3Balance } = useTokenBalance(markets[2]?.slTokenAddress, address);
  const slBalances = [sl1Balance, sl2Balance, sl3Balance];

  // Read debt token balances for transparent mode borrows
  const { balance: dt1Balance } = useTokenBalance(markets[0]?.debtTokenAddress, address);
  const { balance: dt2Balance } = useTokenBalance(markets[1]?.debtTokenAddress, address);
  const { balance: dt3Balance } = useTokenBalance(markets[2]?.debtTokenAddress, address);
  const debtBalances = [dt1Balance, dt2Balance, dt3Balance];

  // Build positions from actual data
  const positions = useMemo(() => {
    if (markets.length === 0) return [];

    return markets
      .map((market, idx) => {
        let depositWei = 0n;
        let borrowWei = 0n;

        if (privacyMode === "shielded") {
          // Read ALL notes from localStorage for this pool
          // Deposit notes: count ALL (spent ones are locked as collateral, not withdrawn)
          // Borrow notes: count only unspent (active debt)
          const allNotes = loadNotes().filter((n) => n.pool === market.poolAddress);
          const depositNotes = allNotes.filter((n) => n.noteType === "deposit");
          const activeBorrows = allNotes.filter((n) => n.noteType === "borrow" && !n.spent);
          const repaidBorrows = allNotes.filter((n) => n.noteType === "borrow" && n.spent);

          // Deposited collateral = all deposits minus those freed by repayments
          // Each repaid borrow freed one spent deposit note
          const lockedDeposits = depositNotes.filter((n) => n.spent).length;
          const freedByRepay = repaidBorrows.length;
          const stillLockedCount = Math.max(0, lockedDeposits - freedByRepay);

          // Free deposits (unspent) + still-locked deposits
          const freeDeposits = depositNotes.filter((n) => !n.spent);
          const lockedDepositNotes = depositNotes
            .filter((n) => n.spent)
            .slice(0, stillLockedCount);

          depositWei = [...freeDeposits, ...lockedDepositNotes].reduce(
            (s, n) => s + BigInt(n.amountWei), 0n,
          );
          borrowWei = activeBorrows.reduce(
            (s, n) => s + BigInt(n.amountWei), 0n,
          );
        } else {
          // Transparent: SL token balance = deposit amount
          depositWei = slBalances[idx] ?? 0n;
          // Debt token balance = borrow amount (transparent mode)
          borrowWei = debtBalances[idx] ?? 0n;
        }

        // Skip markets with no position
        if (depositWei === 0n && borrowWei === 0n) return null;

        const { collateralPrice, loanPrice } = market.data;

        // USD values
        const depositUSD = collateralPrice > 0n
          ? (depositWei * collateralPrice) / WAD
          : 0n;
        const borrowUSD = loanPrice > 0n
          ? (borrowWei * loanPrice) / WAD
          : 0n;

        // Health factor: (collateralValue * liqThreshold) / (debtValue * 10000)
        let hf = Infinity;
        if (borrowUSD > 0n) {
          hf = Number(
            (depositUSD * BigInt(market.liquidationThresholdBps)) /
            (borrowUSD * 10000n)
          );
        }

        return {
          market: `${market.collateralToken}/${market.loanToken}`,
          deposited: `${formatTokenAmount(depositWei)} ${market.collateralToken}`,
          depositedUSD: formatUSDValue(depositWei, collateralPrice),
          borrowed: `${formatTokenAmount(borrowWei)} ${market.loanToken}`,
          borrowedUSD: formatUSDValue(borrowWei, loanPrice),
          healthFactor: hf,
          supplyAPY: market.data.supplyAPY,
          borrowAPY: market.data.borrowAPY,
          isEMode: market.isEMode,
          depositUSDRaw: depositUSD,
          borrowUSDRaw: borrowUSD,
        };
      })
      .filter((p): p is NonNullable<typeof p> => p !== null);
  }, [markets, privacyMode, slBalances, debtBalances]);

  // Summary totals
  const totals = useMemo(() => {
    let totalSuppliedUSD = 0n;
    let totalBorrowedUSD = 0n;

    for (const pos of positions) {
      totalSuppliedUSD += pos.depositUSDRaw;
      totalBorrowedUSD += pos.borrowUSDRaw;
    }

    const netWorthUSD = totalSuppliedUSD - totalBorrowedUSD;

    // Weighted net APY
    let netAPY = 0;
    if (positions.length > 0) {
      const totalSupply = Number(totalSuppliedUSD);
      const totalBorrow = Number(totalBorrowedUSD);
      let supplyYield = 0;
      let borrowCost = 0;
      for (const pos of positions) {
        supplyYield += Number(pos.depositUSDRaw) * pos.supplyAPY;
        borrowCost += Number(pos.borrowUSDRaw) * pos.borrowAPY;
      }
      if (totalSupply > 0) {
        netAPY = (supplyYield - borrowCost) / totalSupply;
      }
    }

    return {
      netWorth: formatUSDValue(netWorthUSD, WAD),
      totalSupplied: formatUSDValue(totalSuppliedUSD, WAD),
      totalBorrowed: formatUSDValue(totalBorrowedUSD, WAD),
      netAPY: `${netAPY.toFixed(1)}%`,
    };
  }, [positions]);

  if (!isConnected) {
    return (
      <div className="text-center py-24">
        <h2 className="text-2xl font-bold text-white mb-4">Your Portfolio</h2>
        <p className="text-gray-400 mb-6">
          Connect your wallet to view your positions
        </p>
        <div className="inline-flex items-center gap-2 px-6 py-3 bg-gray-800 text-gray-400 rounded-xl border border-gray-700">
          No wallet connected
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">Portfolio</h1>
          <p className="text-gray-400 mt-1">
            {address ? shortenAddress(address) : ""} positions
          </p>
        </div>
        <PrivacyBadge mode={privacyMode} size="md" />
      </div>

      {/* Summary */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <StatBox label="Net Worth" value={totals.netWorth} />
        </Card>
        <Card>
          <StatBox label="Total Supplied" value={totals.totalSupplied} />
        </Card>
        <Card>
          <StatBox label="Total Borrowed" value={totals.totalBorrowed} />
        </Card>
        <Card>
          <StatBox label="Net APY" value={totals.netAPY} />
        </Card>
      </div>

      {/* Positions */}
      <div>
        <h2 className="text-xl font-bold text-white mb-4">Active Positions</h2>
        {positions.length === 0 ? (
          <Card>
            <p className="text-center text-gray-500 py-6">
              No active positions. Deposit collateral on the Lend page to get started.
            </p>
          </Card>
        ) : (
          <div className="space-y-4">
            {positions.map((pos) => (
              <Card key={pos.market}>
                <div className="flex items-center justify-between mb-4">
                  <span className="text-lg font-semibold text-white">
                    {pos.market}
                  </span>
                  <HealthFactor value={pos.healthFactor} size="sm" />
                </div>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div>
                    <p className="text-xs text-gray-500 uppercase">Deposited</p>
                    <p className="text-white font-medium">{pos.deposited}</p>
                    <p className="text-xs text-gray-400">{pos.depositedUSD}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 uppercase">Borrowed</p>
                    <p className="text-white font-medium">{pos.borrowed}</p>
                    <p className="text-xs text-gray-400">{pos.borrowedUSD}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 uppercase">Supply APY</p>
                    <p className="text-emerald-400 font-medium">
                      {pos.supplyAPY.toFixed(1)}%
                    </p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 uppercase">Borrow APY</p>
                    <p className="text-orange-400 font-medium">
                      {pos.borrowUSDRaw > 0n ? `${pos.borrowAPY.toFixed(1)}%` : "\u2014"}
                    </p>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>

      {/* Privacy note for shielded mode */}
      {privacyMode === "shielded" && (
        <Card className="border-emerald-900/50 bg-emerald-950/20">
          <div className="flex items-start gap-3">
            <div className="text-emerald-400 text-lg">&#x1f6e1;</div>
            <div>
              <p className="text-sm text-emerald-300 font-medium">
                Shielded Mode Active
              </p>
              <p className="text-xs text-emerald-400/70 mt-1">
                Your position details are encrypted on-chain. Only you can see
                the actual amounts via client-side decryption.
              </p>
            </div>
          </div>
        </Card>
      )}
    </div>
  );
}
