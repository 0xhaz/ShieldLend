"use client";

import { useState, useCallback } from "react";
import { useAccount, useSendTransaction } from "@starknet-react/core";
import { CallData, uint256, RpcProvider, type Call } from "starknet";
import type { TxStatus } from "@/lib/types";
import { useAppStore } from "@/lib/store";
import { toast } from "@/lib/toast";
import { CONTRACTS } from "@/lib/constants";
import { getTokenAddress } from "./useMarkets";

const rpcProvider = new RpcProvider({
  nodeUrl: process.env.NEXT_PUBLIC_RPC_URL || "https://starknet-sepolia.public.blastapi.io/rpc/v0_7",
});

/** Fetch the current Merkle root from the CommitmentStore contract */
async function fetchMerkleRoot(): Promise<string> {
  const result = await rpcProvider.callContract(
    {
      contractAddress: CONTRACTS.commitmentStore,
      entrypoint: "get_root",
      calldata: [],
    },
    "latest",
  );
  return result[0];
}
import {
  prepareShieldedDeposit,
  prepareShieldedWithdraw,
  prepareShieldedBorrow,
  prepareShieldedRepay,
  addNote,
  markNoteSpent,
  getUnspentNotes,
  type ShieldedNoteLocal,
} from "@/lib/shielded";

