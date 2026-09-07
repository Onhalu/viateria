/**
 * Wire types for the eToro Public API.
 *
 * Field-name casing varies per endpoint and responses are returned verbatim, so
 * each shape is modeled exactly as it appears on the wire (see the eToro API
 * conventions). Translation to Viateria's internal camelCase domain happens at a
 * single explicit boundary in `snapshot.ts` — never at the deserialization layer.
 */

/** A single open position as returned by `/trading/info/{env}/pnl` (capital-suffix casing). */
export interface PnlPosition {
  positionID: number;
  instrumentID: number;
  /** 1 = Buy (long), 0 = Sell (short). */
  isBuy: boolean;
  /** Invested cash / margin for this position, in account currency. */
  amount: number;
  /** Number of units held. */
  units: number;
  /** Native-currency open (entry) rate. */
  openRate: number;
  leverage: number;
  /**
   * Live unrealized P&L. Nested in an object that can be missing for
   * closed/historical positions. The inner key is `pnL` (lowercase n, capital L).
   */
  unrealizedPnL?: { pnL: number } | null;
  openDateTime?: string;
  /** Present on copied (mirror) positions — the CID of the copied trader. */
  parentCID?: number;
}

/** A copied trader ("mirror") as returned inside `clientPortfolio`. */
export interface PnlMirror {
  mirrorID: number;
  /** CID of the copied trader. */
  CID: number;
  /** Cash currently allocated to this copy relationship. */
  amount: number;
  /** Aggregate unrealized P&L across the mirror's positions. */
  unrealizedPnL?: number | null;
  parentUsername?: string;
  /** Positions belonging to this mirror (may also appear in the top-level positions[]). */
  positions?: PnlPosition[];
}

/** A pending order to open a new position (`ordersForOpen`). */
export interface PnlOrderForOpen {
  orderID: number;
  instrumentID: number;
  isBuy: boolean;
  amount: number;
  /** Trigger/limit rate. */
  rate: number;
  leverage: number;
}

/**
 * `clientPortfolio` — the entire account state returned by the PnL endpoint
 * despite the URL implying P&L only.
 */
export interface ClientPortfolio {
  /** Available cash (uninvested balance) in account currency. */
  credit: number;
  positions: PnlPosition[];
  mirrors: PnlMirror[];
  orders: PnlOrderForOpen[];
  ordersForOpen: PnlOrderForOpen[];
}

export interface PnlResponse {
  clientPortfolio: ClientPortfolio;
}

/** Instrument metadata from `/market-data/instruments` (capital `D`: instrumentID). */
export interface InstrumentMeta {
  instrumentID: number;
  instrumentDisplayName: string;
  symbolFull: string;
  instrumentTypeID?: number;
  exchangeID?: number;
  /** Selected logo/image URL. */
  imageUrl?: string;
}

export type EtoroEnvironment = "demo" | "real";
