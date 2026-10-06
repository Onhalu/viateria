# FAPI checkout + webhook

Pay CTAs open a FAPI sales form (not Stripe Checkout). Stripe edge
functions stay in the repo but are unused by the Flutter CTA path.

## Secrets

```bash
supabase secrets set FAPI_API_USERNAME="<fapi login email>"
supabase secrets set FAPI_API_KEY="<fapi API token>"

# Required. The function rejects every notification when this is unset
# or the token does not match (401, no purchase update).
supabase secrets set FAPI_WEBHOOK_SECURITY="<random string>"

# Optional: numeric IDs of FAPI custom fields (Prodej → Vlastní pole)
# so start-fapi-checkout can prefill them via fapi-form-customField-{id}.
supabase secrets set FAPI_CUSTOM_FIELD_ID_USER="<id>"
supabase secrets set FAPI_CUSTOM_FIELD_ID_CHALLENGE="<id>"
supabase secrets set FAPI_CUSTOM_FIELD_ID_REWARD="<id>"
```

`FAPI_API_TOKEN` is accepted as an alias of `FAPI_API_KEY`.
`FAPI_API_BASE` defaults to `https://api.fapi.cz`.

Never hardcode these values.

## FAPI form custom fields

Create three custom fields (hidden if FAPI allows) and add them to
**both** sales forms. Names must match so the webhook can read them
from `invoice.custom_fields[]`:

| Field name       | Value written by `start-fapi-checkout` |
| ---------------- | -------------------------------------- |
| `user_id`        | Supabase auth user id                  |
| `challenge_id`   | Challenge UUID                         |
| `reward_variant` | `diploma` or `medal_and_diploma`       |

Prefill uses [FAPI URL parameters](https://napoveda.fapi.cz/article/46-predvyplneni-prodejniho-formulare):

- `fapi-form-customField-{id}=...` when the ID secrets above are set
- `fapi-form-notes=viateria:<user_id>:<challenge_id>:<reward_variant>` always
- `fapi-form-email` when the user has an email

The webhook matches a purchase by custom-field name first, then by the
`viateria:...` notes payload. Store the public **form page** URLs on
`challenges.fapi_form_url_diploma` / `fapi_form_url_medal` (leave null
until the forms exist — the matching CTA stays disabled).

## Notification URL

In FAPI, point the form URL-notification and/or the global invoice
webhook (`paid`) at:

```
https://<project>.supabase.co/functions/v1/fapi-webhook?token=<FAPI_WEBHOOK_SECURITY>
```

FAPI POSTs `id` (or `invoice`), `time`, `security`. This function:

1. Requires `FAPI_WEBHOOK_SECURITY` and a matching `token` (timing-safe). Missing or wrong → 401, no invoice lookup and no purchase write
2. `GET /invoices/{id}` with Basic auth
3. Verifies `security === sha1(time + id + number + Σ md5(item.id + item.name))`
   ([SecurityChecker](https://github.com/fapi-cz/fapi-client/blob/master/src/Fapi/FapiClient/Tools/SecurityChecker.php)) with a timing-safe compare
4. If `paid`, updates the existing pending `purchases` row: `status=paid`, `paid_at`, `reward_variant` from the invoice custom field or the pending row, `amount_cents` and `currency` from the invoice (`total` in major units → cents), `fapi_invoice_id`, `fapi_client_id`. A replay of the same `fapi_invoice_id` is a no-op (`UNIQUE`). Already `paid` returns `OK`. No pending row → 409, nothing is inserted. Also sets `profiles.fapi_client_id` when that column is still empty.
5. Returns 2xx (`OK` or `SKIPPED` for unpaid / missing metadata)

Unpaid proforma notifications are acknowledged with 200 so FAPI does
not retry them; the later paid invoice unlocks the purchase.
