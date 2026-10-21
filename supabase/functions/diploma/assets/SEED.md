# diploma-assets seed

Temporary files for the private `diploma-assets` bucket. Final backgrounds and
the black Vyšlápni logo replace these later. Bricolage Grotesque is OFL
(`fonts/OFL.txt`). Regular and Bold are static instances of
`BricolageGrotesque[opsz,wdth,wght].ttf` from google/fonts @ b9f6c712059d
(opsz 96, wdth 100, weights 400 and 700).

Upload with the service role (the bucket has no client policies):

| Object key | Repo file |
| --- | --- |
| `bg/1.png` | `assets/bg/1.png` |
| `bg/2.png` | `assets/bg/2.png` |
| `bg/3.png` | `assets/bg/3.png` |
| `bg/4.png` | `assets/bg/4.png` |
| `logo/vandery-lockup.png` | `assets/logo/vandery-lockup.png` (= `assets/brand/vandery-lockup@3x.png`) |
| `fonts/BricolageGrotesque-Regular.ttf` | `assets/fonts/BricolageGrotesque-Regular.ttf` |
| `fonts/BricolageGrotesque-Bold.ttf` | `assets/fonts/BricolageGrotesque-Bold.ttf` |

The Edge function reads the bucket first and falls back to these bundled copies
so a render still works before the upload. `background_variant` is chosen once
when the diploma row is issued.

Regenerate the gradients:

```
deno run --allow-write supabase/functions/diploma/generate_backgrounds.ts
```
