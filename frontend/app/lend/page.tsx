"use client";

import { useState } from "react";
import { Card } from "@/components/shared/Card";
import { AmountInput } from "@/components/shared/AmountInput";
import { TxButton } from "@/components/shared/TxButton";
import { PrivacyBadge } from "@/components/privacy/PrivacyBadge";
import { useShieldLend } from "@/hooks/useShieldLend";
import { useMarkets, getTokenAddress } from "@/hooks/useMarkets";
import { useTokenBalance } from "@/hooks/useTokenBalance";
import { Shield, Coins, AlertTriangle } from "lucide-react";

export default function LendPage() {
  const [depositAmount, setDepositAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [activeTab, setActiveTab] = useState<"deposit" | "withdraw">("deposit");
  const [selectedMarketId, setSelectedMarketId] = useState(0);
  const [mintStatus, setMintStatus] = useState<"idle" | "pending" | "success" | "error">("idle");
  const { markets } = useMarkets();

  const selectedMarket = markets[selectedMarketId];

  const { deposit, withdraw, mintTestTokens, status, isConnected, address, privacyMode, getDepositNotes } =
    useShieldLend(
      selectedMarket?.poolAddress,
      selectedMarket?.collateralToken,
      selectedMarket?.loanToken
    );

  const collateralTokenAddr = selectedMarket ? getTokenAddress(selectedMarket.collateralToken) : undefined;
  const { balance: collateralBalance, formatted: collateralFormatted, refresh: refreshBalance } =
    useTokenBalance(collateralTokenAddr, address);

  // Read SL token balance (deposit receipt) for withdraw max amount
  const slTokenAddr = selectedMarket?.slTokenAddress;
  const { formatted: slFormatted } = useTokenBalance(slTokenAddr, address);

  const handleMint = async () => {
    if (!selectedMarket) return;
    setMintStatus("pending");
    try {
      await mintTestTokens(selectedMarket.collateralToken, "10");
      setMintStatus("success");
      refreshBalance();
      setTimeout(() => setMintStatus("idle"), 3000);
    } catch {
      setMintStatus("error");
      setTimeout(() => setMintStatus("idle"), 3000);
    }
  };

  const depositNotes = privacyMode === "shielded" ? getDepositNotes() : [];

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">Lend</h1>
          <p className="text-gray-400 mt-1">Deposit assets to earn yield</p>
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
                  ? "bg-emerald-600 text-white"
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
      {privacyMode === "shielded" && depositNotes.length > 0 && (
        <Card className="border-emerald-800/50 bg-emerald-950/20">
          <div className="flex items-center gap-2 mb-3">
            <Shield className="h-4 w-4 text-emerald-400" />
            <span className="text-sm font-medium text-emerald-400">
              Your Shielded Deposits ({depositNotes.length})
            </span>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between items-center text-xs bg-gray-900/50 rounded-lg px-3 py-2">
              <span className="text-gray-500">Total ({depositNotes.length} note{depositNotes.length > 1 ? "s" : ""})</span>
              <span className="text-white font-medium">
                {depositNotes.reduce((sum, n) => sum + Number(n.amount), 0)} {selectedMarket?.collateralToken}
              </span>
            </div>
          </div>
        </Card>
      )}

      {/* Balance + Testnet Faucet */}
      {isConnected && selectedMarket && (
        <Card className="border-gray-700/50 bg-gray-900/30">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400">Your Balance</span>
            <span className="text-sm text-white font-medium font-mono">
              {collateralFormatted} {selectedMarket.collateralToken}
            </span>
          </div>
          {collateralBalance === 0n && (
            <div className="flex items-center gap-2 mb-3 p-2 bg-yellow-900/20 border border-yellow-800/40 rounded-lg">
              <AlertTriangle className="h-3.5 w-3.5 text-yellow-400 flex-shrink-0" />
              <span className="text-xs text-yellow-400">
                You have no {selectedMarket.collateralToken}. Mint test tokens below before depositing.
              </span>
            </div>
          )}
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
                  : `Mint 10 ${selectedMarket.collateralToken}`}
            </button>
          </div>
        </Card>
      )}

      <Card>
        {/* Tabs */}
        <div className="flex gap-1 mb-6 bg-gray-800 rounded-lg p-1">
          <button
            onClick={() => setActiveTab("deposit")}
            className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors cursor-pointer ${
              activeTab === "deposit"
                ? "bg-gray-700 text-white"
                : "text-gray-400 hover:text-gray-300"
            }`}
          >
            Deposit
          </button>
          <button
            onClick={() => setActiveTab("withdraw")}
            className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors cursor-pointer ${
              activeTab === "withdraw"
                ? "bg-gray-700 text-white"
                : "text-gray-400 hover:text-gray-300"
            }`}
          >
            Withdraw
          </button>
        </div>

        {activeTab === "deposit" ? (
          <div className="space-y-4">
            <AmountInput
              value={depositAmount}
              onChange={setDepositAmount}
              label="Deposit Amount"
              tokenSymbol={selectedMarket?.collateralToken ?? "BTC"}
              maxAmount={collateralFormatted || "0"}
            />

            {selectedMarket && (
              <div className="space-y-2 px-1">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Supply APY</span>
                  <span className="text-emerald-400 font-medium">
                    {selectedMarket.data.supplyAPY.toFixed(2)}%
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">LTV</span>
                  <span className="text-white">
                    {(selectedMarket.ltvBps / 100).toFixed(0)}%
                  </span>
                </div>
                {privacyMode === "transparent" && (
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-400">You will receive</span>
                    <span className="text-white">
                      {depositAmount || "0"} sl{selectedMarket.collateralToken}
                    </span>
                  </div>
                )}
                {privacyMode === "shielded" && (
                  <>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-400">Mode</span>
                      <span className="text-emerald-400 flex items-center gap-1">
                        <Shield className="h-3 w-3" /> Shielded (ZK)
                      </span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-400">Output</span>
                      <span className="text-gray-300">
                        Pedersen commitment (hidden amount)
                      </span>
                    </div>
                  </>
                )}
              </div>
            )}

            <TxButton
              onClick={() => deposit(depositAmount)}
              label={
                isConnected
                  ? privacyMode === "shielded"
                    ? "Shielded Deposit"
                    : "Deposit"
                  : "Connect Wallet"
              }
              status={status}
              disabled={!depositAmount || depositAmount === "0"}
            />
          </div>
        ) : (
          <div className="space-y-4">
            {privacyMode === "shielded" && depositNotes.length === 0 && (
              <div className="text-sm text-gray-500 bg-gray-800/50 rounded-lg p-3 text-center">
                No shielded deposit notes to withdraw from.
                Make a shielded deposit first.
              </div>
            )}

            <AmountInput
              value={withdrawAmount}
              onChange={setWithdrawAmount}
              label="Withdraw Amount"
              tokenSymbol={
                selectedMarket
                  ? privacyMode === "shielded"
                    ? selectedMarket.collateralToken
                    : `sl${selectedMarket.collateralToken}`
                  : "BTC"
              }
              maxAmount={
                privacyMode === "shielded" && depositNotes.length > 0
                  ? depositNotes[0].amount
                  : slFormatted || "0"
              }
            />

            {privacyMode === "shielded" && (
              <div className="space-y-2 px-1">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Mode</span>
                  <span className="text-emerald-400 flex items-center gap-1">
                    <Shield className="h-3 w-3" /> Shielded Withdraw
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Nullifier</span>
                  <span className="text-gray-300 font-mono text-xs">
                    {depositNotes.length > 0
                      ? `${depositNotes[0].nullifier.slice(0, 10)}...`
                      : "—"}
                  </span>
                </div>
              </div>
            )}

            <TxButton
              onClick={() => withdraw(withdrawAmount)}
              label={
                isConnected
                  ? privacyMode === "shielded"
                    ? "Shielded Withdraw"
                    : "Withdraw"
                  : "Connect Wallet"
              }
              status={status}
              disabled={
                !withdrawAmount ||
                withdrawAmount === "0" ||
                (privacyMode === "shielded" && depositNotes.length === 0)
              }
              variant="secondary"
            />
          </div>
        )}
      </Card>
    </div>
  );
}
