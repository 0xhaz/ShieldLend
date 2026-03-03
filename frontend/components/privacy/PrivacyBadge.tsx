"use client";

import { Shield, Eye } from "lucide-react";
import { cn } from "@/lib/utils";
import type { PrivacyMode } from "@/lib/types";

interface PrivacyBadgeProps {
  mode: PrivacyMode;
  size?: "sm" | "md";
}

export function PrivacyBadge({ mode, size = "sm" }: PrivacyBadgeProps) {
  const isShielded = mode === "shielded";
  const iconSize = size === "sm" ? "h-3 w-3" : "h-4 w-4";

  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full font-medium",
        size === "sm" ? "px-2 py-0.5 text-xs" : "px-3 py-1 text-sm",
        isShielded
          ? "bg-emerald-900/40 text-emerald-400"
          : "bg-gray-800 text-gray-400"
      )}
    >
      {isShielded ? (
        <Shield className={iconSize} />
      ) : (
        <Eye className={iconSize} />
      )}
      {isShielded ? "Private" : "Public"}
    </span>
  );
}
