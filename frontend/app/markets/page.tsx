"use client";

import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { Card } from "@/components/shared/Card";
import { StatBox } from "@/components/shared/StatBox";
import { useMarkets } from "@/hooks/useMarkets";
import { formatWad } from "@/lib/math";

export default function MarketsPage() {
  const { markets, loading, totalTVL, totalBorrows } = useMarkets();

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold text-white">Markets</h1>
        <p className="text-gray-400 mt-1">
          Browse lending markets and interest rates
        </p>
      </div>

      {/* Summary stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <StatBox
            label="Total TVL"
            value={loading ? "..." : `${formatWad(totalTVL, 2)} BTC`}
          />
        </Card>
        <Card>
          <StatBox
            label="Total Borrows"
            value={loading ? "..." : `${formatWad(totalBorrows, 2)} BTC`}
          />
        </Card>
        <Card>
          <StatBox label="Active Markets" value={loading ? "..." : `${markets.length}`} />
        </Card>
        <Card>
          <StatBox label="Best Supply APY" value={loading ? "..." : `${Math.max(...markets.map(m => m.data.supplyAPY)).toFixed(1)}%`} />
        </Card>
      </div>

      {/* Markets Table */}
      <Card className="overflow-hidden p-0">
        <table className="w-full">
          <thead>
            <tr className="border-b border-gray-800">
              <th className="text-left text-xs text-gray-500 uppercase tracking-wide px-6 py-4">
                Market
              </th>
              <th className="text-right text-xs text-gray-500 uppercase tracking-wide px-6 py-4">
                Total Deposits
              </th>
              <th className="text-right text-xs text-gray-500 uppercase tracking-wide px-6 py-4">
                Total Borrows
              </th>
              <th className="text-right text-xs text-gray-500 uppercase tracking-wide px-6 py-4">
                Supply APY
              </th>
              <th className="text-right text-xs text-gray-500 uppercase tracking-wide px-6 py-4">
                Borrow APY
              </th>
              <th className="text-right text-xs text-gray-500 uppercase tracking-wide px-6 py-4">
                Utilization
              </th>
              <th className="text-right text-xs text-gray-500 uppercase tracking-wide px-6 py-4">
                LTV
              </th>
              <th className="px-6 py-4" />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={8} className="text-center py-12 text-gray-500">
                  Loading markets...
                </td>
              </tr>
            ) : (
              markets.map((market) => (
                <tr
                  key={market.id}
                  className="border-b border-gray-800/50 hover:bg-gray-800/30 transition-colors"
                >
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-white">
                        {market.collateralToken}/{market.loanToken}
                      </span>
                      {market.isEMode && (
                        <span className="text-xs bg-blue-900/40 text-blue-400 px-2 py-0.5 rounded-full">
                          eMode
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="text-right px-6 py-4 text-gray-300 font-mono text-sm">
                    {formatWad(market.data.totalDeposits, 1)}
                  </td>
                  <td className="text-right px-6 py-4 text-gray-300 font-mono text-sm">
                    {formatWad(market.data.totalBorrows, 1)}
                  </td>
                  <td className="text-right px-6 py-4 text-emerald-400 font-medium">
                    {market.data.supplyAPY.toFixed(2)}%
                  </td>
                  <td className="text-right px-6 py-4 text-orange-400 font-medium">
                    {market.data.borrowAPY.toFixed(2)}%
                  </td>
                  <td className="text-right px-6 py-4 text-gray-300">
                    {market.data.utilizationRate}%
                  </td>
                  <td className="text-right px-6 py-4 text-gray-300">
                    {(market.ltvBps / 100).toFixed(0)}%
                  </td>
                  <td className="px-6 py-4">
                    <Link
                      href={`/markets/${market.id}`}
                      className="text-emerald-400 hover:text-emerald-300 cursor-pointer"
                    >
                      <ArrowRight className="h-4 w-4" />
                    </Link>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </Card>
    </div>
  );
}
