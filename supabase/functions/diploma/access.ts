import { completionLabel, pragueIsoDate } from "./prague.ts";
import { RENDERER_VERSION, renderHash } from "./hash.ts";

export type IssuedDiplomaRow = {
  id: string;
  user_id: string;
  challenge_id: string;
  revoked_at: string | null;
  lang: string | null;
  headline: string | null;
  body: string | null;
  challenge_title: string | null;
  recipient_name_display: string | null;
  completed_at: string | null;
  background_variant: number | null;
  image_path: string | null;
  render_hash: string | null;
};

export type DiplomaDecision =
  | { ok: false; status: 404 | 403 | 402 | 409 | 422; error: string }
  | { ok: true };

/**
 * Refuse the full file before any render or upload.
 * `not_entitled` wins over a missing name so a locked row never renders.
 */
export function decideDiploma(
  row: IssuedDiplomaRow | null,
  entitled: boolean,
): DiplomaDecision {
  if (!row) return { ok: false, status: 404, error: "not_found" };
  if (row.revoked_at) return { ok: false, status: 403, error: "revoked" };
  if (!entitled) return { ok: false, status: 402, error: "not_entitled" };
  if (!(row.recipient_name_display ?? "").trim()) {
    return { ok: false, status: 409, error: "need_name" };
  }
  if (!row.completed_at) {
    return { ok: false, status: 422, error: "incomplete_snapshot" };
  }
  const variant = row.background_variant;
  if (variant == null || variant < 1 || variant > 4) {
    return { ok: false, status: 422, error: "incomplete_snapshot" };
  }
  return { ok: true };
}

export function diplomaObjectPath(
  userId: string,
  challengeId: string,
  hash: string,
): string {
  return `${userId}/${challengeId}/${hash}.png`;
}

export function isCacheHit(
  row: IssuedDiplomaRow,
  hash: string,
  objectPath: string,
): boolean {
  return row.render_hash === hash && row.image_path === objectPath;
}

export type PriceSnapshot = {
  diplomaPriceCents: number;
  status: string;
  validFrom: string;
  validTo: string | null;
};

/**
 * Same predicate as `private.diploma_entitled`. Promo display prices are
 * not an input. The Edge function cannot rely on PostgREST exposing the
 * `private` schema; `record_diploma_render` re-checks the SQL function.
 */
export function entitledFromRows(input: {
  completed: boolean;
  paid: boolean;
  prices: PriceSnapshot[];
  pricingType: string | null;
  now: Date;
}): boolean {
  if (!input.completed) return false;
  if (input.paid) return true;
  const active = input.prices.filter((row) =>
    row.status === "published" && priceWindowContains(row, input.now)
  );
  if (active.some((row) => row.diplomaPriceCents === 0)) return true;
  return input.pricingType === "free" && active.length === 0;
}

function priceWindowContains(row: PriceSnapshot, now: Date): boolean {
  const from = Date.parse(row.validFrom);
  if (Number.isNaN(from) || now.getTime() < from) return false;
  if (!row.validTo) return true;
  const to = Date.parse(row.validTo);
  if (Number.isNaN(to)) return false;
  return now.getTime() < to;
}

export function diplomaCopy(row: IssuedDiplomaRow): {
  headline: string;
  preposition: string;
  name: string;
  body: string;
  title: string;
  duration: string;
  completedOn: string;
} {
  const completed = new Date(row.completed_at ?? "");
  return {
    headline: (row.headline ?? "").trim() || "DIPLOM",
    preposition: "pro",
    // Already final: profile accusative from diploma_status, or a one-time
    // edit stored verbatim. Do not run csAccusative on this string.
    name: (row.recipient_name_display ?? "").trim(),
    body: (row.body ?? "").trim() || "za zdolání výzvy",
    title: (row.challenge_title ?? "").trim(),
    duration: completionLabel(completed),
    completedOn: pragueIsoDate(completed),
  };
}

export async function hashForRow(row: IssuedDiplomaRow): Promise<string> {
  const copy = diplomaCopy(row);
  return await renderHash({
    rendererVersion: RENDERER_VERSION,
    lang: row.lang ?? "cs",
    headline: row.headline ?? "",
    body: row.body ?? "",
    challengeTitle: row.challenge_title ?? "",
    recipientNameDisplay: copy.name,
    completedOn: copy.completedOn,
    backgroundVariant: row.background_variant ?? 0,
  });
}

const TEXT_WIDTH = 640;

/** At most two lines. Drop 60 → 44 when a line does not fit. */
export function layoutTitle(title: string): { lines: string[]; fontSize: number } {
  const clean = title.trim();
  if (!clean) return { lines: [""], fontSize: 60 };
  for (const fontSize of [60, 44]) {
    const lines = wrapWords(clean, fontSize, 2);
    if (
      lines.length <= 2 &&
      lines.every((line) => estimateWidth(line, fontSize) <= TEXT_WIDTH)
    ) {
      return { lines, fontSize };
    }
  }
  const forced = wrapWords(clean, 44, 2);
  if (forced.length > 2) {
    return { lines: [forced[0], trimToWidth(forced.slice(1).join(" "), 44)], fontSize: 44 };
  }
  return {
    lines: forced.map((line) => trimToWidth(line, 44)),
    fontSize: 44,
  };
}

function wrapWords(title: string, fontSize: number, maxLines: number): string[] {
  const words = title.split(/\s+/).filter((word) => word.length > 0);
  const lines: string[] = [];
  let current = "";
  for (let i = 0; i < words.length; i++) {
    const word = words[i];
    const next = current ? `${current} ${word}` : word;
    if (current && estimateWidth(next, fontSize) > TEXT_WIDTH) {
      lines.push(current);
      current = word;
      if (lines.length === maxLines - 1) {
        const rest = [current, ...words.slice(i + 1)].join(" ");
        lines.push(rest);
        return lines;
      }
    } else {
      current = next;
    }
  }
  if (current) lines.push(current);
  return lines.slice(0, maxLines);
}

function estimateWidth(text: string, fontSize: number): number {
  return [...text].length * fontSize * 0.55;
}

function trimToWidth(text: string, fontSize: number): string {
  if (estimateWidth(text, fontSize) <= TEXT_WIDTH) return text;
  let out = text;
  while (out.length > 1 && estimateWidth(`${out}…`, fontSize) > TEXT_WIDTH) {
    out = out.slice(0, -1);
  }
  return `${out.trimEnd()}…`;
}
