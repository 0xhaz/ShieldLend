"use client";

import { cn } from "@/lib/utils";

interface AmountInputProps {
  value: string;
  onChange: (value: string) => void;
  label: string;
  tokenSymbol: string;
  maxAmount?: string;
  disabled?: boolean;
  className?: string;
}

export function AmountInput({
  value,
  onChange,
  label,
  tokenSymbol,
  maxAmount,
  disabled = false,
  className,
}: AmountInputProps) {
  return (
    <div className={cn("rounded-xl border border-gray-700 bg-gray-800/50 p-4", className)}>
      <div className="flex items-center justify-between mb-2">
        <span className="text-xs text-gray-400">{label}</span>
        {maxAmount && (
          <button
            onClick={() => onChange(maxAmount)}
            className="text-xs text-emerald-400 hover:text-emerald-300 font-medium cursor-pointer"
          >
            Max: {maxAmount}
          </button>
        )}
      </div>
      <div className="flex items-center gap-3">
        <input
          type="text"
          inputMode="decimal"
          value={value}
          onChange={(e) => {
            const v = e.target.value;
            if (/^\d*\.?\d*$/.test(v)) {
              onChange(v);
            }
          }}
          placeholder="0.00"
          disabled={disabled}
          className="flex-1 bg-transparent text-2xl font-bold text-white placeholder-gray-600 outline-none disabled:opacity-50"
        />
        <span className="text-sm font-medium text-gray-300 bg-gray-700 px-3 py-1.5 rounded-lg">
          {tokenSymbol}
        </span>
      </div>
    </div>
  );
}
