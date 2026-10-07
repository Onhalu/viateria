import {
  decideDiploma,
  diplomaCopy,
  diplomaObjectPath,
  entitledFromRows,
  hashForRow,
  isCacheHit,
  layoutTitle,
  type IssuedDiplomaRow,
} from "./access.ts";
import { csAccusative } from "./declension.ts";
import { RENDERER_VERSION, renderHash } from "./hash.ts";
import { completionLabel, pragueIsoDate } from "./prague.ts";
import { decodeRgbaPng, pixelAlpha } from "./png.ts";
import { loadBundledRenderAssets, renderDiploma } from "./render.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function row(overrides: Partial<IssuedDiplomaRow> = {}): IssuedDiplomaRow {
  return {
    id: "11111111-1111-4111-8111-111111111111",
    user_id: "22222222-2222-4222-8222-222222222222",
    challenge_id: "33333333-3333-4333-8333-333333333333",
    revoked_at: null,
    lang: "cs",
    headline: "",
    body: "",
    challenge_title: "Pálava",
    recipient_name_display: "Pavla Novák",
    completed_at: "2026-07-15T22:30:00.000Z",
    background_variant: 1,
    image_path: null,
    render_hash: null,
    ...overrides,
  };
}

Deno.test("cs accusative declines the first name only", () => {
  assert(csAccusative("Pavel") === "Pavla", "Pavel");
  assert(csAccusative("Ondřej") === "Ondřeje", "Ondřej");
  assert(csAccusative("Jana") === "Janu", "Jana");
  assert(csAccusative("Marie") === "Marii", "Marie");
  assert(csAccusative("Nikola") === "Nikolu", "Nikola");
  assert(csAccusative("Pavel Novák") === "Pavla Novák", "surname stays");
  assert(csAccusative("  ") === null, "blank");
});

Deno.test("completion line is the Prague calendar date", () => {
  assert(
    pragueIsoDate(new Date("2026-01-15T23:30:00.000Z")) === "2026-01-16",
    "winter crosses midnight",
  );
  assert(
    completionLabel(new Date("2026-01-15T23:30:00.000Z")) === "dne 16.01.2026",
    "winter label",
  );
  assert(
    completionLabel(new Date("2026-07-15T22:30:00.000Z")) === "dne 16.07.2026",
    "summer label",
  );
  assert(
    pragueIsoDate(new Date("2026-03-29T00:30:00.000Z")) === "2026-03-29",
    "before DST",
  );
  assert(
    pragueIsoDate(new Date("2026-10-25T00:30:00.000Z")) === "2026-10-25",
    "still CEST",
  );
});

Deno.test("not entitled refuses before a name or cache check", () => {
  const denied = decideDiploma(row(), false);
  assert(!denied.ok && denied.status === 402 && denied.error === "not_entitled", "402");
  const missing = decideDiploma(null, true);
  assert(!missing.ok && missing.status === 404, "404");
  const revoked = decideDiploma(row({ revoked_at: "2026-01-01T00:00:00Z" }), true);
  assert(!revoked.ok && revoked.status === 403, "403");
  const nameless = decideDiploma(row({ recipient_name_display: null }), true);
  assert(!nameless.ok && nameless.status === 409 && nameless.error === "need_name", "409");
  const ready = decideDiploma(row(), true);
  assert(ready.ok, "entitled with a name may render");
});

Deno.test("entitlement matches paid, zero price, or free without a price row", () => {
  const now = new Date("2026-06-01T12:00:00.000Z");
  const price = {
    diplomaPriceCents: 499,
    status: "published",
    validFrom: "2026-01-01T00:00:00.000Z",
    validTo: null,
  };
  assert(
    entitledFromRows({ completed: true, paid: true, prices: [price], pricingType: "paid", now }),
    "paid",
  );
  assert(
    !entitledFromRows({ completed: false, paid: true, prices: [], pricingType: "free", now }),
    "incomplete",
  );
  assert(
    !entitledFromRows({ completed: true, paid: false, prices: [price], pricingType: "paid", now }),
    "unpaid",
  );
  assert(
    entitledFromRows({
      completed: true,
      paid: false,
      prices: [{ ...price, diplomaPriceCents: 0 }],
      pricingType: "paid",
      now,
    }),
    "zero price",
  );
  assert(
    entitledFromRows({ completed: true, paid: false, prices: [], pricingType: "free", now }),
    "free",
  );
  assert(
    entitledFromRows({
      completed: true,
      paid: false,
      prices: [{ ...price, validTo: "2026-05-01T00:00:00.000Z" }],
      pricingType: "free",
      now,
    }),
    "expired price does not block the free path",
  );
});

Deno.test("render hash is stable and changes with the Prague date", async () => {
  const issued = row();
  const hash = await hashForRow(issued);
  assert(/^[0-9a-f]{64}$/.test(hash), "sha256 hex");
  assert(hash === await hashForRow(issued), "stable");
  const renamed = await hashForRow({ ...issued, recipient_name_display: "Janu" });
  assert(renamed !== hash, "name changes the hash");
  const nextDay = await hashForRow({
    ...issued,
    completed_at: "2026-07-16T22:30:00.000Z",
  });
  assert(nextDay !== hash, "date changes the hash");
  const path = diplomaObjectPath(issued.user_id, issued.challenge_id, hash);
  assert(path.endsWith(`/${hash}.png`), "png path");
  assert(isCacheHit({ ...issued, render_hash: hash, image_path: path }, hash, path), "hit");
  assert(!isCacheHit(issued, hash, path), "miss when unset");
  const manual = await renderHash({
    rendererVersion: RENDERER_VERSION,
    lang: "cs",
    headline: "",
    body: "",
    challengeTitle: "Pálava",
    recipientNameDisplay: "Pavla Novák",
    completedOn: "2026-07-16",
    backgroundVariant: 1,
  });
  assert(manual === hash, "hash uses the raw headline and the Prague date");
  const copy = diplomaCopy(issued);
  assert(copy.headline === "DIPLOM", "default headline");
  assert(copy.body === "za zdolání výzvy", "default body");
  assert(copy.duration === "dne 16.07.2026", "duration line");
  assert(copy.preposition === "pro", "preposition");
});

Deno.test("long titles wrap to two lines and shrink", () => {
  const short = layoutTitle("Pálava");
  assert(short.fontSize === 60 && short.lines.length === 1, "short");
  const long = layoutTitle(
    "Velmi dlouhý název výzvy který se nevejde na jeden řádek Playfair",
  );
  assert(long.lines.length <= 2, "max two lines");
  assert(long.fontSize === 60 || long.fontSize === 44, "size step");
});

Deno.test("T1 render is a rounded 1080 PNG under 1.5s", async () => {
  const assets = await loadBundledRenderAssets(1);
  const started = performance.now();
  const png = await renderDiploma(row(), assets);
  const elapsed = performance.now() - started;
  console.log(`diploma render ${elapsed.toFixed(0)} ms, ${png.byteLength} bytes`);
  assert(elapsed < 1500, `T1 spike ${elapsed.toFixed(0)} ms exceeds 1500 ms`);
  const image = await decodeRgbaPng(png);
  assert(image.width === 1080 && image.height === 1080, "1080 square");
  assert(pixelAlpha(image, 0, 0) === 0, "rounded corner is transparent");
  assert(pixelAlpha(image, 540, 540) > 0, "center is opaque");
});
