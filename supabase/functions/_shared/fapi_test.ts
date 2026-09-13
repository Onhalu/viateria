import {
  appendFapiPrefill,
  fapiPrefillParams,
  httpUrlOrNull,
  invoiceSecurityHash,
  isInvoiceSecurityValid,
  parseNotification,
  parseViateriaNotes,
  purchaseKeysFromInvoice,
  viateriaNotes,
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

Deno.test("invoice security hash matches PHP SecurityChecker", () => {
  const invoice = {
    id: 239,
    number: "20180020",
    items: [{ id: 600, name: "simple" }],
  };
  const hash = invoiceSecurityHash(invoice, 1710000000);
  if (!hash || hash.length !== 40) {
    throw new Error(`unexpected hash ${hash}`);
  }
  if (!isInvoiceSecurityValid(invoice, 1710000000, hash)) {
    throw new Error("self-check failed");
  }
  if (isInvoiceSecurityValid(invoice, 1710000000, "deadbeef")) {
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
