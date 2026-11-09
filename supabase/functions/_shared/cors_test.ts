import {
  corsHeaders,
  isProductionRuntime,
  parseAllowedOrigins,
  preflightResponse,
  type CorsConfig,
} from "./cors.ts";

const PROD_WEB = "https://viateria.limitlessdreams.cz";

const prodConfig: CorsConfig = {
  allowedOrigins: [PROD_WEB],
  production: true,
};

function request(method: string, origin?: string): Request {
  const headers = new Headers();
  if (origin !== undefined) headers.set("Origin", origin);
  return new Request(
    "https://yzmbxxgesnbsqygzgdky.supabase.co/functions/v1/start-fapi-checkout",
    { method, headers },
  );
}

function assertNoWildcard(headers: Headers) {
  for (const [name, value] of headers.entries()) {
    if (value.trim() === "*") {
      throw new Error(`${name} must not be *`);
    }
  }
}

Deno.test("allowed origin is echoed and Vary is Origin", () => {
  const headers = corsHeaders(request("POST", PROD_WEB), prodConfig);
  if (headers.get("Access-Control-Allow-Origin") !== PROD_WEB) {
    throw new Error(
      `expected echo, got ${headers.get("Access-Control-Allow-Origin")}`,
    );
  }
  if (headers.get("Vary") !== "Origin") {
    throw new Error(`Vary: ${headers.get("Vary")}`);
  }
  assertNoWildcard(headers);
});

Deno.test("foreign origin gets no Access-Control-Allow-Origin", () => {
  const headers = corsHeaders(
    request("POST", "https://evil.example"),
    prodConfig,
  );
  if (headers.has("Access-Control-Allow-Origin")) {
    throw new Error(
      `foreign origin must not echo ${headers.get("Access-Control-Allow-Origin")}`,
    );
  }
  if (headers.get("Vary") !== "Origin") {
    throw new Error(`Vary: ${headers.get("Vary")}`);
  }
  assertNoWildcard(headers);
});

Deno.test("OPTIONS preflight is 204 with Vary and echoed origin", async () => {
  const response = preflightResponse(
    request("OPTIONS", PROD_WEB),
    prodConfig,
  );
  if (response.status !== 204) {
    throw new Error(`status ${response.status}`);
  }
  if (await response.text() !== "") {
    throw new Error("preflight body must be empty");
  }
  if (response.headers.get("Access-Control-Allow-Origin") !== PROD_WEB) {
    throw new Error("preflight did not echo the allowed origin");
  }
  if (response.headers.get("Vary") !== "Origin") {
    throw new Error(`Vary: ${response.headers.get("Vary")}`);
  }
  assertNoWildcard(response.headers);
});

Deno.test("OPTIONS from a foreign origin is 204 without ACAO", async () => {
  const response = preflightResponse(
    request("OPTIONS", "https://evil.example"),
    prodConfig,
  );
  if (response.status !== 204) throw new Error(`status ${response.status}`);
  if (response.headers.has("Access-Control-Allow-Origin")) {
    throw new Error("foreign preflight must omit ACAO");
  }
  if (response.headers.get("Vary") !== "Origin") {
    throw new Error("missing Vary");
  }
});

Deno.test("localhost is allowed only outside production", () => {
  const local = "http://localhost:54321";
  const dev: CorsConfig = { allowedOrigins: [PROD_WEB], production: false };
  const allowed = corsHeaders(request("POST", local), dev);
  if (allowed.get("Access-Control-Allow-Origin") !== local) {
    throw new Error("dev localhost should be echoed");
  }
  const blocked = corsHeaders(request("POST", local), {
    allowedOrigins: [PROD_WEB, local],
    production: true,
  });
  if (blocked.has("Access-Control-Allow-Origin")) {
    throw new Error("production must not allow localhost even if listed");
  }
  if (blocked.get("Vary") !== "Origin") throw new Error("missing Vary");
});

Deno.test("ALLOWLIST parsing ignores blanks and keeps https prod web", () => {
  const origins = parseAllowedOrigins(
    ` ${PROD_WEB}/ , http://127.0.0.1:7357 `,
  );
  if (origins[0] !== PROD_WEB || origins[1] !== "http://127.0.0.1:7357") {
    throw new Error(JSON.stringify(origins));
  }
});

Deno.test("hosted SUPABASE_URL without ENVIRONMENT is production", () => {
  const env = {
    get(name: string) {
      if (name === "SUPABASE_URL") {
        return "https://yzmbxxgesnbsqygzgdky.supabase.co";
      }
      return undefined;
    },
  };
  if (!isProductionRuntime(env)) {
    throw new Error("hosted project must be treated as production");
  }
  const local = {
    get(name: string) {
      if (name === "SUPABASE_URL") return "http://127.0.0.1:54321";
      return undefined;
    },
  };
  if (isProductionRuntime(local)) {
    throw new Error("loopback SUPABASE_URL is not production");
  }
});
