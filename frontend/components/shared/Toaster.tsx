"use client";

import { useToastStore, type ToastType } from "@/lib/toast";
import { CheckCircle, XCircle, Info, X } from "lucide-react";

const icons: Record<ToastType, typeof CheckCircle> = {
  success: CheckCircle,
  error: XCircle,
  info: Info,
};

const colors: Record<ToastType, { icon: string; border: string; bg: string }> = {
  success: {
    icon: "text-emerald-400",
    border: "border-emerald-800/60",
    bg: "bg-emerald-950/40",
  },
  error: {
    icon: "text-red-400",
    border: "border-red-800/60",
    bg: "bg-red-950/40",
  },
  info: {
    icon: "text-blue-400",
    border: "border-blue-800/60",
    bg: "bg-blue-950/40",
  },
};

export function Toaster() {
  const toasts = useToastStore((s) => s.toasts);
  const removeToast = useToastStore((s) => s.removeToast);

  if (toasts.length === 0) return null;

  return (
    <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm">
      {toasts.map((t) => {
        const Icon = icons[t.type];
        const c = colors[t.type];
        return (
          <div
            key={t.id}
            className={`flex items-start gap-3 px-4 py-3 rounded-xl border ${c.border} ${c.bg} backdrop-blur-sm shadow-lg animate-in slide-in-from-right`}
          >
            <Icon className={`h-5 w-5 mt-0.5 flex-shrink-0 ${c.icon}`} />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-white">{t.title}</p>
              {t.description && (
                <p className="text-xs text-gray-400 mt-0.5">{t.description}</p>
              )}
            </div>
            <button
              onClick={() => removeToast(t.id)}
              className="text-gray-500 hover:text-gray-300 flex-shrink-0 cursor-pointer"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        );
      })}
    </div>
  );
}
