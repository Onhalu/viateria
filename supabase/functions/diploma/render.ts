import { Resvg, initWasm } from "npm:@resvg/resvg-wasm@2.6.2";
import { diplomaCopy, layoutTitle, type IssuedDiplomaRow } from "./access.ts";

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

const BUNDLED_ASSET_FALLBACK_COMMIT = "8b6c07d";
const BUNDLED_ASSET_FALLBACK_BASE =
  `https://raw.githubusercontent.com/Onhalu/viateria/${BUNDLED_ASSET_FALLBACK_COMMIT}/supabase/functions/diploma/assets/`;
/** Assets added after the pinned commit resolve from their original repo path. */
const BUNDLED_ASSET_FALLBACK_OVERRIDES: Record<string, string> = {
  // Ondřej-supplied lockup (assets/brand, commit be65ddf), copied verbatim.
  "logo/vandery-lockup.png":
    `https://raw.githubusercontent.com/Onhalu/viateria/${BUNDLED_ASSET_FALLBACK_COMMIT}/assets/brand/vandery-lockup@3x.png`,
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
};

export async function loadBundledRenderAssets(variant: number): Promise<RenderAssets> {
  const background = await readBundledAsset(`bg/${variant}.png`);
  const logo = await readBundledAsset(LOGO_ASSET);
  const font = await readBundledAsset("fonts/PlayfairDisplay.ttf");
  return { background, logo, font };
}

// Layout follows Ondřej's reference (vyslapni.cz diploma), scaled to 1080.
const CANVAS = 1080;
const PANEL_W = 720; // ~67 % of the width
const PANEL_H = 870; // ~80 % of the height
const PANEL_X = (CANVAS - PANEL_W) / 2;
const PANEL_Y = (CANVAS - PANEL_H) / 2;
const PANEL_RADIUS = 34;
const PANEL_OPACITY = 0.55;
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
): Promise<Uint8Array> {
  await ensureWasm();
  const copy = diplomaCopy(row);
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
  const texts = lines.map((line, index) => {
    if (index > 0) y += line.gapBefore;
    return `<text x="${CX}" y="${Math.round(y)}" font-size="${line.size}" font-family="Playfair Display" text-anchor="middle" fill="#000000">${xml(line.text)}</text>`;
  }).join("\n    ");

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
    <rect x="${PANEL_X}" y="${PANEL_Y}" width="${PANEL_W}" height="${PANEL_H}" rx="${PANEL_RADIUS}" ry="${PANEL_RADIUS}" fill="#ffffff" fill-opacity="${PANEL_OPACITY}"/>
    <image href="${dataUrl(assets.logo, "image/png")}" x="${CX - LOGO_W / 2}" y="${logoY}" width="${LOGO_W}" height="${LOGO_H}" filter="url(#black)"/>
    ${texts}
  </g>
</svg>`;

  const resvg = new Resvg(svg, {
    fitTo: { mode: "width", value: CANVAS },
    font: {
      fontBuffers: [assets.font],
      loadSystemFonts: false,
      defaultFontFamily: "Playfair Display",
    },
  });
  return resvg.render().asPng();
}
