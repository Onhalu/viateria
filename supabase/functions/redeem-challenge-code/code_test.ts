import { hashCode, isUuid, normalizeCode, redeemHttpStatus } from "./code.ts";

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

Deno.test("normalize strips spaces and dashes and uppercases", () => {
  assert(normalizeCode("  ab12-cd34 ") === "AB12CD34", "dashed");
  assert(normalizeCode("ab12 cd34") === "AB12CD34", "spaces");
  assert(normalizeCode("ABCD2345") === "ABCD2345", "already clean");
  assert(normalizeCode("ABCDEFGHIJKLMNOP") === "ABCDEFGHIJKLMNOP", "len 16");
  assert(normalizeCode("ABC2345") === null, "len 7");
  assert(normalizeCode("ABCDEFGHIJKLMNOPQ") === null, "len 17");
  assert(normalizeCode("AB12_CD34") === null, "underscore");
  assert(normalizeCode("") === null, "empty");
  assert(normalizeCode("   ---   ") === null, "only separators");
  assert(normalizeCode(12) === null, "non-string");
});

Deno.test("sha256 hex matches the import script vector", async () => {
  const hash = await hashCode("AB12CD34");
  assert(
    hash ===
      "668c072603bbc3a89b6e2a67f878e29dbe33c020984d4928eda299e7cebe0adb",
    hash,
  );
});

Deno.test("http status matches the smoke classes", () => {
  assert(redeemHttpStatus("invalid_code") === 400, "invalid");
  assert(redeemHttpStatus("expired") === 400, "expired");
  assert(redeemHttpStatus("already_redeemed") === 400, "redeemed");
  assert(redeemHttpStatus("challenge_mismatch") === 400, "mismatch");
  assert(redeemHttpStatus("email_mismatch") === 403, "email");
  assert(redeemHttpStatus("rate_limited") === 429, "rate");
  assert(redeemHttpStatus("unauthorized") === 401, "auth");
});

Deno.test("challenge id must be a uuid", () => {
  assert(isUuid("11111111-1111-4111-8111-111111111111"), "uuid");
  assert(!isUuid("open-1"), "slug");
  assert(!isUuid(""), "empty");
  assert(!isUuid(null), "null");
});
