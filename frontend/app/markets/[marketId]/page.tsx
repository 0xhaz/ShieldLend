"use client";

import { use, useMemo } from "react";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { Card, CardTitle } from "@/components/shared/Card";
import { StatBox } from "@/components/shared/StatBox";
import { PrivacyBadge } from "@/components/privacy/PrivacyBadge";
import { useMarket } from "@/hooks/useMarkets";
import { useAppStore } from "@/lib/store";
import { formatWad, formatBps } from "@/lib/math";
import type { RateModelParams } from "@/lib/types";

/** Compute borrow rate at a given utilization using two-slope model */
function borrowRateAt(util: number, model: RateModelParams): number {
  if (util <= model.optimalUtil) {
    return model.baseRate + (model.slope1 * util) / model.optimalUtil;
  }
  const excessUtil = util - model.optimalUtil;
  const excessMax = 100 - model.optimalUtil;
  return (
    model.baseRate +
    model.slope1 +
    (model.slope2 * excessUtil) / excessMax
  );
}

/** Generate chart points for the rate curve */
function generateRateCurve(model: RateModelParams): { util: number; borrow: number; supply: number }[] {
  const points: { util: number; borrow: number; supply: number }[] = [];
  for (let u = 0; u <= 100; u += 2) {
    const borrow = borrowRateAt(u, model);
    const supply = (borrow * u) / 100;
    points.push({ util: u, borrow, supply });
  }
  return points;
}

