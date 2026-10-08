import { encodeHex } from "jsr:@std/encoding@1.0.10/hex";

/** Bump when the layout, defaults, or font change. Included in [renderHash]. */
export const RENDERER_VERSION = 4;

export type RenderHashInput = {
  rendererVersion: number;
  lang: string;
  headline: string;
  body: string;
  challengeTitle: string;
  recipientNameDisplay: string;
  completedOn: string;
  backgroundVariant: number;
};

/**
 * sha256 of the SPEC §3 fields, separated by U+001F so a value cannot
 * shift the next field. `completedOn` is the Europe/Prague calendar date
 * (`YYYY-MM-DD`) of `completed_at`. `recipientNameDisplay` is the final
 * printed name, so a profile rename or a one-time edit changes the hash
 * and forces a re-render. Layout version stays on [RENDERER_VERSION].
 */
export async function renderHash(input: RenderHashInput): Promise<string> {
  const payload = [
    String(input.rendererVersion),
    input.lang,
    input.headline,
    input.body,
    input.challengeTitle,
    input.recipientNameDisplay,
    input.completedOn,
    String(input.backgroundVariant),
  ].join("\u001f");
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(payload),
  );
  return encodeHex(new Uint8Array(digest));
}
