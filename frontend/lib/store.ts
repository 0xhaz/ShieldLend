// Global state management with Zustand
import { create } from "zustand";
import type { PrivacyMode, TxStatus, MarketInfo, MarketData } from "./types";

interface AppState {
  // Privacy mode
  privacyMode: PrivacyMode;
  setPrivacyMode: (mode: PrivacyMode) => void;
  togglePrivacyMode: () => void;

  // Transaction status
  txStatus: TxStatus;
  txHash: string | null;
  setTxStatus: (status: TxStatus, hash?: string) => void;

  // Markets cache
  markets: (MarketInfo & { data?: MarketData })[];
  setMarkets: (markets: (MarketInfo & { data?: MarketData })[]) => void;

  // Selected market
  selectedMarketId: number | null;
  setSelectedMarketId: (id: number | null) => void;
}

export const useAppStore = create<AppState>((set) => ({
  // Privacy
  privacyMode: "transparent",
  setPrivacyMode: (mode) => set({ privacyMode: mode }),
  togglePrivacyMode: () =>
    set((state) => ({
      privacyMode:
        state.privacyMode === "transparent" ? "shielded" : "transparent",
    })),

  // Transaction
  txStatus: "idle",
  txHash: null,
  setTxStatus: (status, hash) =>
    set({ txStatus: status, txHash: hash ?? null }),

  // Markets
  markets: [],
  setMarkets: (markets) => set({ markets }),

  // Selection
  selectedMarketId: null,
  setSelectedMarketId: (id) => set({ selectedMarketId: id }),
}));
