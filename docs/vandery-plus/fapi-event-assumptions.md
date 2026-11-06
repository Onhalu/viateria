# FAPI membership events

The live webhook does not read a `vandery_plus_event` custom field. Kind comes from the invoice FAPI already sends (`GET /invoices/{id}`).

These mappings follow the public invoice object (https://web.fapi.cz/api-doc/) and the paid-invoice notification. FAPI does not publish a separate membership event name. Where the payload is ambiguous, the assumption is written below and can be changed without touching challenge purchases.

| Invoice | Kind | Effect |
| --- | --- | --- |
| `type` is `credit_note` or `dobropis`, or `total` is negative | `refund` | Default pending Ondřej. Product ids are still required. A full refund of the current-period invoice revokes. A partial refund or a refund of an older invoice only logs and leaves the row alone |
| `cancelled` is true | `cancel` | `cancel_at_period_end = true`. Access lasts until `expires_at` |
| not paid, checkout still `pending` or `active` | `payment_failed` | No status change. A `pending` row stays `pending` so a later payment can activate. An `active` row is not extended and is not revoked |
| paid, and `parent` is set, or the row is already `active` or `expired` | `renew` | same row, one month from `greatest(expires_at, now())`. TODO Ondřej: a renew after a refund currently sets `status` back to `active`. Behaviour is unchanged until that decision |
| paid, no parent, row is `pending` | `paid_first` | `status = active`, `expires_at = now + 1 month` |

`parent` is the previous invoice id FAPI sets on a later periodic charge. A retry of the same invoice id is idempotent and does not add a month, even if this table would call it `renew`.

Notes (`viateria-plus:`) only find the checkout row. The item id, form id, and product code still have to match `FAPI_VANDERY_PLUS_*`. A credit note is not exempt from that product check. Its negative total is the refund amount, so it is not compared to the catalog price and it is not an amount-mismatch skip.

## Refunds

Default pending Ondřej.

`invoice.parent` must point at an invoice that already has a `paid_first` or `renew` row for the same user in `vandery_plus_webhook_events`, and that invoice must be the membership's current `fapi_invoice_id` (the period being refunded).

- A full refund of that invoice (exact cents, within 100 cents, or a 21% net/gross pair of the charged `amount_cents`) sets `status = revoked`.
- No parent, a parent that is not one of those paid events, or a parent that is an older invoice logs `{ "alert": "vandery_plus_refund_unmatched" }` and does not change the membership.
- A parent that is the current invoice, but an amount that is not a full refund, logs `{ "alert": "vandery_plus_refund_partial" }` and does not change the membership.

Replaying the same credit-note id is idempotent and does not apply the refund twice.

## Amount: net, gross, and coupons

Assumption, until FAPI confirms which field is the charged total:

- `FAPI_VANDERY_PLUS_AMOUNT_CENTS` is the **gross** price in cents (what the customer pays, VAT included).
- `invoice.total` is major units. It may be that gross total, or the **net** base when the form stores VAT separately. Czech standard VAT used for the check is **21%**.
- A match is exact, within **100 cents** (1 CZK) of rounding, or a 21% net/gross pair of those two numbers.
- A coupon or any larger gap is **not** `SKIPPED`. The webhook logs one JSON line `{ "alert": "vandery_plus_amount_mismatch", ... }` and responds `409` with `status: "AMOUNT_MISMATCH"`. Membership is not activated.
