import { getCredentials, getEnvironment } from "./config";
import { EtoroPublicApiClient } from "./http";
import type {
  EtoroEnvironment,
  InstrumentMeta,
  PnlResponse,
} from "./types";

/**
 * High-level eToro Public API client used by Viateria in live mode.
 * Instantiated from environment credentials; demo mode bypasses this entirely.
 */
export class EtoroClient {
  private readonly api: EtoroPublicApiClient;

  constructor(private readonly environment: EtoroEnvironment = getEnvironment()) {
    this.api = new EtoroPublicApiClient(getCredentials());
  }

  /**
   * Fetch the entire account state. Despite the URL implying P&L only, this
   * returns `{ clientPortfolio }` with credit, positions, mirrors and orders.
   */
  async getPortfolio(): Promise<PnlResponse> {
    return this.api.request<PnlResponse>({
      path: `/trading/info/${this.environment}/pnl`,
    });
  }

  /**
   * Batch instrument metadata lookup. The list separator MUST be a literal comma
   * — `URLSearchParams` would percent-encode it, which the API rejects — so the
   * query string is assembled by hand.
   */
  async getInstruments(instrumentIds: number[]): Promise<InstrumentMeta[]> {
    if (instrumentIds.length === 0) return [];
    const query = `instrumentIds=${instrumentIds.join(",")}`;
    return this.api.request<InstrumentMeta[]>({
      path: `/market-data/instruments`,
      query,
    });
  }
}
