import type { ClientPortfolio, PnlPosition } from "./types";

/**
 * Viateria's internal, camelCased domain model. This is the single explicit
 * boundary where per-endpoint eToro wire casing is normalized.
 */
export interface DomainPosition {
  positionId: number;
  instrumentId: number;
  direction: "buy" | "sell";
  invested: number;
  units: number;
  openRate: number;
  leverage: number;
  /** Unrealized P&L (0 when the nested `unrealizedPnL.pnL` is absent). */
  openPnl: number;
  /** Current value = invested margin + unrealized P&L. */
  currentValue: number;
  /** Whether this position belongs to a copied trader (mirror). */
  isMirrored: boolean;
  parentCid?: number;
}

export interface DomainMirror {
  mirrorId: number;
  cid: number;
  parentUsername?: string;
  invested: number;
  openPnl: number;
}

export interface DomainOrder {
  orderId: number;
  instrumentId: number;
  direction: "buy" | "sell";
  amount: number;
  rate: number;
  leverage: number;
}

export interface AccountSnapshot {
  /** Uninvested cash (clientPortfolio.credit). */
  availableCash: number;
  /** Sum of invested margin across all open positions. */
  totalInvested: number;
  /** Aggregate unrealized P&L across all open positions. */
  openPnl: number;
  /** availableCash + Σ(invested + unrealized P&L). */
  equity: number;
  /** openPnl as a fraction of totalInvested (0 when nothing is invested). */
  openPnlPct: number;
  positionCount: number;
  mirrorCount: number;
  pendingOrderCount: number;
}

/** Extract unrealized P&L safely — the nested object can be missing/null. */
function positionPnl(p: PnlPosition): number {
  return p.unrealizedPnL?.pnL ?? 0;
}

function toDomainPosition(p: PnlPosition, isMirrored: boolean): DomainPosition {
  const openPnl = positionPnl(p);
  return {
    positionId: p.positionID,
    instrumentId: p.instrumentID,
    direction: p.isBuy ? "buy" : "sell",
    invested: p.amount,
    units: p.units,
    openRate: p.openRate,
    leverage: p.leverage,
    openPnl,
    currentValue: p.amount + openPnl,
    isMirrored,
    parentCid: p.parentCID,
  };
}

/**
 * Merge the top-level `positions[]` with any positions nested under mirrors,
 * de-duplicating by `positionID`. Mirror positions frequently appear in both
 * arrays; counting them twice would double the invested/P&L figures.
 */
export function collectPositions(portfolio: ClientPortfolio): DomainPosition[] {
  const byId = new Map<number, DomainPosition>();

  for (const p of portfolio.positions ?? []) {
    byId.set(p.positionID, toDomainPosition(p, Boolean(p.parentCID)));
  }
  for (const mirror of portfolio.mirrors ?? []) {
    for (const p of mirror.positions ?? []) {
      // Nested mirror positions win on the `isMirrored` flag but never duplicate.
      byId.set(p.positionID, toDomainPosition(p, true));
    }
  }

  return [...byId.values()];
}

export function collectMirrors(portfolio: ClientPortfolio): DomainMirror[] {
  return (portfolio.mirrors ?? []).map((m) => ({
    mirrorId: m.mirrorID,
    cid: m.CID,
    parentUsername: m.parentUsername,
    invested: m.amount,
    openPnl: m.unrealizedPnL ?? 0,
  }));
}

export function collectOrders(portfolio: ClientPortfolio): DomainOrder[] {
  const raw = [...(portfolio.ordersForOpen ?? []), ...(portfolio.orders ?? [])];
  const byId = new Map<number, DomainOrder>();
  for (const o of raw) {
    byId.set(o.orderID, {
      orderId: o.orderID,
      instrumentId: o.instrumentID,
      direction: o.isBuy ? "buy" : "sell",
      amount: o.amount,
      rate: o.rate,
      leverage: o.leverage,
    });
  }
  return [...byId.values()];
}

/** Compute account-level aggregates from a `clientPortfolio`. */
export function computeSnapshot(portfolio: ClientPortfolio): AccountSnapshot {
  const positions = collectPositions(portfolio);
  const mirrors = collectMirrors(portfolio);
  const orders = collectOrders(portfolio);

  const totalInvested = positions.reduce((sum, p) => sum + p.invested, 0);
  const openPnl = positions.reduce((sum, p) => sum + p.openPnl, 0);
  const availableCash = portfolio.credit ?? 0;
  const equity = availableCash + totalInvested + openPnl;
  const openPnlPct = totalInvested > 0 ? openPnl / totalInvested : 0;

  return {
    availableCash,
    totalInvested,
    openPnl,
    equity,
    openPnlPct,
    positionCount: positions.length,
    mirrorCount: mirrors.length,
    pendingOrderCount: orders.length,
  };
}
