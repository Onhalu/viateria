import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { exchangeCode } from "@/lib/etoro/sso";

export const dynamic = "force-dynamic";

/** OAuth redirect target: validate state, exchange the code, store the token. */
export async function GET(req: NextRequest) {
  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state");
  const error = url.searchParams.get("error");

  if (error) {
    return NextResponse.redirect(new URL(`/?auth_error=${encodeURIComponent(error)}`, req.url));
  }

  const expectedState = req.cookies.get("etoro_state")?.value;
  const verifier = req.cookies.get("etoro_pkce")?.value;

  if (!code || !state || !expectedState || state !== expectedState || !verifier) {
    return NextResponse.redirect(new URL("/?auth_error=invalid_state", req.url));
  }

  try {
    const tokens = await exchangeCode({ code, codeVerifier: verifier });
    const res = NextResponse.redirect(new URL("/?connected=1", req.url));
    const secure = process.env.NODE_ENV === "production";
    // NOTE: a production app should keep tokens in a server-side session store,
    // not a cookie. This is sufficient for the reference integration.
    res.cookies.set("etoro_access_token", tokens.access_token, {
      httpOnly: true,
      secure,
      path: "/",
      maxAge: tokens.expires_in ?? 3600,
    });
    if (tokens.refresh_token) {
      res.cookies.set("etoro_refresh_token", tokens.refresh_token, {
        httpOnly: true,
        secure,
        path: "/",
        maxAge: 60 * 60 * 24 * 30,
      });
    }
    res.cookies.delete("etoro_pkce");
    res.cookies.delete("etoro_state");
    return res;
  } catch (err) {
    const message = err instanceof Error ? err.message : "token_exchange_failed";
    return NextResponse.redirect(
      new URL(`/?auth_error=${encodeURIComponent(message)}`, req.url),
    );
  }
}
