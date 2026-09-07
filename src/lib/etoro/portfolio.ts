import { EtoroClient } from "./client";
import { getEnvironment, isDemoMode } from "./config";
import { MOCK_CLIENT_PORTFOLIO, MOCK_INSTRUMENTS } from "./mock";
import {
  collectMirrors,
  collectOrders,
  collectPositions,
  computeSnapshot,
  type AccountSnapshot,
  type DomainMirror,
  type DomainOrder,
  type DomainPosition,
} from "./snapshot";
import type { ClientPortfolio, InstrumentMeta } from "./types";

export interface EnrichedPosition extends DomainPosition {
  symbol: string;
  displayName: string;
}

export interface EnrichedOrder extends DomainOrder {
  symbol: string;
  displayName: string;
}

export interface PortfolioView {
  mode: "demo" | "live";
  environment: "demo" | "real";
  generatedAt: string;
  snapshot: AccountSnapshot;
  positions: EnrichedPosition[];
  mirrors: DomainMirror[];
  orders: EnrichedOrder[];
}

function instrumentLabel(
  instrumentId: number,
  index: Map<number, InstrumentMeta>,
): { symbol: string; displayName: string } {
  const meta = index.get(instrumentId);
  return {
    symbol: meta?.symbolFull ?? `#${instrumentId}`,
    displayName: meta?.instrumentDisplayName ?? `Instrument ${instrumentId}`,
  };
}

/**
 * Load the full portfolio view. In demo mode this uses bundled mock data; in
 * live mode it calls the eToro Public API and enriches instruments via a batched
 * `/market-data/instruments` lookup.
 */
export async function getPortfolioView(): Promise<PortfolioView> {
  const demo = isDemoMode();

  let portfolio: ClientPortfolio;
  const instrumentIndex = new Map<number, InstrumentMeta>();

  if (demo) {
    portfolio = MOCK_CLIENT_PORTFOLIO;
    for (const [id, meta] of Object.entries(MOCK_INSTRUMENTS)) {
      instrumentIndex.set(Number(id), meta);
    }
  } else {
    const client = new EtoroClient();
    const res = await client.getPortfolio();
    portfolio = res.clientPortfolio;

    const ids = uniqueInstrumentIds(portfolio);
    if (ids.length > 0) {
      const metas = await client.getInstruments(ids);
      for (const meta of metas) instrumentIndex.set(meta.instrumentID, meta);
    }
  }

  const positions = collectPositions(portfolio).map((p) => ({
    ...p,
    ...instrumentLabel(p.instrumentId, instrumentIndex),
  }));
  const orders = collectOrders(portfolio).map((o) => ({
    ...o,
    ...instrumentLabel(o.instrumentId, instrumentIndex),
  }));

  return {
    mode: demo ? "demo" : "live",
    environment: getEnvironment(),
    generatedAt: new Date().toISOString(),
    snapshot: computeSnapshot(portfolio),
    positions,
    mirrors: collectMirrors(portfolio),
    orders,
  };
}

function uniqueInstrumentIds(portfolio: ClientPortfolio): number[] {
  const ids = new Set<number>();
  for (const p of collectPositions(portfolio)) ids.add(p.instrumentId);
  for (const o of collectOrders(portfolio)) ids.add(o.instrumentId);
  return [...ids];
}
