# Legal staging notes (T9)

SPEC §14. Prod membership stays off.

## LG-01

The paywall renders **Obchodní podmínky** and **Ochrana osobních údajů** above **Zaplatit členství**. The links are the draft URLs from the VOP working text:

- https://vyslapni.cz/obchodni-podminky/
- https://vyslapni.cz/ochrana-osobnich-udaju/

A draft disclaimer is on the paywall: production payments are not enabled. These URLs are not a published VOP gate (LG-03).

## LG-02

FAPI sandbox checkbox copy (draft appendix 2), to be placed on the form when P3 exists. The app does not render the FAPI form.

1. Souhlasím s Obchodními podmínkami a Zásadami ochrany osobních údajů.
2. Žádám o okamžité zahájení poskytování digitální služby VANDERY+ a beru na vědomí, že tím ztrácím právo odstoupit od smlouvy podle § 1837 občanského zákoníku.
3. Souhlasím s opakovaným strháváním měsíční platby, dokud předplatné nezruším e-mailem na ahoj@vyslapni.cz. Po zrušení zůstává členství aktivní do konce zaplaceného období a další platba se už nestrhne.

Legal PASS draft, VOP publish Ask first. This is not a lawyer sign-off. Do not publish.

The VOP citation is čl. X (X.5) and Příloha 2 checkbox 3.

## LG-04 privacy inventory

| Data | Table | Fields |
| --- | --- | --- |
| VANDERY+ membership | `public.vandery_plus_memberships` | status, starts_at, expires_at, cancel_at_period_end, fapi_subscription_id, fapi_invoice_id, amount_cents, currency |

Account delete anonymizes the row (user id tombstone, subscription id cleared). Amount, currency, invoice id, and period timestamps stay as the accounting trace (SPEC §14.3).

## LG-06 iOS IAP (Ask first, not implemented)

Apple App Review 3.1.x may reject a digital membership sold only through FAPI, outside In-App Purchase. This branch does not add IAP and does not turn on a production membership flag. Ondřej decides IAP vs FAPI before any store submit.

## LG-05 post-payment email

Legal PASS draft, VOP publish Ask first. Not a lawyer sign-off. Do not publish. The VOP citation is čl. X (X.5) and Příloha 2 checkbox 3.

- cs: Zrušit můžeš kdykoli e-mailem na ahoj@vyslapni.cz. Členství pak platí do konce zaplaceného období a další platba se už nestrhne.
- en: Cancel anytime. Membership stays active until the end of the paid period. Cancel by email to ahoj@vyslapni.cz.
- de: Jederzeit kündbar. Die Mitgliedschaft bleibt bis zum Ende des bezahlten Zeitraums aktiv. Kündigen per E-Mail an ahoj@vyslapni.cz.

## Still blocked for prod

LG-03 published VOP čl. X (X.5) and Příloha 2 checkbox 3 (monthly variant B), LG-05 post-payment email (draft above, not sent), P3 price and live form, P5 diploma list.