// Hook for lending interactions — branches between transparent and shielded mode
export function useShieldLend(poolAddress?: string, collateralToken?: string, loanToken?: string) {
  const { address, isConnected } = useAccount();
  const privacyMode = useAppStore((s) => s.privacyMode);
  const [status, setStatus] = useState<TxStatus>("idle");
  const { sendAsync } = useSendTransaction({ calls: [] });

  // ====== Transparent mode functions ======

  const transparentDeposit = useCallback(
    async (amount: string) => {
      if (!poolAddress || !collateralToken) throw new Error("No market selected");
      const tokenAddr = getTokenAddress(collateralToken);
      const amountWei = uint256.bnToUint256(BigInt(Math.floor(Number(amount) * 1e18)));

      const calls: Call[] = [
        {
          contractAddress: tokenAddr,
          entrypoint: "approve",
          calldata: CallData.compile([poolAddress, amountWei]),
        },
        {
          contractAddress: poolAddress,
          entrypoint: "deposit",
          calldata: CallData.compile([amountWei]),
        },
      ];
      await sendAsync(calls);
    },
    [poolAddress, collateralToken, sendAsync],
  );

  const transparentWithdraw = useCallback(
    async (amount: string) => {
      if (!poolAddress) throw new Error("No market selected");
      const amountWei = uint256.bnToUint256(BigInt(Math.floor(Number(amount) * 1e18)));

      const calls: Call[] = [
        {
          contractAddress: poolAddress,
          entrypoint: "withdraw",
          calldata: CallData.compile([amountWei]),
        },
      ];
      await sendAsync(calls);
    },
    [poolAddress, sendAsync],
  );

  const transparentBorrow = useCallback(
    async (amount: string) => {
      if (!poolAddress) throw new Error("No market selected");
      const amountWei = uint256.bnToUint256(BigInt(Math.floor(Number(amount) * 1e18)));

      const calls: Call[] = [
        {
          contractAddress: poolAddress,
          entrypoint: "borrow",
          calldata: CallData.compile([amountWei]),
        },
      ];
      await sendAsync(calls);
    },
    [poolAddress, sendAsync],
  );

  const transparentRepay = useCallback(
    async (amount: string) => {
      if (!poolAddress || !loanToken) throw new Error("No market selected");
      const tokenAddr = getTokenAddress(loanToken);
      const amountWei = uint256.bnToUint256(BigInt(Math.floor(Number(amount) * 1e18)));

      const calls: Call[] = [
        {
          contractAddress: tokenAddr,
          entrypoint: "approve",
          calldata: CallData.compile([poolAddress, amountWei]),
        },
        {
          contractAddress: poolAddress,
          entrypoint: "repay",
          calldata: CallData.compile([amountWei]),
        },
      ];
      await sendAsync(calls);
    },
    [poolAddress, loanToken, sendAsync],
  );

  // ====== Shielded mode functions ======

  const shieldedDeposit = useCallback(
    async (amount: string) => {
      if (!poolAddress || !collateralToken) throw new Error("No market selected");

      const tokenAddr = getTokenAddress(collateralToken);
      const amountWeiBn = BigInt(Math.floor(Number(amount) * 1e18));
      const amountWei = uint256.bnToUint256(amountWeiBn);

      // Generate commitment, blinding, and mock proof
      const { note, commitment, encryptedAmount, proof } =
        prepareShieldedDeposit(amount, amountWeiBn, poolAddress);

      // Multicall: approve + shielded_deposit
      const calls: Call[] = [
        {
          contractAddress: tokenAddr,
          entrypoint: "approve",
          calldata: CallData.compile([poolAddress, amountWei]),
        },
        {
          contractAddress: poolAddress,
          entrypoint: "shielded_deposit",
          calldata: CallData.compile([
            amountWei,      // amount: u256
            commitment,     // commitment: felt252
            encryptedAmount, // encrypted_amount: felt252
            proof,          // proof: Array<felt252>
          ]),
        },
      ];

      await sendAsync(calls);

      // Persist note locally after successful tx
      addNote(note);
    },
    [poolAddress, collateralToken, sendAsync],
  );

  const shieldedWithdraw = useCallback(
    async (amount: string) => {
      if (!poolAddress) throw new Error("No market selected");

      // Find an unspent deposit note for this pool
      const notes = getUnspentNotes(poolAddress, "deposit");
      if (notes.length === 0) throw new Error("No shielded deposit notes found for this pool");

      const note = notes[0]; // use first available note
      const amountWeiBn = BigInt(Math.floor(Number(amount) * 1e18));
      const amountWei = uint256.bnToUint256(amountWeiBn);

      const { nullifier, changeCommitment, proof } = prepareShieldedWithdraw(note);

      const merkleRoot = await fetchMerkleRoot();

      const calls: Call[] = [
        {
          contractAddress: poolAddress,
          entrypoint: "shielded_withdraw",
          calldata: CallData.compile([
            amountWei,        // amount: u256
            nullifier,        // nullifier: felt252
            changeCommitment, // change_commitment: felt252
            merkleRoot,       // merkle_root: felt252
            proof,            // proof: Array<felt252>
          ]),
        },
      ];

      await sendAsync(calls);

      // Mark the original note as spent
      markNoteSpent(note.commitment);
    },
    [poolAddress, sendAsync],
  );

  const shieldedBorrow = useCallback(
    async (amount: string) => {
      if (!poolAddress) throw new Error("No market selected");

      // Need a collateral deposit note to borrow against
      const depositNotes = getUnspentNotes(poolAddress, "deposit");
      if (depositNotes.length === 0) throw new Error("No shielded collateral notes found. Deposit first in shielded mode.");

      const collateralNote = depositNotes[0];
      const borrowAmountWei = BigInt(Math.floor(Number(amount) * 1e18));
      const amountWei = uint256.bnToUint256(borrowAmountWei);

      const {
        borrowNote,
        borrowCommitment,
        collateralNullifier,
        encryptedBorrowAmount,
        proof,
      } = prepareShieldedBorrow(amount, borrowAmountWei, collateralNote, poolAddress);

      const merkleRoot = await fetchMerkleRoot();

      const calls: Call[] = [
        {
          contractAddress: poolAddress,
          entrypoint: "shielded_borrow",
          calldata: CallData.compile([
            amountWei,              // amount: u256
            borrowCommitment,       // borrow_commitment: felt252
            collateralNullifier,    // collateral_nullifier: felt252
            merkleRoot,             // merkle_root: felt252
            encryptedBorrowAmount,  // encrypted_borrow_amount: felt252
            proof,                  // proof: Array<felt252>
          ]),
        },
      ];

      await sendAsync(calls);

      // Save borrow note, mark collateral note as consumed
      addNote(borrowNote);
      markNoteSpent(collateralNote.commitment);
    },
    [poolAddress, sendAsync],
  );

  const shieldedRepay = useCallback(
    async (amount: string) => {
      if (!poolAddress || !loanToken) throw new Error("No market selected");

      // Find an unspent borrow note
      const borrowNotes = getUnspentNotes(poolAddress, "borrow");
      if (borrowNotes.length === 0) throw new Error("No shielded borrow notes found for this pool");

      const borrowNote = borrowNotes[0];
      const tokenAddr = getTokenAddress(loanToken);
      const amountWeiBn = BigInt(Math.floor(Number(amount) * 1e18));
      const amountWei = uint256.bnToUint256(amountWeiBn);

      const { debtNullifier, newDebtCommitment, proof } = prepareShieldedRepay(borrowNote);

      const calls: Call[] = [
        {
          contractAddress: tokenAddr,
          entrypoint: "approve",
          calldata: CallData.compile([poolAddress, amountWei]),
        },
        {
          contractAddress: poolAddress,
          entrypoint: "shielded_repay",
          calldata: CallData.compile([
            amountWei,          // amount: u256
            debtNullifier,      // debt_nullifier: felt252
            newDebtCommitment,  // new_debt_commitment: felt252
            proof,              // proof: Array<felt252>
          ]),
        },
      ];

      await sendAsync(calls);

      // Mark borrow note as spent
      markNoteSpent(borrowNote.commitment);
    },
    [poolAddress, loanToken, sendAsync],
  );

  // ====== Unified functions that branch on privacy mode ======

  const deposit = useCallback(
    async (amount: string) => {
      if (!isConnected || !address) throw new Error("Wallet not connected");
      setStatus("pending");
      try {
        if (privacyMode === "shielded") {
          await shieldedDeposit(amount);
        } else {
          await transparentDeposit(amount);
        }
        setStatus("success");
        toast.success(
          "Deposit successful",
          `${amount} ${collateralToken} deposited${privacyMode === "shielded" ? " (shielded)" : ""}`,
        );
        setTimeout(() => setStatus("idle"), 3000);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        if (msg.includes("User rejected") || msg.includes("UserRejected")) {
          toast.error("Transaction failed", "Simulation failed — check your token balance or try minting first.");
        } else {
          toast.error("Deposit failed", msg.slice(0, 120));
        }
        setStatus("error");
        setTimeout(() => setStatus("idle"), 3000);
      }
    },
    [isConnected, address, privacyMode, collateralToken, shieldedDeposit, transparentDeposit],
  );

  const withdraw = useCallback(
    async (amount: string) => {
      if (!isConnected || !address) throw new Error("Wallet not connected");
      setStatus("pending");
      try {
        if (privacyMode === "shielded") {
          await shieldedWithdraw(amount);
        } else {
          await transparentWithdraw(amount);
        }
        setStatus("success");
        toast.success("Withdrawal successful", `${amount} withdrawn${privacyMode === "shielded" ? " (shielded)" : ""}`);
        setTimeout(() => setStatus("idle"), 3000);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        toast.error("Withdrawal failed", msg.includes("User rejected") ? "Transaction rejected by wallet." : msg.slice(0, 120));
        setStatus("error");
        setTimeout(() => setStatus("idle"), 3000);
      }
    },
    [isConnected, address, privacyMode, shieldedWithdraw, transparentWithdraw],
  );

  const borrow = useCallback(
    async (amount: string) => {
      if (!isConnected || !address) throw new Error("Wallet not connected");
      setStatus("pending");
      try {
        if (privacyMode === "shielded") {
          await shieldedBorrow(amount);
        } else {
          await transparentBorrow(amount);
        }
        setStatus("success");
        toast.success("Borrow successful", `${amount} ${loanToken} borrowed${privacyMode === "shielded" ? " (shielded)" : ""}`);
        setTimeout(() => setStatus("idle"), 3000);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        toast.error("Borrow failed", msg.includes("User rejected") ? "Transaction rejected by wallet." : msg.slice(0, 120));
        setStatus("error");
        setTimeout(() => setStatus("idle"), 3000);
      }
    },
    [isConnected, address, privacyMode, loanToken, shieldedBorrow, transparentBorrow],
  );

  const repay = useCallback(
    async (amount: string) => {
      if (!isConnected || !address) throw new Error("Wallet not connected");
      setStatus("pending");
      try {
        if (privacyMode === "shielded") {
          await shieldedRepay(amount);
        } else {
          await transparentRepay(amount);
        }
        setStatus("success");
        toast.success("Repayment successful", `${amount} ${loanToken} repaid${privacyMode === "shielded" ? " (shielded)" : ""}`);
        setTimeout(() => setStatus("idle"), 3000);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        toast.error("Repayment failed", msg.includes("User rejected") ? "Transaction rejected by wallet." : msg.slice(0, 120));
        setStatus("error");
        setTimeout(() => setStatus("idle"), 3000);
      }
    },
    [isConnected, address, privacyMode, loanToken, shieldedRepay, transparentRepay],
  );

  // Mint test tokens (faucet for testnet)
  const mintTestTokens = useCallback(
    async (tokenSymbol: string, amount: string) => {
      if (!isConnected || !address) throw new Error("Wallet not connected");

      setStatus("pending");
      try {
        const tokenAddr = getTokenAddress(tokenSymbol);
        const amountWei = uint256.bnToUint256(BigInt(Math.floor(Number(amount) * 1e18)));

        const calls: Call[] = [
          {
            contractAddress: tokenAddr,
            entrypoint: "mint",
            calldata: CallData.compile([address, amountWei]),
          },
        ];

        await sendAsync(calls);
        setStatus("success");
        toast.success("Tokens minted", `${amount} ${tokenSymbol} added to your wallet`);
        setTimeout(() => setStatus("idle"), 3000);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        toast.error("Mint failed", msg.includes("User rejected") ? "Transaction rejected by wallet." : msg.slice(0, 120));
        setStatus("error");
        setTimeout(() => setStatus("idle"), 3000);
      }
    },
    [isConnected, address, sendAsync],
  );

  // Get user's shielded notes for the current pool
  const getDepositNotes = useCallback(
    (): ShieldedNoteLocal[] => getUnspentNotes(poolAddress, "deposit"),
    [poolAddress],
  );

  const getBorrowNotes = useCallback(
    (): ShieldedNoteLocal[] => getUnspentNotes(poolAddress, "borrow"),
    [poolAddress],
  );

  return {
    deposit,
    withdraw,
    borrow,
    repay,
    mintTestTokens,
    getDepositNotes,
    getBorrowNotes,
    status,
    isConnected,
    address,
    privacyMode,
  };
}
