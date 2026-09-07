import type { ClientPortfolio, InstrumentMeta } from "./types";

/**
 * Realistic mock `clientPortfolio` served in demo mode. It flows through the
 * exact same snapshot/enrichment code paths as live data, so the dashboard
 * renders end-to-end without eToro credentials.
 */
export const MOCK_CLIENT_PORTFOLIO: ClientPortfolio = {
  credit: 12480.55,
  positions: [
    {
      positionID: 900001,
      instrumentID: 1001,
      isBuy: true,
      amount: 4200.0,
      units: 22.15,
      openRate: 178.42,
      leverage: 1,
      unrealizedPnL: { pnL: 612.38 },
      openDateTime: "2026-06-02T14:31:00Z",
    },
    {
      positionID: 900002,
      instrumentID: 1002,
      isBuy: true,
      amount: 3100.0,
      units: 12.4,
      openRate: 241.1,
      leverage: 2,
      unrealizedPnL: { pnL: -284.11 },
      openDateTime: "2026-07-18T09:05:00Z",
    },
    {
      positionID: 900003,
      instrumentID: 1003,
      isBuy: true,
      amount: 5000.0,
      units: 0.081,
      openRate: 61250.0,
      leverage: 1,
      unrealizedPnL: { pnL: 1843.9 },
      openDateTime: "2026-05-11T20:44:00Z",
    },
    {
      positionID: 900004,
      instrumentID: 1004,
      isBuy: false,
      amount: 1500.0,
      units: 9.6,
      openRate: 155.8,
      leverage: 5,
      unrealizedPnL: { pnL: 121.44 },
      openDateTime: "2026-08-21T11:12:00Z",
    },
    // A mirrored position, also present under the mirror below (deduped by ID).
    {
      positionID: 900005,
      instrumentID: 1005,
      isBuy: true,
      amount: 2000.0,
      units: 5.2,
      openRate: 402.5,
      leverage: 1,
      unrealizedPnL: { pnL: 96.7 },
      parentCID: 5551234,
    },
  ],
  mirrors: [
    {
      mirrorID: 700001,
      CID: 5551234,
      parentUsername: "JeppeKirkBonde",
      amount: 2000.0,
      unrealizedPnL: 96.7,
      positions: [
        {
          positionID: 900005,
          instrumentID: 1005,
          isBuy: true,
          amount: 2000.0,
          units: 5.2,
          openRate: 402.5,
          leverage: 1,
          unrealizedPnL: { pnL: 96.7 },
          parentCID: 5551234,
        },
      ],
    },
  ],
  orders: [],
  ordersForOpen: [
    {
      orderID: 800001,
      instrumentID: 1006,
      isBuy: true,
      amount: 1000.0,
      rate: 92.5,
      leverage: 1,
    },
  ],
};

/** Static instrument metadata for the demo instrument IDs above. */
export const MOCK_INSTRUMENTS: Record<number, InstrumentMeta> = {
  1001: { instrumentID: 1001, instrumentDisplayName: "Apple", symbolFull: "AAPL" },
  1002: { instrumentID: 1002, instrumentDisplayName: "Tesla", symbolFull: "TSLA" },
  1003: { instrumentID: 1003, instrumentDisplayName: "Bitcoin", symbolFull: "BTC" },
  1004: { instrumentID: 1004, instrumentDisplayName: "Nike", symbolFull: "NKE" },
  1005: { instrumentID: 1005, instrumentDisplayName: "Microsoft", symbolFull: "MSFT" },
  1006: { instrumentID: 1006, instrumentDisplayName: "Uber", symbolFull: "UBER" },
};
