import { Resvg, initWasm } from "npm:@resvg/resvg-wasm@2.6.2";
import { diplomaCopy, layoutTitle, type IssuedDiplomaRow } from "./access.ts";
import { type DiplomaLayout, type DrawOp, type LayoutResult, layoutVariant } from "./layouts.ts";
import { createMeasure, type Measure } from "./measure.ts";

export type { DiplomaLayout } from "./layouts.ts";
/** Active layout: "B" (Editoriál, chosen 2026-10-08). "v4" = previous prod; "A"–"D" from SPEC-variants.md. */
export const DIPLOMA_LAYOUT: DiplomaLayout = "B";

let wasmReady: Promise<void> | null = null;

async function ensureWasm(): Promise<void> {
  if (!wasmReady) {
    wasmReady = (async () => {
      const wasmUrl = import.meta.resolve(
        "npm:@resvg/resvg-wasm@2.6.2/index_bg.wasm",
      );
      const bytes = await Deno.readFile(new URL(wasmUrl));
      await initWasm(bytes);
    })();
  }
  await wasmReady;
}

const assetCache = new Map<string, Uint8Array>();

/** Branch commit that has every asset below at the function path. */
const BUNDLED_ASSET_FALLBACK_COMMIT = "f885408";
const BUNDLED_ASSET_FALLBACK_BASE =
  `https://raw.githubusercontent.com/Onhalu/viateria/${BUNDLED_ASSET_FALLBACK_COMMIT}/supabase/functions/diploma/assets/`;
/** Assets newer than the pinned commit resolve from a pinned upstream copy. */
const BUNDLED_ASSET_FALLBACK_OVERRIDES: Record<string, string> = {
  // OFL, byte-identical to assets/fonts/PlayfairDisplay-Italic.ttf (google/fonts @ 1e1aa08).
  "fonts/PlayfairDisplay-Italic.ttf":
    "https://raw.githubusercontent.com/google/fonts/1e1aa08e994ff7db50116e86ccc7b52a4e4ae5b8/ofl/playfairdisplay/PlayfairDisplay-Italic%5Bwght%5D.ttf",
};

export async function readBundledAsset(relativePath: string): Promise<Uint8Array> {
  const hit = assetCache.get(relativePath);
  if (hit) return hit;
  let bytes: Uint8Array;
  try {
    bytes = await Deno.readFile(new URL(`./assets/${relativePath}`, import.meta.url));
  } catch {
    // MCP/text deploys may omit binary assets; bucket is preferred in index.ts.
    const url = BUNDLED_ASSET_FALLBACK_OVERRIDES[relativePath] ??
      `${BUNDLED_ASSET_FALLBACK_BASE}${relativePath}`;
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`bundled asset missing: ${relativePath} (${res.status})`);
    }
    bytes = new Uint8Array(await res.arrayBuffer());
  }
  assetCache.set(relativePath, bytes);
  return bytes;
}

function xml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function dataUrl(bytes: Uint8Array, mime: string): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return `data:${mime};base64,${btoa(binary)}`;
}

/** VANDERY lockup (compass + wordmark), 960×557, recoloured black in the SVG. */
export const LOGO_ASSET = "logo/vandery-lockup.png";
const LOGO_ASPECT = 557 / 960;

export type RenderAssets = {
  background: Uint8Array;
  logo: Uint8Array;
  font: Uint8Array;
  /** PlayfairDisplay-Italic.ttf (OFL, google/fonts). Optional: layout B falls back to Regular. */
  fontItalic?: Uint8Array | null;
};

export const ITALIC_FONT_ASSET = "fonts/PlayfairDisplay-Italic.ttf";

export async function loadBundledRenderAssets(variant: number): Promise<RenderAssets> {
  const background = await readBundledAsset(`bg/${variant}.png`);
  const logo = await readBundledAsset(LOGO_ASSET);
  const font = await readBundledAsset("fonts/PlayfairDisplay.ttf");
  let fontItalic: Uint8Array | null = null;
  try {
    fontItalic = await readBundledAsset(ITALIC_FONT_ASSET);
  } catch {
    fontItalic = null;
  }
  return { background, logo, font, fontItalic };
}

const measureCache = new WeakMap<Uint8Array, Measure>();
function measureFor(font: Uint8Array): Measure {
  let m = measureCache.get(font);
  if (!m) {
    m = createMeasure(font);
    measureCache.set(font, m);
  }
  return m;
}

function opSvg(op: DrawOp, logoHref: string): string {
  switch (op.kind) {
    case "logo":
      return `<image href="${logoHref}" x="${op.x}" y="${op.y}" width="${op.w}" height="${op.h}" filter="url(#black)"/>`;
    case "rule":
      return `<rect x="${op.x0}" y="${op.y}" width="${op.x1 - op.x0}" height="1" fill="#000000" fill-opacity="${op.opacity}"/>`;
    case "text": {
      // resvg 2.6.2 adds letter-spacing between glyphs only and centres the
      // spaced run correctly (pixel-checked), so no x − ls/2 compensation.
      const ls = op.letterSpacing ? ` letter-spacing="${op.letterSpacing.toFixed(2)}"` : "";
      const opacity = op.opacity != null && op.opacity < 1 ? ` fill-opacity="${op.opacity}"` : "";
      const italic = op.italic ? ` font-style="italic"` : "";
      return `<text x="${op.x}" y="${op.y}" font-size="${op.size}" font-family="Playfair Display"${italic} text-anchor="${op.anchor}"${ls} fill="#000000"${opacity}>${xml(op.text)}</text>`;
    }
  }
}

