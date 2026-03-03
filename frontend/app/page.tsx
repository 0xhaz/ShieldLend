"use client";

import Link from "next/link";
import {
  Shield,
  Zap,
  TrendingUp,
  Lock,
  ArrowRight,
} from "lucide-react";
import { Card } from "@/components/shared/Card";
import { StatBox } from "@/components/shared/StatBox";
import { useMarkets } from "@/hooks/useMarkets";
import { formatWad, formatUSD } from "@/lib/math";
import { WAD } from "@/lib/constants";

const features = [
  {
    icon: Shield,
    title: "Privacy-Native Lending",
    description:
      "Deposit and borrow BTC with ZK-powered privacy. Your position details stay hidden on-chain.",
  },
  {
    icon: Zap,
    title: "Flash Loans",
    description:
      "Uncollateralized instant loans with 0.09% fee. Both transparent and shielded modes supported.",
  },
  {
    icon: TrendingUp,
    title: "Yield Tokenization",
    description:
      "Split yield-bearing positions into Principal Tokens (PT) and Yield Tokens (YT) for advanced strategies.",
  },
  {
    icon: Lock,
    title: "Built on Starknet",
    description:
      "Leveraging Starknet's native ZK infrastructure for scalable, low-cost privacy-preserving DeFi.",
  },
];

export default function Home() {
  const { markets, loading, totalTVL, totalBorrows } = useMarkets();

  // Compute USD values from market data
  const tvlUSD = markets.reduce((sum, m) => {
    const depositValue = (m.data.totalDeposits * m.data.collateralPrice) / WAD;
    return sum + depositValue;
  }, 0n);
  const borrowsUSD = markets.reduce((sum, m) => {
    const borrowValue = (m.data.totalBorrows * m.data.loanPrice) / WAD;
    return sum + borrowValue;
  }, 0n);

  return (
    <div className="space-y-12">
      {/* Hero */}
      <section className="text-center pt-12 pb-8">
        <h1 className="text-5xl font-bold text-white mb-4">
          Privacy-Native BTC Lending
        </h1>
        <p className="text-xl text-gray-400 max-w-2xl mx-auto mb-8">
          Deposit, borrow, and earn yield on Bitcoin — with ZK-powered privacy
          on Starknet.
        </p>
        <div className="flex items-center justify-center gap-4">
          <Link
            href="/markets"
            className="flex items-center gap-2 px-6 py-3 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl transition-colors cursor-pointer"
          >
            Explore Markets
            <ArrowRight className="h-4 w-4" />
          </Link>
          <Link
            href="/lend"
            className="flex items-center gap-2 px-6 py-3 bg-gray-800 hover:bg-gray-700 text-gray-200 font-semibold rounded-xl border border-gray-700 transition-colors cursor-pointer"
          >
            Start Lending
          </Link>
        </div>
      </section>

      {/* Protocol Stats */}
      <section>
        <Card>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
            <StatBox
              label="Total Value Locked"
              value={loading ? "..." : `${formatWad(totalTVL, 2)} BTC`}
              subValue={loading ? "" : formatUSD(tvlUSD)}
            />
            <StatBox
              label="Total Borrows"
              value={loading ? "..." : `${formatWad(totalBorrows, 2)} BTC`}
              subValue={loading ? "" : formatUSD(borrowsUSD)}
            />
            <StatBox
              label="Active Markets"
              value={loading ? "..." : `${markets.length}`}
            />
            <StatBox
              label="Privacy Mode"
              value="ZK-Ready"
              subValue="Noir + Garaga"
            />
          </div>
        </Card>
      </section>

      {/* Features */}
      <section>
        <h2 className="text-2xl font-bold text-white mb-6">
          Why ShieldLend?
        </h2>
        <div className="grid md:grid-cols-2 gap-4">
          {features.map((feature) => (
            <Card key={feature.title} className="flex gap-4">
              <div className="flex-shrink-0 w-10 h-10 bg-emerald-900/40 rounded-lg flex items-center justify-center">
                <feature.icon className="h-5 w-5 text-emerald-400" />
              </div>
              <div>
                <h3 className="font-semibold text-white mb-1">
                  {feature.title}
                </h3>
                <p className="text-sm text-gray-400">{feature.description}</p>
              </div>
            </Card>
          ))}
        </div>
      </section>

      {/* Markets Preview */}
      {!loading && markets.length > 0 && (
        <section>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-2xl font-bold text-white">Top Markets</h2>
            <Link
              href="/markets"
              className="text-sm text-emerald-400 hover:text-emerald-300 flex items-center gap-1 cursor-pointer"
            >
              View all <ArrowRight className="h-3 w-3" />
            </Link>
          </div>
          <Card className="overflow-hidden p-0">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-800">
                  <th className="text-left text-xs text-gray-500 uppercase tracking-wide px-6 py-3">
                    Market
                  </th>
                  <th className="text-right text-xs text-gray-500 uppercase tracking-wide px-6 py-3">
                    Supply APY
                  </th>
                  <th className="text-right text-xs text-gray-500 uppercase tracking-wide px-6 py-3">
                    Borrow APY
                  </th>
                  <th className="text-right text-xs text-gray-500 uppercase tracking-wide px-6 py-3">
                    Utilization
                  </th>
                  <th className="text-right text-xs text-gray-500 uppercase tracking-wide px-6 py-3">
                    LTV
                  </th>
                </tr>
              </thead>
              <tbody>
                {markets.map((market) => (
                  <tr
                    key={market.id}
                    className="border-b border-gray-800/50 hover:bg-gray-800/30 transition-colors"
                  >
                    <td className="px-6 py-4">
                      <Link
                        href={`/markets/${market.id}`}
                        className="flex items-center gap-2 cursor-pointer"
                      >
                        <span className="font-medium text-white">
                          {market.collateralToken}/{market.loanToken}
                        </span>
                        {market.isEMode && (
                          <span className="text-xs bg-blue-900/40 text-blue-400 px-2 py-0.5 rounded-full">
                            eMode
                          </span>
                        )}
                      </Link>
                    </td>
                    <td className="text-right px-6 py-4 text-emerald-400 font-medium">
                      {market.data.supplyAPY.toFixed(1)}%
                    </td>
                    <td className="text-right px-6 py-4 text-orange-400 font-medium">
                      {market.data.borrowAPY.toFixed(1)}%
                    </td>
                    <td className="text-right px-6 py-4 text-gray-300">
                      {market.data.utilizationRate}%
                    </td>
                    <td className="text-right px-6 py-4 text-gray-300">
                      {(market.ltvBps / 100).toFixed(0)}%
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Card>
        </section>
      )}
    </div>
  );
}
