import { describe, expect, it } from "vitest";
import { MOCK_CLIENT_PORTFOLIO } from "./mock";
import { collectPositions, computeSnapshot } from "./snapshot";
import type { ClientPortfolio } from "./types";

describe("computeSnapshot", () => {
  it("de-duplicates mirror positions that also appear at the top level", () => {
    const positions = collectPositions(MOCK_CLIENT_PORTFOLIO);
    // The mock has 5 unique positions; 900005 appears in both arrays.
    expect(positions).toHaveLength(5);
    expect(positions.filter((p) => p.positionId === 900005)).toHaveLength(1);
    expect(positions.find((p) => p.positionId === 900005)?.isMirrored).toBe(true);
  });

  it("aggregates equity, invested and P&L correctly", () => {
    const s = computeSnapshot(MOCK_CLIENT_PORTFOLIO);
    expect(s.totalInvested).toBeCloseTo(15800, 2);
    expect(s.openPnl).toBeCloseTo(2390.31, 2);
    expect(s.availableCash).toBeCloseTo(12480.55, 2);
    expect(s.equity).toBeCloseTo(30670.86, 2);
    expect(s.openPnlPct).toBeCloseTo(2390.31 / 15800, 6);
    expect(s.positionCount).toBe(5);
    expect(s.mirrorCount).toBe(1);
    expect(s.pendingOrderCount).toBe(1);
  });

  it("treats a missing unrealizedPnL object as zero P&L", () => {
    const portfolio: ClientPortfolio = {
      credit: 100,
      positions: [
        {
          positionID: 1,
          instrumentID: 1,
          isBuy: true,
          amount: 500,
          units: 1,
          openRate: 10,
          leverage: 1,
          unrealizedPnL: null,
        },
      ],
      mirrors: [],
      orders: [],
      ordersForOpen: [],
    };
    const s = computeSnapshot(portfolio);
    expect(s.openPnl).toBe(0);
    expect(s.equity).toBeCloseTo(600, 2);
  });
});
