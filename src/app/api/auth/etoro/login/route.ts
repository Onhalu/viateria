import { NextResponse } from "next/server";
import { isSsoConfigured } from "@/lib/etoro/config";
import { buildAuthorizeUrl, createPkcePair, s256Challenge } from "@/lib/etoro/sso";

export const dynamic = "force-dynamic";

/** Kick off the eToro auth-code + PKCE flow. */
export async function GET() {
  if (!isSsoConfigured()) {
    return NextResponse.json(
      { error: "eToro SSO is not configured. Set ETORO_CLIENT_ID and ETORO_REDIRECT_URI." },
      { status: 501 },
    );
  }

  const { verifier } = createPkcePair();
  const challenge = await s256Challenge(verifier);
  const state = crypto.randomUUID();

  const url = buildAuthorizeUrl({ state, codeChallenge: challenge });
  const res = NextResponse.redirect(url);

  // Short-lived, httpOnly cookies carry the PKCE verifier + state across the redirect.
  const secure = process.env.NODE_ENV === "production";
  res.cookies.set("etoro_pkce", verifier, { httpOnly: true, secure, path: "/", maxAge: 600 });
  res.cookies.set("etoro_state", state, { httpOnly: true, secure, path: "/", maxAge: 600 });
  return res;
}
