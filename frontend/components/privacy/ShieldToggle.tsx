"use client";

import { Shield, ShieldOff } from "lucide-react";
import { useAppStore } from "@/lib/store";
import { cn } from "@/lib/utils";

export function ShieldToggle() {
  const { privacyMode, togglePrivacyMode } = useAppStore();
  const isShielded = privacyMode === "shielded";

  return (
    <button
      onClick={togglePrivacyMode}
      className={cn(
        "flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-medium transition-all cursor-pointer",
        isShielded
          ? "bg-emerald-900/50 text-emerald-400 border border-emerald-700"
          : "bg-gray-800 text-gray-400 border border-gray-700"
      )}
      title={isShielded ? "Switch to transparent mode" : "Switch to shielded mode"}
    >
      {isShielded ? (
        <Shield className="h-3.5 w-3.5" />
      ) : (
        <ShieldOff className="h-3.5 w-3.5" />
      )}
      {isShielded ? "Shielded" : "Transparent"}
    </button>
  );
}
