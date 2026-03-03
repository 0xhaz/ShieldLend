"use client";

import { Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";
import type { TxStatus } from "@/lib/types";

interface TxButtonProps {
  onClick: () => void;
  label: string;
  status?: TxStatus;
  disabled?: boolean;
  variant?: "primary" | "secondary" | "danger";
  className?: string;
}

export function TxButton({
  onClick,
  label,
  status = "idle",
  disabled = false,
  variant = "primary",
  className,
}: TxButtonProps) {
  const isLoading = status === "pending" || status === "confirming";

  const getLabel = () => {
    switch (status) {
      case "pending":
        return "Confirm in wallet...";
      case "confirming":
        return "Confirming...";
      case "success":
        return "Success!";
      case "error":
        return "Try again";
      default:
        return label;
    }
  };

  return (
    <button
      onClick={onClick}
      disabled={disabled || isLoading}
      className={cn(
        "w-full flex items-center justify-center gap-2 px-6 py-3 rounded-xl font-semibold text-sm transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed",
        variant === "primary" &&
          "bg-emerald-600 hover:bg-emerald-500 text-white",
        variant === "secondary" &&
          "bg-gray-800 hover:bg-gray-700 text-gray-200 border border-gray-700",
        variant === "danger" && "bg-red-600 hover:bg-red-500 text-white",
        status === "success" && "bg-emerald-700",
        className
      )}
    >
      {isLoading && <Loader2 className="h-4 w-4 animate-spin" />}
      {getLabel()}
    </button>
  );
}
