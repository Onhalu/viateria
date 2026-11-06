# VANDERY+ runbook

## Unapplied refund

A refund that is not applied does not change the membership and does not write `vandery_plus_webhook_events`. There is no audit row. The only record is the webhook JSON log (`vandery_plus_refund_unmatched` or `vandery_plus_refund_partial`).

FAPI receives HTTP **200** with `status: "OK"` and the `alert` field. FAPI treats 200 as delivered, so it will not retry that credit note on its own. `refund:<invoice>` is not stored, so the same credit note can be sent again after the parent paid invoice exists.

| Case | Alert | Membership | Webhook row |
| --- | --- | --- | --- |
| No parent, foreign parent, or an older invoice | `vandery_plus_refund_unmatched` | unchanged | none |
| Current invoice, amount more than 1 CZK short of the gross charge | `vandery_plus_refund_partial` | unchanged | none |
| Current invoice, gross amount within 1 CZK | none | `revoked` | `refund:<invoice>` |

After the paid invoice is recorded, replay the credit note. That second delivery can revoke. Replaying an already applied refund is idempotent and does not revoke twice.

Sandbox coverage is the Deno case `E2E sandbox unapplied refund returns 200 and leaves no trace` in `supabase/functions/_shared/vandery_plus_test.ts`. It does not call live FAPI.