function variantBody(result: LayoutResult, logoHref: string): string {
  const p = result.panel;
  return [
    `<rect x="${p.x}" y="${p.y}" width="${p.w}" height="${p.h}" rx="${p.r}" ry="${p.r}" fill="#ffffff" fill-opacity="${p.opacity}"/>`,
    ...result.ops.map((op) => opSvg(op, logoHref)),
  ].join("\n    ");
}

// Layout follows Ondřej's reference (vyslapni.cz diploma), scaled to 1080.
const CANVAS = 1080;
const PANEL_W = 720; // ~67 % of the width
const PANEL_H = 870; // ~80 % of the height
const PANEL_X = (CANVAS - PANEL_W) / 2;
const PANEL_Y = (CANVAS - PANEL_H) / 2;
const PANEL_RADIUS = 34;
const PANEL_OPACITY = 0.55;
/** Date line baseline sits this far above the panel's bottom edge. */
const DATE_BOTTOM_PADDING = 56;
const LOGO_W = 250;
const LOGO_H = Math.round(LOGO_W * LOGO_ASPECT);
const CX = CANVAS / 2;

type Line = { text: string; size: number; gapBefore: number };

/**
 * 1080×1080 PNG with transparent rounded corners (r60). A translucent white
 * panel holds every element: black lockup, DIPLOM, pro, name, body, title,
 * date. imagescript cannot draw Playfair, so the layout is SVG rasterized by resvg.
 */
export async function renderDiploma(
  row: IssuedDiplomaRow,
  assets: RenderAssets,
  layout: DiplomaLayout = DIPLOMA_LAYOUT,
): Promise<Uint8Array> {
  await ensureWasm();
  const copy = diplomaCopy(row);
  const logoHref = dataUrl(assets.logo, "image/png");
  let body: string;
  if (layout === "v4") {
    body = v4Body(copy, logoHref);
  } else {
    const result = layoutVariant(layout, copy, measureFor(assets.font), !!assets.fontItalic);
    body = variantBody(result, logoHref);
  }

  const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${CANVAS}" height="${CANVAS}" viewBox="0 0 ${CANVAS} ${CANVAS}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="sheet"><rect width="${CANVAS}" height="${CANVAS}" rx="60" ry="60"/></clipPath>
    <filter id="black" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB">
      <feColorMatrix type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0"/>
    </filter>
  </defs>
  <g clip-path="url(#sheet)">
    <image href="${dataUrl(assets.background, "image/png")}" width="${CANVAS}" height="${CANVAS}"/>
    ${body}
  </g>
</svg>`;

  const fontBuffers = assets.fontItalic ? [assets.font, assets.fontItalic] : [assets.font];
  const resvg = new Resvg(svg, {
    fitTo: { mode: "width", value: CANVAS },
    font: {
      fontBuffers,
      loadSystemFonts: false,
      defaultFontFamily: "Playfair Display",
    },
  });
  return resvg.render().asPng();
}

/** Prod v4 layout, unchanged. */
function v4Body(copy: ReturnType<typeof diplomaCopy>, logoHref: string): string {
  const title = layoutTitle(copy.title);
  const titleLineHeight = Math.round(title.fontSize * 1.15);

  // Baseline-to-baseline gaps (gapBefore) measured on the reference.
  const lines: Line[] = [
    { text: copy.headline, size: 92, gapBefore: 0 },
    { text: copy.preposition, size: 36, gapBefore: 72 },
    { text: copy.name, size: 58, gapBefore: 88 },
    { text: copy.body, size: 36, gapBefore: 66 },
    ...title.lines.map((text, index) => ({
      text,
      size: title.fontSize,
      gapBefore: index === 0 ? 86 : titleLineHeight,
    })),
    { text: copy.duration, size: 36, gapBefore: 64 },
  ];

  const logoToHeadline = 70 + 92 * 0.72; // logo bottom → DIPLOM baseline
  const textSpan = lines.reduce((sum, line) => sum + line.gapBefore, 0);
  const contentH = LOGO_H + logoToHeadline + textSpan + 12; // + descender
  const free = PANEL_H - contentH;
  // Reference keeps more air below than above (~1:3).
  const top = PANEL_Y + Math.max(40, Math.round(free * 0.3));

  const logoY = top;
  let y = logoY + LOGO_H + logoToHeadline;
  const lastIndex = lines.length - 1;
  const texts = lines.map((line, index) => {
    if (index > 0) y += line.gapBefore;
    // The date is anchored to the panel bottom; the block above keeps its place.
    if (index === lastIndex) y = PANEL_Y + PANEL_H - DATE_BOTTOM_PADDING;
    return `<text x="${CX}" y="${Math.round(y)}" font-size="${line.size}" font-family="Playfair Display" text-anchor="middle" fill="#000000">${xml(line.text)}</text>`;
  }).join("\n    ");

  return [
    `<rect x="${PANEL_X}" y="${PANEL_Y}" width="${PANEL_W}" height="${PANEL_H}" rx="${PANEL_RADIUS}" ry="${PANEL_RADIUS}" fill="#ffffff" fill-opacity="${PANEL_OPACITY}"/>`,
    `<image href="${logoHref}" x="${CX - LOGO_W / 2}" y="${logoY}" width="${LOGO_W}" height="${LOGO_H}" filter="url(#black)"/>`,
    texts,
  ].join("\n    ");
}
