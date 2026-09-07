# Viateria

Viateria is a modern **eToro portfolio dashboard & social-trading cockpit**. It
reads your entire account state from the eToro Public API and presents equity,
available cash, invested capital, open P&L, positions, copied traders (mirrors),
and pending orders in one clean view.

Built with **Next.js (App Router) + TypeScript + Tailwind CSS**.

## Demo mode (no credentials needed)

With no eToro credentials configured, Viateria runs in **demo mode**: it serves
realistic mock account data through the exact same snapshot/enrichment code paths
as live data, so the dashboard renders end-to-end out of the box. Add credentials
to switch to live data — no code changes required.

## Quick start

```bash
npm ci        # install dependencies (or: npm install)
npm run dev   # start the dev server on http://localhost:3000
```

Then open http://localhost:3000.

## Scripts

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start the Next.js dev server (port 3000). |
| `npm run build` | Production build (also type-checks and lints). |
| `npm start` | Serve the production build. |
| `npm run lint` | ESLint via `next lint`. |
| `npm run typecheck` | `tsc --noEmit`. |
| `npm run test` | Run unit tests (Vitest). |

## Configuration

Copy `.env.example` to `.env.local` and fill in what you need. Key variables:

- `ETORO_ACCESS_TOKEN` — Bearer token from the eToro OAuth flow, **or**
- `ETORO_API_KEY` + `ETORO_USER_KEY` — partner API-key pair (never combine the
  two auth families).
- `ETORO_ENV` — `demo` (default) or `real`.
- `ETORO_CLIENT_ID` / `ETORO_CLIENT_SECRET` / `ETORO_REDIRECT_URI` — enable
  "Sign in with eToro" (OAuth auth-code + PKCE).
- `VIATERIA_DEMO` — force demo mode `true`/`false` regardless of credentials.

In Cloud Agents, provide these as **Secrets** rather than committing them.

## Architecture

- `src/lib/etoro/` — the eToro integration, built to the eToro API conventions:
  - `http.ts` — Public API client (per-request `x-request-id`, Bearer **or**
    key-pair auth, `429/413/5xx` retry classes).
  - `client.ts` — typed endpoint wrappers (`/trading/info/{env}/pnl`,
    `/market-data/instruments` with literal-comma lists).
  - `snapshot.ts` — the single boundary that normalizes per-endpoint wire casing
    into Viateria's domain model, computes account aggregates, and de-duplicates
    mirror positions.
  - `sso.ts` — OAuth auth-code + PKCE against the SSO host (form-encoded).
  - `mock.ts` — demo data.
- `src/app/` — the dashboard UI and API routes (`/api/health`, `/api/portfolio`,
  `/api/auth/etoro/*`).

## The eToro data model

The entire account state comes from a single endpoint — `/trading/info/{env}/pnl`
— whose `clientPortfolio` object contains `credit`, `positions[]`, `mirrors[]`,
and `ordersForOpen[]`. Viateria computes:

- **Equity** = available cash + Σ(invested + unrealized P&L)
- **Total invested** = Σ position margin
- **Open P&L** = Σ `position.unrealizedPnL.pnL` (optional-chained; absent on
  historical positions)

Mirror positions can appear in both the top-level `positions[]` and nested under
`mirrors[]`; they are de-duplicated by `positionID` before aggregation.
