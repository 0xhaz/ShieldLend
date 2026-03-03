"use client";

import { useState, useCallback } from "react";
import { useAccount, useSendTransaction } from "@starknet-react/core";
import { CallData, uint256, type Call } from "starknet";
import type { TxStatus } from "@/lib/types";
import { toast } from "@/lib/toast";
import { YIELD_TOKENIZERS } from "@/lib/constants";
import { useTokenBalance } from "./useTokenBalance";

export function useYieldTokenizer(marketIdx: number) {
  const { address, isConnected } = useAccount();
  const [status, setStatus] = useState<TxStatus>("idle");
  const { sendAsync } = useSendTransaction({ calls: [] });

  const config = YIELD_TOKENIZERS[marketIdx];
  const tokenizerAddr = config?.tokenizer;
  const ptAddr = config?.ptToken;
  const ytAddr = config?.ytToken;

  // Read PT and YT balances
  const { balance: ptBalance, refresh: refetchPt } = useTokenBalance(ptAddr, address);
  const { balance: ytBalance, refresh: refetchYt } = useTokenBalance(ytAddr, address);

  const tokenize = useCallback(
    async (amount: string, slTokenAddr: string) => {
      if (!isConnected || !address) throw new Error("Wallet not connected");
      if (!tokenizerAddr || tokenizerAddr === "0x0") throw new Error("Tokenizer not deployed");

      setStatus("pending");
      try {
        const amountWei = uint256.bnToUint256(BigInt(Math.floor(Number(amount) * 1e18)));

        const calls: Call[] = [
          // Approve slToken transfer to the tokenizer
          {
            contractAddress: slTokenAddr,
            entrypoint: "approve",
            calldata: CallData.compile([tokenizerAddr, amountWei]),
          },
          // Call tokenize
          {
            contractAddress: tokenizerAddr,
            entrypoint: "tokenize",
            calldata: CallData.compile([amountWei]),
          },
        ];

        await sendAsync(calls);
        setStatus("success");
        toast.success(
          "Tokenization successful",
          `Split ${amount} slTokens into PT + YT`,
        );
        refetchPt();
        refetchYt();
        setTimeout(() => setStatus("idle"), 3000);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        if (msg.includes("User rejected") || msg.includes("UserRejected")) {
          toast.error("Transaction cancelled", "Rejected by wallet.");
        } else {
          toast.error("Tokenize failed", msg.slice(0, 120));
        }
        setStatus("error");
        setTimeout(() => setStatus("idle"), 3000);
      }
    },
    [isConnected, address, tokenizerAddr, sendAsync, refetchPt, refetchYt],
  );

  const redeem = useCallback(
    async (amount: string) => {
      if (!isConnected || !address) throw new Error("Wallet not connected");
      if (!tokenizerAddr || tokenizerAddr === "0x0") throw new Error("Tokenizer not deployed");

      setStatus("pending");
      try {
        const amountWei = uint256.bnToUint256(BigInt(Math.floor(Number(amount) * 1e18)));

        // Redeem requires equal PT + YT
        const calls: Call[] = [
          {
            contractAddress: tokenizerAddr,
            entrypoint: "redeem",
            calldata: CallData.compile([amountWei, amountWei]),
          },
        ];

        await sendAsync(calls);
        setStatus("success");
        toast.success(
          "Redemption successful",
          `Redeemed ${amount} PT + YT back to slTokens`,
        );
        refetchPt();
        refetchYt();
        setTimeout(() => setStatus("idle"), 3000);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        if (msg.includes("User rejected") || msg.includes("UserRejected")) {
          toast.error("Transaction cancelled", "Rejected by wallet.");
        } else {
          toast.error("Redeem failed", msg.slice(0, 120));
        }
        setStatus("error");
        setTimeout(() => setStatus("idle"), 3000);
      }
    },
    [isConnected, address, tokenizerAddr, sendAsync, refetchPt, refetchYt],
  );

  const claimYield = useCallback(
    async () => {
      if (!isConnected || !address) throw new Error("Wallet not connected");
      if (!tokenizerAddr || tokenizerAddr === "0x0") throw new Error("Tokenizer not deployed");

      setStatus("pending");
      try {
        const calls: Call[] = [
          {
            contractAddress: tokenizerAddr,
            entrypoint: "claim_yield",
            calldata: [],
          },
        ];

        await sendAsync(calls);
        setStatus("success");
        toast.success("Yield claimed", "Accrued yield transferred to your wallet");
        setTimeout(() => setStatus("idle"), 3000);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        if (msg.includes("User rejected") || msg.includes("UserRejected")) {
          toast.error("Transaction cancelled", "Rejected by wallet.");
        } else {
          toast.error("Claim failed", msg.slice(0, 120));
        }
        setStatus("error");
        setTimeout(() => setStatus("idle"), 3000);
      }
    },
    [isConnected, address, tokenizerAddr, sendAsync],
  );

  return {
    tokenize,
    redeem,
    claimYield,
    ptBalance,
    ytBalance,
    ptAddr,
    ytAddr,
    tokenizerAddr,
    status,
    isConnected,
  };
}
