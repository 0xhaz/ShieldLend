"use client";

import { useState, useRef, useEffect } from "react";
import { useAccount, useConnect, useDisconnect } from "@starknet-react/core";
import { Wallet, LogOut, ChevronDown } from "lucide-react";
import { shortenAddress } from "@/lib/math";

export function WalletConnect() {
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  // Close dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  if (isConnected && address) {
    return (
      <div className="flex items-center gap-2">
        <span className="text-sm text-emerald-400 font-mono">
          {shortenAddress(address)}
        </span>
        <button
          onClick={() => disconnect()}
          className="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors cursor-pointer"
          title="Disconnect"
        >
          <LogOut className="h-4 w-4" />
        </button>
      </div>
    );
  }

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-sm font-medium rounded-lg transition-colors cursor-pointer"
      >
        <Wallet className="h-4 w-4" />
        Connect Wallet
        <ChevronDown className={`h-3 w-3 transition-transform ${open ? "rotate-180" : ""}`} />
      </button>

      {open && (
        <div className="absolute right-0 mt-2 w-56 rounded-xl border border-gray-700 bg-gray-900 shadow-xl z-50 overflow-hidden">
          {connectors.map((connector) => (
            <button
              key={connector.id}
              onClick={() => {
                connect({ connector });
                setOpen(false);
              }}
              className="w-full flex items-center gap-3 px-4 py-3 text-sm text-gray-200 hover:bg-gray-800 transition-colors cursor-pointer"
            >
              {connector.icon ? (
                <img
                  src={typeof connector.icon === "string" ? connector.icon : connector.icon.dark}
                  alt=""
                  className="h-5 w-5 rounded"
                />
              ) : (
                <Wallet className="h-5 w-5 text-gray-500" />
              )}
              {connector.name}
            </button>
          ))}
          {connectors.length === 0 && (
            <p className="px-4 py-3 text-sm text-gray-500">
              No wallets detected
            </p>
          )}
        </div>
      )}
    </div>
  );
}
