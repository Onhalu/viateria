import { RefreshButton } from "@/components/RefreshButton";
import { StatCard } from "@/components/StatCard";
import { isSsoConfigured } from "@/lib/etoro/config";
import { getPortfolioView } from "@/lib/etoro/portfolio";
import { clsx } from "@/lib/clsx";
import {
  formatCurrency,
  formatNumber,
  formatPercent,
  formatSignedCurrency,
} from "@/lib/format";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const view = await getPortfolioView();
  const { snapshot, positions, mirrors, orders } = view;
  const ssoReady = isSsoConfigured();

  return (
    <main className="mx-auto max-w-6xl px-6 py-10">
      <Header mode={view.mode} environment={view.environment} ssoReady={ssoReady} />

      <section className="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <StatCard label="Equity" value={formatCurrency(snapshot.equity)} tone="brand" />
        <StatCard label="Available cash" value={formatCurrency(snapshot.availableCash)} />
        <StatCard label="Total invested" value={formatCurrency(snapshot.totalInvested)} />
        <StatCard
          label="Open P&L"
          value={formatSignedCurrency(snapshot.openPnl)}
          sub={formatPercent(snapshot.openPnlPct)}
          tone={snapshot.openPnl >= 0 ? "gain" : "loss"}
        />
      </section>

      <PositionsTable positions={positions} />

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <CopiedTraders mirrors={mirrors} />
        <PendingOrders orders={orders} />
      </div>

      <Footer generatedAt={view.generatedAt} mode={view.mode} />
    </main>
  );
}

function Header({
  mode,
  environment,
  ssoReady,
}: {
  mode: "demo" | "live";
  environment: "demo" | "real";
  ssoReady: boolean;
}) {
  return (
    <header className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-gradient-to-br from-brand-400 to-brand-600 text-lg font-black text-ink-950">
          V
        </div>
        <div>
          <h1 className="text-xl font-semibold tracking-tight text-white">Viateria</h1>
          <p className="text-sm text-gray-400">eToro portfolio &amp; social-trading cockpit</p>
        </div>
      </div>

      <div className="flex items-center gap-3">
        <span
          className={clsx(
            "inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold",
            mode === "demo"
              ? "bg-amber-400/10 text-amber-300 ring-1 ring-amber-400/30"
              : "bg-gain/10 text-gain ring-1 ring-gain/30",
          )}
        >
          <span className="h-1.5 w-1.5 rounded-full bg-current" />
          {mode === "demo" ? "Demo data" : "Live"} · {environment}
        </span>
        <RefreshButton />
        <ConnectButton ssoReady={ssoReady} />
      </div>
    </header>
  );
}

function ConnectButton({ ssoReady }: { ssoReady: boolean }) {
  if (ssoReady) {
    return (
      <a
        href="/api/auth/etoro/login"
        className="inline-flex items-center gap-2 rounded-lg bg-brand-500 px-3 py-2 text-sm font-semibold text-ink-950 transition hover:bg-brand-400"
      >
        Connect eToro
      </a>
    );
  }
  return (
    <span
      title="Set ETORO_CLIENT_ID and ETORO_REDIRECT_URI to enable Sign in with eToro"
      className="inline-flex cursor-not-allowed items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-semibold text-gray-500"
    >
      Connect eToro
    </span>
  );
}

type EnrichedPosition = Awaited<ReturnType<typeof getPortfolioView>>["positions"][number];
type EnrichedOrder = Awaited<ReturnType<typeof getPortfolioView>>["orders"][number];
type Mirror = Awaited<ReturnType<typeof getPortfolioView>>["mirrors"][number];

