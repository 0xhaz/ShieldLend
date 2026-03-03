"use client";

import { ReactNode, useMemo } from "react";
import { sepolia } from "@starknet-react/chains";
import {
  StarknetConfig,
  jsonRpcProvider,
  argent,
  braavos,
  useInjectedConnectors,
} from "@starknet-react/core";
import { MetaMask } from "starknetkit/metamask";

const RPC_URL =
  process.env.NEXT_PUBLIC_RPC_URL ||
  "https://starknet-sepolia.public.blastapi.io/rpc/v0_7";

function rpcProvider() {
  return jsonRpcProvider({
    rpc: () => ({ nodeUrl: RPC_URL }),
  });
}

export function StarknetProvider({ children }: { children: ReactNode }) {
  const { connectors: injected } = useInjectedConnectors({
    recommended: [argent(), braavos()],
    includeRecommended: "always",
  });

  const connectors = useMemo(
    () => [...injected, new MetaMask()],
    [injected],
  );

  return (
    <StarknetConfig
      chains={[sepolia]}
      provider={rpcProvider()}
      connectors={connectors as any}
      autoConnect
    >
      {children}
    </StarknetConfig>
  );
}
