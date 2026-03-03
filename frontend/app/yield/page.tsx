"use client";

import { useState } from "react";
import { Card, CardTitle } from "@/components/shared/Card";
import { AmountInput } from "@/components/shared/AmountInput";
import { TxButton } from "@/components/shared/TxButton";
import { StatBox } from "@/components/shared/StatBox";
import { useTokenBalance } from "@/hooks/useTokenBalance";
import { useYieldTokenizer } from "@/hooks/useYieldTokenizer";
import { useMarkets } from "@/hooks/useMarkets";
import { useAccount } from "@starknet-react/core";
import { YIELD_MATURITY } from "@/lib/constants";

const WAD = 10n ** 18n;

function formatBalance(wei: bigint): string {
  const whole = wei / WAD;
  const frac = wei % WAD;
  if (frac === 0n) return whole.toString();
  const fracStr = frac.toString().padStart(18, "0").slice(0, 4).replace(/0+$/, "");
  return `${whole}.${fracStr}`;
}

function formatMaturity(): string {
  return new Date(YIELD_MATURITY * 1000).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

export default function YieldPage() {
  const [tokenizeAmount, setTokenizeAmount] = useState("");
  const [activeTab, setActiveTab] = useState<"tokenize" | "redeem">("tokenize");
  const [selectedMarketIdx, setSelectedMarketIdx] = useState(0);

  const { address, isConnected } = useAccount();
  const { markets } = useMarkets();
  const selectedMarket = markets[selectedMarketIdx];

  // Read user's slToken balance for the selected market
  const slTokenAddr = selectedMarket?.slTokenAddress;
  const { balance: slBalance, refresh: refreshSl } = useTokenBalance(slTokenAddr, address);
  const slFormatted = formatBalance(slBalance);

  // Yield tokenizer hook — reads PT/YT balances + provides tokenize/redeem/claim
  const {
    tokenize,
    redeem,
    claimYield,
    ptBalance,
    ytBalance,
    status,
  } = useYieldTokenizer(selectedMarketIdx);

  const ptFormatted = formatBalance(ptBalance);
  const ytFormatted = formatBalance(ytBalance);

  const slSymbol = selectedMarket
    ? `sl${selectedMarket.collateralToken}`
    : "slToken";

  const canTokenize =
    isConnected &&
    tokenizeAmount !== "" &&
    Number(tokenizeAmount) > 0 &&
    slBalance > 0n;

  const canRedeem =
    isConnected &&
    tokenizeAmount !== "" &&
    Number(tokenizeAmount) > 0 &&
    ptBalance > 0n &&
    ytBalance > 0n;

  const handleTokenize = async () => {
    if (!slTokenAddr) return;
    await tokenize(tokenizeAmount, slTokenAddr);
    setTokenizeAmount("");
    refreshSl();
  };

  const handleRedeem = async () => {
    await redeem(tokenizeAmount);
    setTokenizeAmount("");
    refreshSl();
  };

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold text-white">Yield Tokenization</h1>
        <p className="text-gray-400 mt-1">
          Split slTokens into Principal (PT) and Yield (YT) tokens
        </p>
      </div>

      {/* Market selector */}
      {markets.length > 0 && (
        <div className="flex gap-2">
          {markets.map((m, i) => (
            <button
              key={m.id}
              onClick={() => {
                setSelectedMarketIdx(i);
                setTokenizeAmount("");
              }}
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors cursor-pointer ${
                selectedMarketIdx === i
                  ? "bg-emerald-600 text-white"
                  : "bg-gray-800 text-gray-400 hover:text-gray-300"
              }`}
            >
              sl{m.collateralToken}
            </button>
          ))}
        </div>
      )}

      {/* Balances */}
      <div className="grid md:grid-cols-3 gap-4">
        <Card>
          <StatBox
            label={`Your ${slSymbol} Balance`}
            value={isConnected ? slFormatted : "\u2014"}
            subValue={slSymbol}
          />
        </Card>
        <Card>
          <StatBox
            label="Your PT Balance"
            value={isConnected ? ptFormatted : "\u2014"}
            subValue={`PT-${slSymbol}`}
          />
        </Card>
        <Card>
          <StatBox
            label="Your YT Balance"
            value={isConnected ? ytFormatted : "\u2014"}
            subValue={`YT-${slSymbol}`}
          />
        </Card>
      </div>

      {/* Actions */}
      <div className="max-w-lg mx-auto">
        <Card>
          {/* Tabs */}
          <div className="flex gap-1 mb-6 bg-gray-800 rounded-lg p-1">
            <button
              onClick={() => setActiveTab("tokenize")}
              className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors cursor-pointer ${
                activeTab === "tokenize"
                  ? "bg-gray-700 text-white"
                  : "text-gray-400 hover:text-gray-300"
              }`}
            >
              Tokenize
            </button>
            <button
              onClick={() => setActiveTab("redeem")}
              className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors cursor-pointer ${
                activeTab === "redeem"
                  ? "bg-gray-700 text-white"
                  : "text-gray-400 hover:text-gray-300"
              }`}
            >
              Redeem
            </button>
          </div>

          {activeTab === "tokenize" ? (
            <div className="space-y-4">
              <AmountInput
                value={tokenizeAmount}
                onChange={setTokenizeAmount}
                label={`${slSymbol} Amount`}
                tokenSymbol={slSymbol}
                maxAmount={slBalance > 0n ? slFormatted : undefined}
              />

              <div className="space-y-2 px-1">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">You will receive</span>
                  <div className="text-right">
                    <p className="text-white">
                      {tokenizeAmount || "0"} PT-{slSymbol}
                    </p>
                    <p className="text-white">
                      {tokenizeAmount || "0"} YT-{slSymbol}
                    </p>
                  </div>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Maturity</span>
                  <span className="text-white">{formatMaturity()}</span>
                </div>
              </div>

              <TxButton
                onClick={handleTokenize}
                label="Tokenize"
                status={status}
                disabled={!canTokenize}
              />
            </div>
          ) : (
            <div className="space-y-4">
              <AmountInput
                value={tokenizeAmount}
                onChange={setTokenizeAmount}
                label="PT + YT Amount"
                tokenSymbol="PT/YT"
                maxAmount={
                  ptBalance > 0n && ytBalance > 0n
                    ? formatBalance(ptBalance < ytBalance ? ptBalance : ytBalance)
                    : undefined
                }
              />

              <div className="space-y-2 px-1">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">You will receive</span>
                  <span className="text-white">
                    {tokenizeAmount || "0"} {slSymbol}
                  </span>
                </div>
              </div>

              <TxButton
                onClick={handleRedeem}
                label="Redeem"
                status={status}
                disabled={!canRedeem}
                variant="secondary"
              />
            </div>
          )}
        </Card>
      </div>

      {/* Claim yield */}
      {ytBalance > 0n && (
        <div className="max-w-lg mx-auto">
          <Card>
            <div className="flex items-center justify-between mb-4">
              <div>
                <p className="text-white font-medium">Claim Accrued Yield</p>
                <p className="text-xs text-gray-400 mt-1">
                  YT holders earn yield until maturity. Claim your accrued interest.
                </p>
              </div>
            </div>
            <TxButton
              onClick={claimYield}
              label="Claim Yield"
              status={status}
            />
          </Card>
        </div>
      )}

      {/* How it works */}
      <Card>
        <CardTitle>How Yield Tokenization Works</CardTitle>
        <div className="mt-4 space-y-3 text-sm text-gray-400">
          <p>
            <strong className="text-white">1. Deposit collateral</strong> on the
            Lend page (transparent mode) to receive slTokens — interest-bearing
            receipt tokens that grow in value as borrowers pay APY.
          </p>
          <p>
            <strong className="text-white">2. Tokenize:</strong> Split your
            slTokens into Principal Tokens (PT) and Yield Tokens (YT). PT is
            redeemable 1:1 for the underlying at maturity. YT captures all yield
            until maturity.
          </p>
          <p>
            <strong className="text-white">3. Strategies:</strong>
          </p>
          <ul className="list-disc list-inside space-y-1 ml-2">
            <li>
              <strong className="text-gray-300">Fixed yield</strong> — Sell YT, keep
              PT. You know exactly what you get at maturity.
            </li>
            <li>
              <strong className="text-gray-300">Yield leverage</strong> — Buy YT
              cheaply. If APY rises, you earn more than you paid.
            </li>
            <li>
              <strong className="text-gray-300">Early exit</strong> — Sell PT at a
              discount, keep YT to continue earning.
            </li>
          </ul>
          <p>
            <strong className="text-white">4. Redeem:</strong> After maturity,
            PT holders redeem for the underlying. Before maturity, combine PT+YT
            to get back slTokens.
          </p>
        </div>
      </Card>
    </div>
  );
}
