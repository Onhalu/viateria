import {
  appendFapiPrefill,
  checkoutAmountCents,
  fapiPrefillParams,
  httpUrlOrNull,
  invoiceSecurityHash,
  isInvoiceSecurityValid,
  parseNotification,
  parseViateriaNotes,
  promoMatchesViewer,
  purchaseKeysFromInvoice,
  selectActiveDiscountStripe,
  viateriaNotes,
  type DiscountStripe,
} from "./fapi.ts";

Deno.test("httpUrlOrNull rejects blank and non-http values", () => {
  if (httpUrlOrNull(" https://form.fapi.cz/d ") !== "https://form.fapi.cz/d") {
    throw new Error("should keep http(s) URLs");
  }
  if (httpUrlOrNull("") !== null) throw new Error("empty");
  if (httpUrlOrNull("javascript:alert(1)") !== null) {
    throw new Error("javascript");
  }
});

Deno.test("notes payload round-trips purchase keys", () => {
  const notes = viateriaNotes(
    "user-1",
    "challenge-1",
    "medal_and_diploma",
  );
  const parsed = parseViateriaNotes(notes);
  if (
    parsed?.userId !== "user-1" ||
    parsed.challengeId !== "challenge-1" ||
    parsed.rewardVariant !== "medal_and_diploma"
  ) {
    throw new Error(`bad notes parse: ${JSON.stringify(parsed)}`);
  }
});

Deno.test("prefill appends notes and custom fields", () => {
  const url = appendFapiPrefill(
    "https://example.com/form",
    fapiPrefillParams({
      userId: "u1",
      challengeId: "c1",
      rewardVariant: "diploma",
      email: "ada@example.com",
      customFieldIdUser: "20",
    }),
  );
  const parsed = new URL(url);
  if (parsed.searchParams.get("fapi-form-email") !== "ada@example.com") {
    throw new Error(url);
  }
  if (parsed.searchParams.get("fapi-form-customField-20") !== "u1") {
    throw new Error(url);
  }
  if (
    parsed.searchParams.get("fapi-form-notes") !==
      "viateria:u1:c1:diploma"
  ) {
    throw new Error(url);
  }
});

Deno.test("invoice security hash matches PHP SecurityChecker", async () => {
  const invoice = {
    id: 239,
    number: "20180020",
    items: [{ id: 600, name: "simple" }],
  };
  const hash = await invoiceSecurityHash(invoice, 1710000000);
  if (!hash || hash.length !== 40) {
    throw new Error(`unexpected hash ${hash}`);
  }
  if (!await isInvoiceSecurityValid(invoice, 1710000000, hash)) {
    throw new Error("self-check failed");
  }
  if (await isInvoiceSecurityValid(invoice, 1710000000, "deadbeef")) {
    throw new Error("should reject");
  }
});

Deno.test("purchase keys prefer custom fields then notes", () => {
  const keys = purchaseKeysFromInvoice({
    notes: "viateria:note-user:note-challenge:diploma",
    custom_fields: [
      { name: "user_id", value: "field-user" },
      { name: "challenge_id", value: "field-challenge" },
      { name: "reward_variant", value: "medal_and_diploma" },
    ],
  });
  if (
    keys.userId !== "field-user" ||
    keys.challengeId !== "field-challenge" ||
    keys.rewardVariant !== "medal_and_diploma"
  ) {
    throw new Error(JSON.stringify(keys));
  }
});

Deno.test("promo audience: empty assignments match everyone", () => {
  const viewer = {
    userId: "ada",
    locale: "cs",
    countryCode: "CZ",
    segmentIds: new Set<string>(),
  };
  if (!promoMatchesViewer([], viewer)) throw new Error("empty should match");
  if (
    promoMatchesViewer(
      [{ targetType: "user", userId: "ondrej" }],
      viewer,
    )
  ) {
    throw new Error("other user should not match");
  }
  if (
    !promoMatchesViewer(
      [
        { targetType: "user", userId: "ondrej" },
        { targetType: "locale", locale: "cs" },
      ],
      viewer,
    )
  ) {
    throw new Error("OR locale should match");
  }
});

Deno.test("discount checkout prefers promo cents when the stripe matches", () => {
  const now = new Date("2026-09-30T12:00:00Z");
  const stripes: DiscountStripe[] = [
    {
      id: "later",
      sortOrder: 2,
      startsAt: null,
      endsAt: null,
      promoDiplomaPriceCents: 100,
      promoMedalPriceCents: 200,
      assignments: [],
    },
    {
      id: "first",
      sortOrder: 0,
      startsAt: "2026-09-01T00:00:00Z",
      endsAt: "2026-10-14T00:00:00Z",
      promoDiplomaPriceCents: 50,
      promoMedalPriceCents: null,
      assignments: [{ targetType: "country", countryCode: "cz" }],
    },
  ];
  const viewer = {
    userId: "ada",
    locale: "cs",
    countryCode: "CZ",
    segmentIds: new Set<string>(),
  };
  const selected = selectActiveDiscountStripe(stripes, viewer, now);
  if (selected?.id !== "first") throw new Error(selected?.id ?? "none");
  const diploma = checkoutAmountCents({
    isMedal: false,
    diplomaPriceCents: 499,
    medalPriceCents: 900,
    promoDiplomaPriceCents: selected?.promoDiplomaPriceCents,
    promoMedalPriceCents: selected?.promoMedalPriceCents,
  });
  const medal = checkoutAmountCents({
    isMedal: true,
    diplomaPriceCents: 499,
    medalPriceCents: 900,
    promoDiplomaPriceCents: selected?.promoDiplomaPriceCents,
    promoMedalPriceCents: selected?.promoMedalPriceCents,
  });
  if (diploma !== 50) throw new Error(`diploma ${diploma}`);
  if (medal !== 900) throw new Error(`medal ${medal}`);
  const plain = checkoutAmountCents({
    isMedal: false,
    diplomaPriceCents: 499,
    medalPriceCents: 900,
  });
  if (plain !== 499) throw new Error(`plain ${plain}`);
});

Deno.test("notification parser reads id or invoice", () => {
  const form = parseNotification(
    "invoice=99&time=1&security=abc",
    "application/x-www-form-urlencoded",
  );
  if (form.invoiceId !== "99" || form.time !== "1" || form.security !== "abc") {
    throw new Error(JSON.stringify(form));
  }
  const json = parseNotification(
    JSON.stringify({ id: 12, time: 3, security: "s" }),
    "application/json",
  );
  if (json.invoiceId !== "12" || json.time !== "3") {
    throw new Error(JSON.stringify(json));
  }
});
