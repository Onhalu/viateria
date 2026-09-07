import { clsx } from "@/lib/clsx";

export function StatCard({
  label,
  value,
  sub,
  tone = "neutral",
}: {
  label: string;
  value: string;
  sub?: string;
  tone?: "neutral" | "gain" | "loss" | "brand";
}) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5 shadow-lg shadow-black/20 backdrop-blur">
      <div className="text-xs font-medium uppercase tracking-wider text-gray-400">
        {label}
      </div>
      <div
        className={clsx(
          "mt-2 text-2xl font-semibold tabular-nums",
          tone === "gain" && "text-gain",
          tone === "loss" && "text-loss",
          tone === "brand" && "text-brand-400",
          tone === "neutral" && "text-white",
        )}
      >
        {value}
      </div>
      {sub ? <div className="mt-1 text-sm text-gray-400 tabular-nums">{sub}</div> : null}
    </div>
  );
}
