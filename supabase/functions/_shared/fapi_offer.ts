/**
 * Read a FAPI sales-form offer (price + terms) from the public form page.
 *
 * FAPI embeds the form JSON in `script.php?id=<path>` as
 * `setAttribute('data-form-resource', "...")`. That payload is what the
 * form itself shows: item templates, one_time / special_one_time prices,
 * `terms_url`, and purpose links. No FAPI API secret is required.
 *
 * Authenticated `GET /item-templates?form=` (the planned `sync-fapi-prices`
 * cache) is not called here.
 */

import { httpUrlOrNull } from "./fapi.ts";

export type OfferTerm = {
  text: string;
  url: string | null;
};

export type OfferVariant = {
  price_cents: number | null;
  currency: string | null;
  terms_url: string | null;
  terms: OfferTerm[];
};

const EMPTY_VARIANT: OfferVariant = {
  price_cents: null,
  currency: null,
  terms_url: null,
  terms: [],
};

export function emptyOfferVariant(): OfferVariant {
  return { ...EMPTY_VARIANT, terms: [] };
}

/** Form path from a stored sales-form URL (`?id=`, `?path=`, or the last segment). */
export function formPathFromSaleUrl(formUrl: string): string | null {
  let url: URL;
  try {
    url = new URL(formUrl);
  } catch {
    return null;
  }
  const query = url.searchParams.get("id") ?? url.searchParams.get("path");
  if (query && isFormPath(query)) return query;
  const parts = url.pathname.split("/").filter((part) => part.length > 0);
  const last = parts[parts.length - 1];
  if (last && last !== "script.php" && isFormPath(last)) return last;
  return null;
}

function isFormPath(value: string): boolean {
  return /^[A-Za-z0-9_-]{6,}$/.test(value);
}

export function scriptUrlForSaleForm(formUrl: string): string | null {
  const path = formPathFromSaleUrl(formUrl);
  if (!path) return null;
  let url: URL;
  try {
    url = new URL(formUrl);
  } catch {
    return null;
  }
  return `${url.protocol}//${url.host}/script.php?id=${encodeURIComponent(path)}`;
}

