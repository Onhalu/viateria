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

export async function readBundledAsset(relativePath: string): Promise<Uint8Array> {
  const hit = assetCache.get(relativePath);
  if (hit) return hit;
  const bytes = await Deno.readFile(new URL(`./assets/${relativePath}`, import.meta.url));
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

export type RenderAssets = {
  background: Uint8Array;
  logo: Uint8Array;
  font: Uint8Array;
};

export async function loadBundledRenderAssets(variant: number): Promise<RenderAssets> {
  const background = await readBundledAsset(`bg/${variant}.png`);
  const logo = await readBundledAsset("logo/vandery-mark.png");
  const font = await readBundledAsset("fonts/PlayfairDisplay.ttf");
  return { background, logo, font };
}

/**
 * 1080×1080 PNG with a transparent rounded rect (r60).
 * imagescript cannot draw Playfair, so the layout is SVG rasterized by resvg.
 */
export async function renderDiploma(
  row: IssuedDiplomaRow,
  assets: RenderAssets,
): Promise<Uint8Array> {
  await ensureWasm();
  const copy = diplomaCopy(row);
  const title = layoutTitle(copy.title);
  const titleStart = 760;
  const titleLines = title.lines.map((line, index) => {
    const y = titleStart + index * Math.round(title.fontSize * 1.15);
    return `<text x="540" y="${y}" font-size="${title.fontSize}" font-family="Playfair Display" text-anchor="middle" fill="#000000">${xml(line)}</text>`;
  }).join("");
  const durationY = titleStart + title.lines.length * Math.round(title.fontSize * 1.15) + 36;

  const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg width="1080" height="1080" viewBox="0 0 1080 1080" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="sheet"><rect width="1080" height="1080" rx="60" ry="60"/></clipPath>
  </defs>
  <g clip-path="url(#sheet)">
    <image href="${dataUrl(assets.background, "image/png")}" width="1080" height="1080"/>
    <rect x="180" y="180" width="720" height="720" rx="50" ry="50" fill="#ffffff" fill-opacity="0.745"/>
    <image href="${dataUrl(assets.logo, "image/png")}" x="430" y="120" width="220" height="220"/>
    <text x="540" y="430" font-size="100" font-family="Playfair Display" text-anchor="middle" fill="#000000">${xml(copy.headline)}</text>
    <text x="540" y="490" font-size="40" font-family="Playfair Display" text-anchor="middle" fill="#000000">${xml(copy.preposition)}</text>
    <text x="540" y="570" font-size="60" font-family="Playfair Display" text-anchor="middle" fill="#000000">${xml(copy.name)}</text>
    <text x="540" y="650" font-size="40" font-family="Playfair Display" text-anchor="middle" fill="#000000">${xml(copy.body)}</text>
    ${titleLines}
    <text x="540" y="${durationY}" font-size="40" font-family="Playfair Display" text-anchor="middle" fill="#000000">${xml(copy.duration)}</text>
  </g>
</svg>`;

  const resvg = new Resvg(svg, {
    fitTo: { mode: "width", value: 1080 },
    font: {
      fontBuffers: [assets.font],
      loadSystemFonts: false,
      defaultFontFamily: "Playfair Display",
    },
  });
  return resvg.render().asPng();
}