function PositionsTable({ positions }: { positions: EnrichedPosition[] }) {
  return (
    <section className="mt-8 overflow-hidden rounded-2xl border border-white/10 bg-white/[0.02]">
      <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
        <h2 className="text-sm font-semibold text-white">Open positions</h2>
        <span className="text-xs text-gray-400">{positions.length} holdings</span>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs uppercase tracking-wider text-gray-500">
              <th className="px-5 py-3 font-medium">Instrument</th>
              <th className="px-5 py-3 font-medium">Side</th>
              <th className="px-5 py-3 text-right font-medium">Invested</th>
              <th className="px-5 py-3 text-right font-medium">Units</th>
              <th className="px-5 py-3 text-right font-medium">Open rate</th>
              <th className="px-5 py-3 text-right font-medium">P&L</th>
              <th className="px-5 py-3 text-right font-medium">Return</th>
            </tr>
          </thead>
          <tbody>
            {positions.map((p) => {
              const ret = p.invested > 0 ? p.openPnl / p.invested : 0;
              const positive = p.openPnl >= 0;
              return (
                <tr
                  key={p.positionId}
                  className="border-t border-white/5 transition hover:bg-white/[0.03]"
                >
                  <td className="px-5 py-3">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-white">{p.symbol}</span>
                      {p.isMirrored ? (
                        <span className="rounded bg-brand-500/15 px-1.5 py-0.5 text-[10px] font-semibold text-brand-400">
                          COPY
                        </span>
                      ) : null}
                    </div>
                    <div className="text-xs text-gray-500">{p.displayName}</div>
                  </td>
                  <td className="px-5 py-3">
                    <span
                      className={clsx(
                        "rounded px-2 py-0.5 text-xs font-semibold",
                        p.direction === "buy"
                          ? "bg-gain/10 text-gain"
                          : "bg-loss/10 text-loss",
                      )}
                    >
                      {p.direction === "buy" ? "BUY" : "SELL"}
                      {p.leverage > 1 ? ` ×${p.leverage}` : ""}
                    </span>
                  </td>
                  <td className="px-5 py-3 text-right tabular-nums text-gray-200">
                    {formatCurrency(p.invested)}
                  </td>
                  <td className="px-5 py-3 text-right tabular-nums text-gray-300">
                    {formatNumber(p.units)}
                  </td>
                  <td className="px-5 py-3 text-right tabular-nums text-gray-300">
                    {formatNumber(p.openRate, 2)}
                  </td>
                  <td
                    className={clsx(
                      "px-5 py-3 text-right font-semibold tabular-nums",
                      positive ? "text-gain" : "text-loss",
                    )}
                  >
                    {formatSignedCurrency(p.openPnl)}
                  </td>
                  <td
                    className={clsx(
                      "px-5 py-3 text-right tabular-nums",
                      positive ? "text-gain" : "text-loss",
                    )}
                  >
                    {formatPercent(ret)}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function CopiedTraders({ mirrors }: { mirrors: Mirror[] }) {
  return (
    <section className="rounded-2xl border border-white/10 bg-white/[0.02] p-5">
      <h2 className="text-sm font-semibold text-white">Copied traders</h2>
      {mirrors.length === 0 ? (
        <p className="mt-3 text-sm text-gray-500">No active copy relationships.</p>
      ) : (
        <ul className="mt-4 space-y-3">
          {mirrors.map((m) => {
            const positive = m.openPnl >= 0;
            return (
              <li
                key={m.mirrorId}
                className="flex items-center justify-between rounded-xl border border-white/5 bg-white/[0.02] px-4 py-3"
              >
                <div>
                  <div className="font-medium text-white">
                    {m.parentUsername ?? `CID ${m.cid}`}
                  </div>
                  <div className="text-xs text-gray-500">
                    Allocated {formatCurrency(m.invested)}
                  </div>
                </div>
                <div
                  className={clsx(
                    "text-sm font-semibold tabular-nums",
                    positive ? "text-gain" : "text-loss",
                  )}
                >
                  {formatSignedCurrency(m.openPnl)}
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}

function PendingOrders({ orders }: { orders: EnrichedOrder[] }) {
  return (
    <section className="rounded-2xl border border-white/10 bg-white/[0.02] p-5">
      <h2 className="text-sm font-semibold text-white">Pending orders</h2>
      {orders.length === 0 ? (
        <p className="mt-3 text-sm text-gray-500">No open orders waiting to trigger.</p>
      ) : (
        <ul className="mt-4 space-y-3">
          {orders.map((o) => (
            <li
              key={o.orderId}
              className="flex items-center justify-between rounded-xl border border-white/5 bg-white/[0.02] px-4 py-3"
            >
              <div>
                <div className="font-medium text-white">{o.symbol}</div>
                <div className="text-xs text-gray-500">{o.displayName}</div>
              </div>
              <div className="text-right">
                <div className="text-sm text-gray-200">
                  {o.direction === "buy" ? "Buy" : "Sell"} @ {formatNumber(o.rate, 2)}
                </div>
                <div className="text-xs text-gray-500">{formatCurrency(o.amount)}</div>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function Footer({ generatedAt, mode }: { generatedAt: string; mode: "demo" | "live" }) {
  return (
    <footer className="mt-10 border-t border-white/10 pt-6 text-xs text-gray-500">
      <p>
        Snapshot generated {new Date(generatedAt).toUTCString()} ·{" "}
        {mode === "demo"
          ? "Showing bundled demo data. Add ETORO_ACCESS_TOKEN (or ETORO_API_KEY + ETORO_USER_KEY) as secrets to switch to live data."
          : "Live data from the eToro Public API."}
      </p>
      <p className="mt-1">
        Account state is sourced from a single endpoint: /trading/info/{"{env}"}/pnl.
      </p>
    </footer>
  );
}
