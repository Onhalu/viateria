import { hookSecretBytes } from "./hook_auth.ts";

Deno.test("send-email hook secret is required", () => {
  if (hookSecretBytes(undefined) !== null) {
    throw new Error("unset secret must fail closed");
  }
  if (hookSecretBytes("") !== null) throw new Error("empty");
  if (hookSecretBytes("v1,whsec_") !== null) {
    throw new Error("prefix only");
  }
  if (hookSecretBytes("v1,whsec_abc") !== "abc") {
    throw new Error("should strip the Supabase prefix");
  }
  if (hookSecretBytes("already-raw") !== "already-raw") {
    throw new Error("raw secret should pass through");
  }
});