/** Pull the JSON object out of FAPI's `data-form-resource` attribute. */
export function extractFormResource(
  script: string,
): Record<string, unknown> | null {
  const marker = "setAttribute('data-form-resource', \"";
  const start = script.indexOf(marker);
  if (start < 0) return null;
  let i = start + marker.length;
  let out = "";
  while (i < script.length) {
    const c = script[i];
    if (c === "\\") {
      const next = script[i + 1];
      if (
        next === "u" &&
        /^[0-9a-fA-F]{4}$/.test(script.slice(i + 2, i + 6))
      ) {
        out += String.fromCharCode(parseInt(script.slice(i + 2, i + 6), 16));
        i += 6;
        continue;
      }
      const mapped: Record<string, string> = {
        n: "\n",
        r: "\r",
        t: "\t",
        '"': '"',
        "\\": "\\",
        "/": "/",
      };
      out += next == null ? "" : (mapped[next] ?? next);
      i += 2;
      continue;
    }
    if (c === '"') break;
    out += c;
    i++;
  }
  try {
    const parsed = JSON.parse(out);
    return isRecord(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

export function offerFromFormResource(
  resource: Record<string, unknown>,
  now = new Date(),
): OfferVariant {
  const currency = stringOrNull(resource.currency_code)?.toLowerCase() ?? null;
  const showGross = resource.show_prices_including_vat !== false;
  const templates = templateMap(resource.item_templates);
  const items = recordsOf(resource.items);
  const required = items.filter((item) => item.required === true);
  const chosen = required.length > 0 ? required : items;

  let cents = 0;
  let priced = 0;
  let priceCurrency = currency;
  for (const item of chosen) {
    const templateId = item.item_template == null
      ? ""
      : String(item.item_template);
    const template = templates.get(templateId);
    if (!template) continue;
    const price = selectTemplatePrice(template, priceCurrency, now);
    if (!price) continue;
    const major = finiteNumber(price.price);
    if (major == null || major < 0) continue;
    cents += Math.round(grossMajor(major, template, showGross) * 100);
    priced++;
    const code = stringOrNull(price.currency_code)?.toLowerCase();
    if (code) priceCurrency = code;
  }

  const termsUrl = resource.allow_terms === false
    ? null
    : httpUrlOrNull(resource.terms_url);
  return {
    price_cents: priced > 0 ? cents : null,
    currency: priceCurrency,
    terms_url: termsUrl,
    terms: termsFromResource(resource, termsUrl),
  };
}

export async function fetchOfferForFormUrl(
  formUrl: string,
  now = new Date(),
): Promise<OfferVariant | null> {
  const scriptUrl = scriptUrlForSaleForm(formUrl);
  if (!scriptUrl) return null;
  const response = await fetch(scriptUrl, {
    headers: { Accept: "text/javascript, text/html, */*" },
    signal: AbortSignal.timeout(12000),
  });
  if (!response.ok) return null;
  const resource = extractFormResource(await response.text());
  if (!resource) return null;
  return offerFromFormResource(resource, now);
}

function termsFromResource(
  resource: Record<string, unknown>,
  termsUrl: string | null,
): OfferTerm[] {
  const out: OfferTerm[] = [];
  const seen = new Set<string>();
  const purposes = recordsOf(resource.purposes).sort((a, b) => {
    const rank = (row: Record<string, unknown>) => row.is_primary === true ? 0 : 1;
    return rank(a) - rank(b);
  });
  for (const purpose of purposes) {
    const href = httpUrlOrNull(purpose.link_href) ??
      firstHttpUrl(purpose.html) ??
      firstHttpUrl(purpose.checkbox_label);
    const text = plainText(purpose.checkbox_label) ||
      plainText(purpose.link_label) ||
      plainText(purpose.html);
    pushTerm(out, seen, { text, url: href });
  }
  if (termsUrl) pushTerm(out, seen, { text: "", url: termsUrl });
  return out.slice(0, 6);
}

function pushTerm(out: OfferTerm[], seen: Set<string>, term: OfferTerm) {
  const url = term.url;
  const text = term.text.trim();
  if (!url && !text) return;
  const key = url ? `url:${url}` : `text:${text}`;
  if (seen.has(key)) return;
  seen.add(key);
  out.push({ text, url });
}

function selectTemplatePrice(
  template: Record<string, unknown>,
  currency: string | null,
  now: Date,
): Record<string, unknown> | null {
  const prices = recordsOf(template.prices);
  const specials = prices.filter((price) =>
    price.type === "special_one_time" &&
    specialPriceActive(price, now) &&
    currencyMatches(price, currency)
  );
  if (specials.length > 0) return specials[0];
  const oneTime = prices.filter((price) =>
    price.type === "one_time" && currencyMatches(price, currency)
  );
  if (oneTime.length > 0) return oneTime[0];
  return prices.find((price) => price.type === "one_time") ?? null;
}

function specialPriceActive(
  price: Record<string, unknown>,
  now: Date,
): boolean {
  const metadata = asRecord(price.metadata);
  const special = metadata ? asRecord(metadata.special_price) : null;
  if (!special) return true;
  const begin = parseDay(special.begin_date);
  const end = parseDay(special.end_date);
  if (begin && now.getTime() < begin.getTime()) return false;
  if (end) {
    const endExclusive = new Date(end.getTime());
    endExclusive.setUTCDate(endExclusive.getUTCDate() + 1);
    if (now.getTime() >= endExclusive.getTime()) return false;
  }
  return true;
}

function currencyMatches(
  price: Record<string, unknown>,
  currency: string | null,
): boolean {
  if (!currency) return true;
  const code = stringOrNull(price.currency_code)?.toLowerCase();
  return code == null || code === currency;
}

function grossMajor(
  amount: number,
  template: Record<string, unknown>,
  showGross: boolean,
): number {
  if (template.including_vat !== false || !showGross) return amount;
  const vat = finiteNumber(template.vat) ?? 0;
  return amount * (1 + vat / 100);
}

function templateMap(
  value: unknown,
): Map<string, Record<string, unknown>> {
  const map = new Map<string, Record<string, unknown>>();
  for (const row of recordsOf(value)) {
    if (row.id == null) continue;
    map.set(String(row.id), row);
  }
  // Dict form is `{ "617084": { id, prices } }` — recordsOf already unwraps values.
  return map;
}

function recordsOf(value: unknown): Record<string, unknown>[] {
  if (Array.isArray(value)) return value.filter(isRecord);
  const record = asRecord(value);
  if (!record) return [];
  return Object.values(record).filter(isRecord);
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return isRecord(value) ? value : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function stringOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function finiteNumber(value: unknown): number | null {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function parseDay(value: unknown): Date | null {
  if (typeof value !== "string" || !value.trim()) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

export function plainText(value: unknown): string {
  if (typeof value !== "string") return "";
  return value
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&quot;/gi, '"')
    .replace(/\s+/g, " ")
    .trim();
}

export function firstHttpUrl(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const match = value.match(/https?:\/\/[^\s"'<>]+/i);
  if (!match) return null;
  return httpUrlOrNull(match[0].replace(/&amp;/gi, "&").replace(/[),.;]+$/, ""));
}
