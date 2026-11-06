# FAPI membership events

The live webhook does not read a `vandery_plus_event` custom field. Kind comes from the invoice FAPI already sends (`GET /invoices/{id}`).

These mappings follow the public invoice object (https://web.fapi.cz/api-doc/) and the paid-invoice notification. FAPI does not publish a separate membership event name. Where the payload is ambiguous, the assumption is written below and can be changed without touching challenge purchases.

| Invoice | Kind | Effect |
| --- | --- | --- |
| `type` is `credit_note` or `dobropis` | `refund` | `status = revoked` immediately |
| `cancelled` is true | `cancel` | `cancel_at_period_end = true`. Access lasts until `expires_at` |
| not paid, checkout still `pending` or `active` | `payment_failed` | No status change. A `pending` row stays `pending` so a later payment can activate. An `active` row is not extended and is not revoked |
| paid, and `parent` is set, or the row is already `active` or `expired` | `renew` | same row, one month from `greatest(expires_at, now())` |
| paid, no parent, row is `pending` | `paid_first` | `status = active`, `expires_at = now + 1 month` |

`parent` is the previous invoice id FAPI sets on a later periodic charge. A retry of the same invoice id is idempotent and does not add a month, even if this table would call it `renew`.

Notes (`viateria-plus:`) only find the checkout row. The item id, form id, and product code still have to match `FAPI_VANDERY_PLUS_*`.

## Amount: net, gross, and coupons

Assumption, until FAPI confirms which field is the charged total:

- `FAPI_VANDERY_PLUS_AMOUNT_CENTS` is the **gross** price in cents (what the customer pays, VAT included).
- `invoice.total` is major units. It may be that gross total, or the **net** base when the form stores VAT separately. Czech standard VAT used for the check is **21%**.
- A match is exact, within **100 cents** (1 CZK) of rounding, or a 21% net/gross pair of those two numbers.
- A coupon or any larger gap is **not** `SKIPPED`. The webhook logs one JSON line `{ "alert": "vandery_plus_amount_mismatch", ... }` and responds `409` with `status: "AMOUNT_MISMATCH"`. Membership is not activated.
