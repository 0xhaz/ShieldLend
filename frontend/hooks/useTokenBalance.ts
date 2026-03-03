"use client";

import { useEffect, useState, useCallback } from "react";
import { RpcProvider } from "starknet";

const RPC_URL =
  process.env.NEXT_PUBLIC_RPC_URL ||
  "https://starknet-sepolia.public.blastapi.io/rpc/v0_7";

const provider = new RpcProvider({ nodeUrl: RPC_URL });

/**
 * Read an ERC20 balance_of for a given token + account.
 * Returns the balance as bigint (in wei), formatted string, and loading state.
 */
export function useTokenBalance(
  tokenAddress?: string,
  accountAddress?: string,
) {
  const [balance, setBalance] = useState<bigint>(0n);
  const [loading, setLoading] = useState(false);

  const refresh = useCallback(async () => {
    if (!tokenAddress || !accountAddress || tokenAddress === "0x0") return;
    setLoading(true);
    try {
      const result = await provider.callContract(
        {
          contractAddress: tokenAddress,
          entrypoint: "balance_of",
          calldata: [accountAddress],
        },
        "latest",
      );
      // balance_of returns u256 = 2 felts (low, high)
      const low = BigInt(result[0] ?? "0");
      const high = BigInt(result[1] ?? "0");
      setBalance(low + (high << 128n));
    } catch {
      setBalance(0n);
    } finally {
      setLoading(false);
    }
  }, [tokenAddress, accountAddress]);

  useEffect(() => {
    refresh();
    const interval = setInterval(refresh, 15_000);
    return () => clearInterval(interval);
  }, [refresh]);

  // Format to human-readable (18 decimals)
  const formatted = formatBalance(balance);

  return { balance, formatted, loading, refresh };
}

function formatBalance(wei: bigint): string {
  if (wei === 0n) return "0";
  const WAD = 10n ** 18n;
  const whole = wei / WAD;
  const frac = wei % WAD;
  if (frac === 0n) return whole.toString();
  const fracStr = frac.toString().padStart(18, "0").replace(/0+$/, "");
  return `${whole}.${fracStr.slice(0, 4)}`;
}
