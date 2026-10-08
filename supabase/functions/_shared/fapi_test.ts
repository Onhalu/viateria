import {
  appendFapiPrefill,
  callerCanReadChallenge,
  checkoutAmountCents,
  fapiClientId,
  fapiInvoiceId,
  fapiPrefillParams,
  httpUrlOrNull,
  invoiceCurrencyCode,
  invoiceSecurityHash,
  invoiceTotalCents,
  isInvoiceSecurityValid,
  isWebhookTokenValid,
  parseNotification,
  parseViateriaNotes,
  promoMatchesViewer,
  purchaseKeysFromInvoice,
  purchaseUnlockPlan,
  isMissingSchemaObject,
  selectActiveDiscountStripe,
  selectActivePrice,
  selectSaleFormUrl,
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

Deno.test("invoice money comes from total and currency, not the pending row", () => {
  const invoice = {
    id: 239,
    client: 23,
    currency: "CZK",
    total: 199,
  };
  if (fapiInvoiceId(invoice) !== "239") throw new Error("id");
  if (fapiClientId(invoice) !== "23") throw new Error("client");
  if (invoiceCurrencyCode(invoice) !== "czk") throw new Error("currency");
  if (invoiceTotalCents(invoice) !== 19900) throw new Error("cents");
  if (invoiceTotalCents({ total: "19.99" }) !== 1999) {
    throw new Error("string total");
  }
  if (invoiceTotalCents({ total: -1 }) !== null) throw new Error("negative");
  if (invoiceCurrencyCode({ currency: "euro" }) !== null) {
    throw new Error("bad currency");
  }
  if (invoiceTotalCents({}) !== null || invoiceCurrencyCode({}) !== null) {
    throw new Error("missing");
  }
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

Deno.test("webhook token fails closed when the secret is missing or wrong", () => {
  if (isWebhookTokenValid(undefined, "anything")) {
    throw new Error("unset secret");
  }
  if (isWebhookTokenValid("", "")) throw new Error("empty must not match empty");
  if (isWebhookTokenValid("secret", null)) throw new Error("missing token");
  if (isWebhookTokenValid("secret", "Secret")) {
    throw new Error("token compare is case-sensitive");
  }
  if (isWebhookTokenValid("secret", "secret-extra")) {
    throw new Error("length mismatch");
  }
  if (!isWebhookTokenValid("secret", "secret")) {
    throw new Error("exact token should pass");
  }
});

Deno.test("paid unlock only marks an existing pending purchase", () => {
  if (purchaseUnlockPlan(null) !== "reject") throw new Error("no row");
  if (purchaseUnlockPlan({ status: "failed" }) !== "reject") {
    throw new Error("failed");
  }
  if (purchaseUnlockPlan({ status: "refunded" }) !== "reject") {
    throw new Error("refunded");
  }
  if (purchaseUnlockPlan({ status: "pending" }) !== "mark_paid") {
    throw new Error("pending");
  }
  if (purchaseUnlockPlan({ status: "paid" }) !== "already_paid") {
    throw new Error("replay");
  }
});

Deno.test("sale form url falls back preferred, cs, en, de", () => {
  const now = new Date("2026-10-06T12:00:00Z");
  const forms = [
    {
      locale: "en",
      reward_variant: "diploma",
      fapi_form_url: "https://form.fapi.cz/en",
      status: "published",
      valid_from: "2026-01-01T00:00:00Z",
    },
    {
      locale: "cs",
      reward_variant: "diploma",
      fapi_form_url: "https://form.fapi.cz/cs",
      status: "published",
      valid_from: "2026-01-01T00:00:00Z",
    },
    {
      locale: "de",
      reward_variant: "medal_and_diploma",
      fapi_form_url: "https://form.fapi.cz/de-medal",
      status: "published",
      valid_from: "2026-06-01T00:00:00Z",
    },
    {
      locale: "cs",
      reward_variant: "diploma",
      fapi_form_url: "https://form.fapi.cz/draft",
      status: "draft",
      valid_from: "2026-01-01T00:00:00Z",
    },
  ];
  if (selectSaleFormUrl(forms, "diploma", "de", now) !== "https://form.fapi.cz/cs") {
    throw new Error("de missing should use cs");
  }
  if (selectSaleFormUrl(forms, "diploma", "en", now) !== "https://form.fapi.cz/en") {
    throw new Error("en exact");
  }
  if (
    selectSaleFormUrl(forms, "medal_and_diploma", "cs", now) !==
      "https://form.fapi.cz/de-medal"
  ) {
    throw new Error("only de medal form");
  }
  if (selectSaleFormUrl(forms, "diploma", "cs", now) !== "https://form.fapi.cz/cs") {
    throw new Error("cs preferred over en");
  }
});

Deno.test("active price prefers the newest published window", () => {
  const now = new Date("2026-10-06T12:00:00Z");
  const selected = selectActivePrice([
    {
      diploma_price_cents: 100,
      medal_price_cents: 200,
      currency: "czk",
      status: "published",
      valid_from: "2026-01-01T00:00:00Z",
      valid_to: "2026-06-01T00:00:00Z",
    },
    {
      diploma_price_cents: 19900,
      medal_price_cents: null,
      currency: "eur",
      status: "published",
      valid_from: "2026-06-01T00:00:00Z",
    },
    {
      diploma_price_cents: 1,
      currency: "czk",
      status: "draft",
      valid_from: "2026-09-01T00:00:00Z",
    },
  ], now);
  if (selected?.diploma_price_cents !== 19900) throw new Error("stale or draft");
  if (selected?.currency !== "eur") throw new Error("currency");
  if (!isMissingSchemaObject({ code: "PGRST205", message: "not in schema" })) {
    throw new Error("missing view");
  }
  if (isMissingSchemaObject({ code: "42501", message: "permission denied" })) {
    throw new Error("permission is not a missing relation");
  }
});

Deno.test("checkout readable gate accepts only a true RPC result", () => {
  if (!callerCanReadChallenge(true, null)) throw new Error("true");
  if (callerCanReadChallenge(false, null)) throw new Error("false");
  if (callerCanReadChallenge(null, null)) throw new Error("null");
  if (callerCanReadChallenge(true, { message: "missing function" })) {
    throw new Error("rpc error must fail closed");
  }
});
