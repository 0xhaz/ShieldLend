import { cn } from "@/lib/utils";

interface StatBoxProps {
  label: string;
  value: string;
  subValue?: string;
  trend?: "up" | "down" | "neutral";
  className?: string;
}

export function StatBox({ label, value, subValue, trend, className }: StatBoxProps) {
  return (
    <div className={cn("flex flex-col", className)}>
      <span className="text-xs text-gray-500 uppercase tracking-wide">
        {label}
      </span>
      <span className="text-2xl font-bold text-white mt-1">{value}</span>
      {subValue && (
        <span
          className={cn(
            "text-sm mt-0.5",
            trend === "up" && "text-emerald-400",
            trend === "down" && "text-red-400",
            (!trend || trend === "neutral") && "text-gray-400"
          )}
        >
          {subValue}
        </span>
      )}
    </div>
  );
}
