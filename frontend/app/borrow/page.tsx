"use client";

import { useState, useMemo } from "react";
import { Card } from "@/components/shared/Card";
import { AmountInput } from "@/components/shared/AmountInput";
import { TxButton } from "@/components/shared/TxButton";
import { HealthFactor } from "@/components/shared/HealthFactor";
import { PrivacyBadge } from "@/components/privacy/PrivacyBadge";
import { useShieldLend } from "@/hooks/useShieldLend";
import { useMarkets, getTokenAddress } from "@/hooks/useMarkets";
import { useTokenBalance } from "@/hooks/useTokenBalance";
import { Shield, Coins } from "lucide-react";

const WAD = 10n ** 18n;

export default function BorrowPage() {
  const [borrowAmount, setBorrowAmount] = useState("");
  const [repayAmount, setRepayAmount] = useState("");
  const [activeTab, setActiveTab] = useState<"borrow" | "repay">("borrow");
  const [selectedMarketId, setSelectedMarketId] = useState(0);
  const [mintStatus, setMintStatus] = useState<"idle" | "pending" | "success" | "error">("idle");
  const { markets } = useMarkets();

  const selectedMarket = markets[selectedMarketId];

  const { borrow, repay, mintTestTokens, status, isConnected, address, privacyMode, getDepositNotes, getBorrowNotes } =
    useShieldLend(
      selectedMarket?.poolAddress,
      selectedMarket?.collateralToken,
      selectedMarket?.loanToken
    );

  const loanTokenAddr = selectedMarket ? getTokenAddress(selectedMarket.loanToken) : undefined;
  const { formatted: loanFormatted, refresh: refreshBalance } =
    useTokenBalance(loanTokenAddr, address);

  // Read user's SL token balance (transparent mode collateral deposit)
  const slTokenAddr = selectedMarket?.slTokenAddress;
  const { balance: slTokenBalance } = useTokenBalance(slTokenAddr, address);

  // Read user's existing debt token balance (for health factor calculation)
  const debtTokenAddr = selectedMarket?.debtTokenAddress;
  const { balance: debtTokenBalance } = useTokenBalance(debtTokenAddr, address);

  const handleMint = async () => {
    if (!selectedMarket) return;
    setMintStatus("pending");
    try {
      await mintTestTokens(selectedMarket.loanToken, "10000");
      setMintStatus("success");
      refreshBalance();
      setTimeout(() => setMintStatus("idle"), 3000);
    } catch {
      setMintStatus("error");
      setTimeout(() => setMintStatus("idle"), 3000);
    }
  };

  const depositNotes = privacyMode === "shielded" ? getDepositNotes() : [];
  const borrowNotes = privacyMode === "shielded" ? getBorrowNotes() : [];

  // Calculate max borrow based on collateral deposits, prices, and LTV
  const maxBorrowAmount = useMemo(() => {
    if (!selectedMarket) return "0";

    const { collateralPrice, loanPrice } = selectedMarket.data;
    if (collateralPrice === 0n || loanPrice === 0n) return "0";

    let collateralWei: bigint;

    if (privacyMode === "shielded") {
      // Sum all unspent deposit notes for this pool
      const totalCollateral = depositNotes.reduce(
        (sum, n) => sum + BigInt(n.amountWei),
        0n,
      );
      collateralWei = totalCollateral;
    } else {
      // Transparent: use SL token balance (1:1 with deposits)
      collateralWei = slTokenBalance;
    }

    if (collateralWei === 0n) return "0";

    // maxBorrow = collateralWei * collateralPrice * ltvBps / (10000 * loanPrice)
    const maxBorrowWei =
      (collateralWei * collateralPrice * BigInt(selectedMarket.ltvBps)) /
      (10000n * loanPrice);

    // Convert from wei to human-readable (18 decimals), truncate to 2 decimals
    const whole = maxBorrowWei / WAD;
    const frac = ((maxBorrowWei % WAD) * 100n) / WAD;
    if (frac === 0n) return whole.toString();
    return `${whole}.${frac.toString().padStart(2, "0")}`;
  }, [selectedMarket, privacyMode, depositNotes, slTokenBalance]);

  // Health factor = (collateralUSD * liquidationThreshold) / (totalDebtUSD * 10000)
  const simulatedHF = useMemo(() => {
    if (!selectedMarket || !borrowAmount || Number(borrowAmount) === 0) return Infinity;

    const { collateralPrice, loanPrice } = selectedMarket.data;
    if (collateralPrice === 0n || loanPrice === 0n) return Infinity;

    let collateralWei: bigint;
    if (privacyMode === "shielded") {
      collateralWei = depositNotes.reduce((sum, n) => sum + BigInt(n.amountWei), 0n);
    } else {
      collateralWei = slTokenBalance;
    }

    if (collateralWei === 0n) return 0;

    // Convert to human-readable USD values
    const collateralUSD = (Number(collateralWei) / 1e18) * (Number(collateralPrice) / 1e18);
    const existingDebtUSD = (Number(debtTokenBalance) / 1e18) * (Number(loanPrice) / 1e18);
    const newBorrowUSD = Number(borrowAmount) * (Number(loanPrice) / 1e18);
    const totalDebtUSD = existingDebtUSD + newBorrowUSD;

    if (totalDebtUSD <= 0) return Infinity;

    return (collateralUSD * selectedMarket.liquidationThresholdBps) / (totalDebtUSD * 10000);
  }, [selectedMarket, borrowAmount, privacyMode, depositNotes, slTokenBalance, debtTokenBalance]);

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">Borrow</h1>
          <p className="text-gray-400 mt-1">
            Borrow against your collateral
          </p>
        </div>
        <PrivacyBadge mode={privacyMode} size="md" />
      </div>

      {/* Market selector */}
      {markets.length > 0 && (
        <div className="flex gap-2">
          {markets.map((m, i) => (
            <button
              key={m.id}
              onClick={() => setSelectedMarketId(i)}
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors cursor-pointer ${
                selectedMarketId === i
                  ? "bg-orange-600 text-white"
                  : "bg-gray-800 text-gray-400 hover:text-gray-300"
              }`}
            >
              {m.collateralToken}/{m.loanToken}
              {m.isEMode && " (eMode)"}
            </button>
          ))}
        </div>
      )}

      {/* Shielded notes info */}
      {privacyMode === "shielded" && (depositNotes.length > 0 || borrowNotes.length > 0) && (
        <Card className="border-emerald-800/50 bg-emerald-950/20">
          <div className="flex items-center gap-2 mb-3">
            <Shield className="h-4 w-4 text-emerald-400" />
            <span className="text-sm font-medium text-emerald-400">
              Shielded Notes
            </span>
          </div>
          <div className="space-y-2">
            {depositNotes.length > 0 && (
              <div className="flex justify-between items-center text-xs bg-gray-900/50 rounded-lg px-3 py-2">
                <span className="text-gray-500">Collateral ({depositNotes.length} note{depositNotes.length > 1 ? "s" : ""})</span>
                <span className="text-white font-medium">
                  {depositNotes.reduce((sum, n) => sum + Number(n.amount), 0)} {selectedMarket?.collateralToken}
                </span>
              </div>
            )}
            {borrowNotes.length > 0 && (
              <div className="flex justify-between items-center text-xs bg-gray-900/50 rounded-lg px-3 py-2">
                <span className="text-orange-400">Debt ({borrowNotes.length} note{borrowNotes.length > 1 ? "s" : ""})</span>
                <span className="text-white font-medium">
                  {borrowNotes.reduce((sum, n) => sum + Number(n.amount), 0)} {selectedMarket?.loanToken}
                </span>
              </div>
            )}
          </div>
        </Card>
      )}

      {/* Balance + Testnet Faucet */}
      {isConnected && selectedMarket && (
        <Card className="border-gray-700/50 bg-gray-900/30">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400">{selectedMarket.loanToken} Balance</span>
            <span className="text-sm text-white font-medium font-mono">
              {loanFormatted} {selectedMarket.loanToken}
            </span>
          </div>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Coins className="h-4 w-4 text-yellow-400" />
              <span className="text-sm text-gray-400">
                Testnet faucet
              </span>
            </div>
            <button
              onClick={handleMint}
              disabled={mintStatus === "pending"}
              className="px-3 py-1.5 text-xs font-medium bg-yellow-600 hover:bg-yellow-500 text-white rounded-lg transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {mintStatus === "pending"
                ? "Minting..."
                : mintStatus === "success"
                  ? "Minted!"
                  : `Mint 10,000 ${selectedMarket.loanToken}`}
            </button>
          </div>
        </Card>
      )}

      <Card>
        {/* Tabs */}
        <div className="flex gap-1 mb-6 bg-gray-800 rounded-lg p-1">
          <button
            onClick={() => setActiveTab("borrow")}
            className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors cursor-pointer ${
              activeTab === "borrow"
                ? "bg-gray-700 text-white"
                : "text-gray-400 hover:text-gray-300"
            }`}
          >
            Borrow
          </button>
          <button
            onClick={() => setActiveTab("repay")}
            className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors cursor-pointer ${
              activeTab === "repay"
                ? "bg-gray-700 text-white"
                : "text-gray-400 hover:text-gray-300"
            }`}
          >
            Repay
          </button>
        </div>

        {activeTab === "borrow" ? (
          <div className="space-y-4">
            {privacyMode === "shielded" && depositNotes.length === 0 && (
              <div className="text-sm text-gray-500 bg-gray-800/50 rounded-lg p-3 text-center">
                No shielded collateral notes found.
                Make a shielded deposit on the Lend page first.
              </div>
            )}

            <AmountInput
              value={borrowAmount}
              onChange={setBorrowAmount}
              label="Borrow Amount"
              tokenSymbol={selectedMarket?.loanToken ?? "USDC"}
              maxAmount={maxBorrowAmount !== "0" ? maxBorrowAmount : undefined}
            />

            {selectedMarket && (
              <div className="space-y-3 px-1">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Borrow APY</span>
                  <span className="text-orange-400 font-medium">
                    {selectedMarket.data.borrowAPY.toFixed(2)}%
                  </span>
                </div>
                {privacyMode === "transparent" && (
                  <div className="flex justify-between text-sm items-center">
                    <span className="text-gray-400">Health Factor</span>
                    <HealthFactor value={simulatedHF} size="sm" />
                  </div>
                )}
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">LTV</span>
                  <span className="text-white">
                    {(selectedMarket.ltvBps / 100).toFixed(0)}%
                  </span>
                </div>
                {privacyMode === "shielded" && (
                  <>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-400">Mode</span>
                      <span className="text-emerald-400 flex items-center gap-1">
                        <Shield className="h-3 w-3" /> Shielded (ZK)
                      </span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-400">Solvency</span>
                      <span className="text-gray-300">
                        Verified via ZK proof (hidden on-chain)
                      </span>
                    </div>
                    {depositNotes.length > 0 && (
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-400">Collateral note</span>
                        <span className="text-gray-300 font-mono text-xs">
                          {depositNotes[0].commitment.slice(0, 10)}...
                        </span>
                      </div>
                    )}
                  </>
                )}
              </div>
            )}

            <TxButton
              onClick={() => borrow(borrowAmount)}
              label={
                isConnected
                  ? privacyMode === "shielded"
                    ? "Shielded Borrow"
                    : "Borrow"
                  : "Connect Wallet"
              }
              status={status}
              disabled={
                !borrowAmount ||
                borrowAmount === "0" ||
                (privacyMode === "shielded" && depositNotes.length === 0)
              }
            />
          </div>
        ) : (
          <div className="space-y-4">
            {privacyMode === "shielded" && borrowNotes.length === 0 && (
              <div className="text-sm text-gray-500 bg-gray-800/50 rounded-lg p-3 text-center">
                No shielded borrow notes to repay.
              </div>
            )}

            <AmountInput
              value={repayAmount}
              onChange={setRepayAmount}
              label="Repay Amount"
              tokenSymbol={selectedMarket?.loanToken ?? "USDC"}
              maxAmount={
                privacyMode === "shielded" && borrowNotes.length > 0
                  ? borrowNotes.reduce((sum, n) => sum + Number(n.amount), 0).toString()
                  : undefined
              }
            />

            {privacyMode === "shielded" && borrowNotes.length > 0 && (
              <div className="space-y-2 px-1">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Mode</span>
                  <span className="text-emerald-400 flex items-center gap-1">
                    <Shield className="h-3 w-3" /> Shielded Repay
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Debt nullifier</span>
                  <span className="text-gray-300 font-mono text-xs">
                    {borrowNotes[0].nullifier.slice(0, 10)}...
                  </span>
                </div>
              </div>
            )}

            <TxButton
              onClick={() => repay(repayAmount)}
              label={
                isConnected
                  ? privacyMode === "shielded"
                    ? "Shielded Repay"
                    : "Repay"
                  : "Connect Wallet"
              }
              status={status}
              disabled={
                !repayAmount ||
                repayAmount === "0" ||
                (privacyMode === "shielded" && borrowNotes.length === 0)
              }
              variant="secondary"
            />
          </div>
        )}
      </Card>
    </div>
  );
}