export default function MarketDetailPage({
  params,
}: {
  params: Promise<{ marketId: string }>;
}) {
  const { marketId } = use(params);
  const { market, loading } = useMarket(Number(marketId));
  const privacyMode = useAppStore((s) => s.privacyMode);

  const curvePoints = useMemo(
    () => (market ? generateRateCurve(market.data.rateModel) : []),
    [market],
  );

  const maxRate = useMemo(
    () => Math.ceil(Math.max(...curvePoints.map((p) => p.borrow), 10) / 10) * 10,
    [curvePoints],
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center py-24 text-gray-500">
        Loading market...
      </div>
    );
  }

  if (!market) {
    return (
      <div className="text-center py-24">
        <h2 className="text-xl font-bold text-white mb-2">Market not found</h2>
        <Link href="/markets" className="text-emerald-400 hover:text-emerald-300 cursor-pointer">
          Back to markets
        </Link>
      </div>
    );
  }

  const { rateModel } = market.data;
  const currentBorrowRate = borrowRateAt(market.data.utilizationRate, rateModel);
  const currentSupplyRate = (currentBorrowRate * market.data.utilizationRate) / 100;

  // SVG chart dimensions
  const chartW = 800;
  const chartH = 320;
  const padL = 50;
  const padR = 20;
  const padT = 20;
  const padB = 40;
  const plotW = chartW - padL - padR;
  const plotH = chartH - padT - padB;

  const toX = (util: number) => padL + (util / 100) * plotW;
  const toY = (rate: number) => padT + plotH - (rate / maxRate) * plotH;

  const borrowPath = curvePoints
    .map((p, i) => `${i === 0 ? "M" : "L"} ${toX(p.util)} ${toY(p.borrow)}`)
    .join(" ");
  const supplyPath = curvePoints
    .map((p, i) => `${i === 0 ? "M" : "L"} ${toX(p.util)} ${toY(p.supply)}`)
    .join(" ");

  // Fill area under supply curve
  const supplyFill =
    supplyPath +
    ` L ${toX(100)} ${toY(0)} L ${toX(0)} ${toY(0)} Z`;

  // Current utilization marker
  const curX = toX(market.data.utilizationRate);
  // Optimal utilization marker
  const optX = toX(rateModel.optimalUtil);

  // Y-axis labels
  const yTicks = Array.from({ length: 5 }, (_, i) => (maxRate / 4) * i);

  return (
    <div className="space-y-8">
      {/* Back + title */}
      <div>
        <Link
          href="/markets"
          className="flex items-center gap-1 text-sm text-gray-400 hover:text-gray-300 mb-4 cursor-pointer"
        >
          <ArrowLeft className="h-4 w-4" /> Back to Markets
        </Link>
        <div className="flex items-center gap-3">
          <h1 className="text-3xl font-bold text-white">
            {market.collateralToken}/{market.loanToken}
          </h1>
          {market.isEMode && (
            <span className="text-sm bg-blue-900/40 text-blue-400 px-3 py-1 rounded-full font-medium">
              eMode
            </span>
          )}
          <PrivacyBadge mode={privacyMode} size="md" />
        </div>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <StatBox
            label="Total Deposits"
            value={formatWad(market.data.totalDeposits, 2)}
            subValue={market.collateralToken}
          />
        </Card>
        <Card>
          <StatBox
            label="Total Borrows"
            value={formatWad(market.data.totalBorrows, 2)}
            subValue={market.loanToken}
          />
        </Card>
        <Card>
          <StatBox
            label="Supply APY"
            value={`${market.data.supplyAPY.toFixed(2)}%`}
            trend="up"
          />
        </Card>
        <Card>
          <StatBox
            label="Borrow APY"
            value={`${market.data.borrowAPY.toFixed(2)}%`}
          />
        </Card>
      </div>

      {/* Market parameters + Quick Actions */}
      <div className="grid md:grid-cols-2 gap-6">
        <Card>
          <CardTitle>Market Parameters</CardTitle>
          <div className="space-y-3 mt-4">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Loan-to-Value (LTV)</span>
              <span className="text-white font-medium">
                {formatBps(market.ltvBps)}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Liquidation Threshold</span>
              <span className="text-white font-medium">
                {formatBps(market.liquidationThresholdBps)}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Utilization Rate</span>
              <span className="text-white font-medium">
                {market.data.utilizationRate}%
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Pool Address</span>
              <span className="text-gray-300 font-mono text-xs break-all">
                {market.poolAddress}
              </span>
            </div>
          </div>
        </Card>

        <Card>
          <CardTitle>Quick Actions</CardTitle>
          <div className="space-y-3 mt-4">
            <Link
              href="/lend"
              className="block w-full text-center px-4 py-3 bg-emerald-600 hover:bg-emerald-500 text-white font-medium rounded-xl transition-colors cursor-pointer"
            >
              Deposit {market.collateralToken}
            </Link>
            <Link
              href="/borrow"
              className="block w-full text-center px-4 py-3 bg-gray-800 hover:bg-gray-700 text-gray-200 font-medium rounded-xl border border-gray-700 transition-colors cursor-pointer"
            >
              Borrow {market.loanToken}
            </Link>
          </div>
        </Card>
      </div>

      {/* Interest Rate Model — full-width SVG chart */}
      <Card>
        <div className="flex items-center justify-between mb-2">
          <CardTitle>Interest Rate Model</CardTitle>
          <div className="flex items-center gap-4 text-xs">
            <span className="flex items-center gap-1.5">
              <span className="w-3 h-0.5 bg-orange-400 inline-block rounded" />
              <span className="text-gray-400">Borrow APR</span>
            </span>
            <span className="flex items-center gap-1.5">
              <span className="w-3 h-0.5 bg-emerald-400 inline-block rounded" />
              <span className="text-gray-400">Supply APR</span>
            </span>
          </div>
        </div>

        {/* Rate model params */}
        <div className="flex gap-4 mb-4 text-xs text-gray-500">
          <span>Base: {rateModel.baseRate}%</span>
          <span>Slope1: {rateModel.slope1}%</span>
          <span>Slope2: {rateModel.slope2}%</span>
          <span>Optimal: {rateModel.optimalUtil}%</span>
        </div>

        <div className="w-full overflow-hidden">
          <svg
            viewBox={`0 0 ${chartW} ${chartH}`}
            className="w-full h-auto"
            preserveAspectRatio="xMidYMid meet"
          >
            {/* Grid lines */}
            {yTicks.map((tick) => (
              <g key={tick}>
                <line
                  x1={padL}
                  y1={toY(tick)}
                  x2={chartW - padR}
                  y2={toY(tick)}
                  stroke="#1e1e2a"
                  strokeWidth="1"
                />
                <text
                  x={padL - 8}
                  y={toY(tick) + 4}
                  textAnchor="end"
                  fill="#6b7280"
                  fontSize="11"
                >
                  {tick.toFixed(0)}%
                </text>
              </g>
            ))}

            {/* X-axis labels */}
            {[0, 25, 50, 75, 100].map((u) => (
              <text
                key={u}
                x={toX(u)}
                y={chartH - 8}
                textAnchor="middle"
                fill="#6b7280"
                fontSize="11"
              >
                {u}%
              </text>
            ))}
            <text
              x={chartW / 2}
              y={chartH}
              textAnchor="middle"
              fill="#4b5563"
              fontSize="11"
            >
              Utilization Rate
            </text>

            {/* Optimal utilization dashed line */}
            <line
              x1={optX}
              y1={padT}
              x2={optX}
              y2={padT + plotH}
              stroke="#374151"
              strokeWidth="1"
              strokeDasharray="4 4"
            />
            <text
              x={optX}
              y={padT - 6}
              textAnchor="middle"
              fill="#6b7280"
              fontSize="10"
            >
              Optimal ({rateModel.optimalUtil}%)
            </text>

            {/* Supply area fill */}
            <path d={supplyFill} fill="rgba(16, 185, 129, 0.08)" />

            {/* Supply curve */}
            <path
              d={supplyPath}
              fill="none"
              stroke="#34d399"
              strokeWidth="2.5"
              strokeLinecap="round"
            />

            {/* Borrow curve */}
            <path
              d={borrowPath}
              fill="none"
              stroke="#fb923c"
              strokeWidth="2.5"
              strokeLinecap="round"
            />

            {/* Current utilization vertical line */}
            <line
              x1={curX}
              y1={padT}
              x2={curX}
              y2={padT + plotH}
              stroke="#60a5fa"
              strokeWidth="1.5"
              strokeDasharray="6 3"
            />

            {/* Current borrow dot */}
            <circle
              cx={curX}
              cy={toY(currentBorrowRate)}
              r="5"
              fill="#fb923c"
              stroke="#111118"
              strokeWidth="2"
            />
            {/* Current supply dot */}
            <circle
              cx={curX}
              cy={toY(currentSupplyRate)}
              r="5"
              fill="#34d399"
              stroke="#111118"
              strokeWidth="2"
            />

            {/* Current rate labels */}
            <text
              x={curX + 10}
              y={toY(currentBorrowRate) - 8}
              fill="#fb923c"
              fontSize="11"
              fontWeight="600"
            >
              {currentBorrowRate.toFixed(1)}%
            </text>
            <text
              x={curX + 10}
              y={toY(currentSupplyRate) - 8}
              fill="#34d399"
              fontSize="11"
              fontWeight="600"
            >
              {currentSupplyRate.toFixed(1)}%
            </text>

            {/* Current utilization label */}
            <text
              x={curX}
              y={padT + plotH + 16}
              textAnchor="middle"
              fill="#60a5fa"
              fontSize="10"
              fontWeight="600"
            >
              Current ({market.data.utilizationRate}%)
            </text>
          </svg>
        </div>
      </Card>
    </div>
  );
}
