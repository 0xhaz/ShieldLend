"use client";

import { cn } from "@/lib/utils";
import { HEALTH_FACTOR_SAFE, HEALTH_FACTOR_WARNING, HEALTH_FACTOR_DANGER } from "@/lib/constants";

interface HealthFactorProps {
  value: number;
  size?: "sm" | "md" | "lg";
}

export function HealthFactor({ value, size = "md" }: HealthFactorProps) {
  const getColor = () => {
    if (value === Infinity) return "text-emerald-400";
    if (value >= HEALTH_FACTOR_SAFE) return "text-emerald-400";
    if (value >= HEALTH_FACTOR_WARNING) return "text-yellow-400";
    if (value >= HEALTH_FACTOR_DANGER) return "text-orange-400";
    return "text-red-400";
  };

  const getLabel = () => {
    if (value === Infinity) return "Safe";
    if (value >= HEALTH_FACTOR_SAFE) return "Safe";
    if (value >= HEALTH_FACTOR_WARNING) return "Moderate";
    if (value >= HEALTH_FACTOR_DANGER) return "Risky";
    return "Liquidatable";
  };

  const displayValue = value === Infinity ? "∞" : value.toFixed(2);

  return (
    <div className="flex items-center gap-2">
      <span
        className={cn(
          "font-bold",
          getColor(),
          size === "sm" && "text-sm",
          size === "md" && "text-lg",
          size === "lg" && "text-2xl"
        )}
      >
        {displayValue}
      </span>
      <span
        className={cn(
          "text-xs font-medium rounded-full px-2 py-0.5",
          value >= HEALTH_FACTOR_SAFE && "bg-emerald-900/40 text-emerald-400",
          value < HEALTH_FACTOR_SAFE &&
            value >= HEALTH_FACTOR_WARNING &&
            "bg-yellow-900/40 text-yellow-400",
          value < HEALTH_FACTOR_WARNING &&
            value >= HEALTH_FACTOR_DANGER &&
            "bg-orange-900/40 text-orange-400",
          value < HEALTH_FACTOR_DANGER && "bg-red-900/40 text-red-400"
        )}
      >
        {getLabel()}
      </span>
    </div>
  );
}
