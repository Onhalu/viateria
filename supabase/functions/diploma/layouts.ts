import type { Measure } from "./measure.ts";

/** Layout variants from SPEC-variants.md (UX 2026-10-08). "v4" = prod layout. */
export type DiplomaLayout = "v4" | "A" | "B" | "C" | "D";

export type DiplomaText = {
  headline: string;
  preposition: string;
  name: string;
  body: string;
  title: string;
  duration: string;
};

export type Panel = { x: number; y: number; w: number; h: number; r: number; opacity: number };
export type DrawOp =
  | {
    kind: "text";
    text: string;
    size: number;
    x: number;
    y: number;
    anchor: "middle" | "start";
    letterSpacing?: number;
    opacity?: number;
    italic?: boolean;
  }
  | { kind: "rule"; x0: number; x1: number; y: number; opacity: number }
  | { kind: "logo"; x: number; y: number; w: number; h: number };

export type LayoutResult = { panel: Panel; ops: DrawOp[] };

const CANVAS = 1080;
const CX = CANVAS / 2;
/** Playfair Display cap height / em. */
const CAP = 0.708;
const LOGO_ASPECT = 557 / 960;

type Item = { key: string; size: number; gap: number };

function wrap(measure: Measure, text: string, size: number, maxW: number): string[] {
  const words = text.split(/\s+/).filter((w) => w.length > 0);
  const lines: string[] = [];
  let current = "";
  for (const word of words) {
    const next = current ? `${current} ${word}` : word;
    if (current && measure(next, size) > maxW) {
      lines.push(current);
      current = word;
    } else {
      current = next;
    }
  }
  if (current) lines.push(current);
  return lines;
}

function ellipsize(measure: Measure, text: string, size: number, maxW: number): string {
  if (measure(text, size) <= maxW) return text;
  let chars = [...text];
  while (chars.length > 1 && measure(`${chars.join("")}…`, size) > maxW) {
    chars = chars.slice(0, -1);
  }
  return `${chars.join("").trimEnd()}…`;
}

/** Max 2 lines, break on spaces only, step the size down, ellipsis last. */
export function fitTitle(
  measure: Measure,
  title: string,
  steps: number[],
  maxW: number,
): { lines: string[]; size: number } {
  const clean = title.trim();
  if (!clean) return { lines: [""], size: steps[0] };
  for (const size of steps) {
    const lines = wrap(measure, clean, size, maxW);
    if (lines.length <= 2 && lines.every((l) => measure(l, size) <= maxW)) {
      return { lines, size };
    }
  }
  const size = steps[steps.length - 1];
  const lines = wrap(measure, clean, size, maxW);
  if (lines.length === 1) return { lines: [ellipsize(measure, lines[0], size, maxW)], size };
  return {
    lines: [
      ellipsize(measure, lines[0], size, maxW),
      ellipsize(measure, lines.slice(1).join(" "), size, maxW),
    ],
    size,
  };
}

/** One line shrinking base → min; then 2 lines at min; then ellipsis. */
export function fitName(
  measure: Measure,
  name: string,
  base: number,
  min: number,
  maxW: number,
): { lines: string[]; size: number } {
  const w = measure(name, base);
  const size = w <= maxW ? base : Math.max(min, Math.floor(base * maxW / w));
  if (measure(name, size) <= maxW) return { lines: [name], size };
  let lines = wrap(measure, name, min, maxW);
  if (lines.length > 2) lines = [lines[0], lines.slice(1).join(" ")];
  return { lines: lines.map((l) => ellipsize(measure, l, min, maxW)), size: min };
}

/** Centre the group (cap-top of first line → last baseline) in [top, bottom]. */
function stack(items: Item[], top: number, bottom: number): Record<string, number> {
  let y = 0;
  const rel = items.map((item, i) => {
    y = i === 0 ? 0 : y + item.gap;
    return { key: item.key, y };
  });
  const groupTop = -items[0].size * CAP;
  const groupBottom = rel[rel.length - 1].y;
  const offset = top + ((bottom - top) - (groupBottom - groupTop)) / 2 - groupTop;
  return Object.fromEntries(rel.map((r) => [r.key, Math.round(offset + r.y)]));
}

function nameItems(name: { lines: string[]; size: number }, gap: number): Item[] {
  const out: Item[] = [{ key: "n0", size: name.size, gap }];
  if (name.lines.length > 1) out.push({ key: "n1", size: name.size, gap: Math.round(name.size * 1.15) });
  return out;
}

function titleItems(title: { lines: string[]; size: number }, gap: number, lh: number): Item[] {
  return title.lines.map((_, i) => ({ key: `t${i}`, size: title.size, gap: i === 0 ? gap : Math.round(title.size * lh) }));
}

function text(
  t: string,
  size: number,
  y: number,
  extra: Partial<Extract<DrawOp, { kind: "text" }>> = {},
): DrawOp {
  return { kind: "text", text: t, size, x: CX, y, anchor: "middle", ...extra };
}

function logo(w: number, x: number, y: number): { op: DrawOp; h: number } {
  const h = Math.round(w * LOGO_ASPECT);
  return { op: { kind: "logo", x, y, w, h }, h };
}

function linesOps(
  lines: string[],
  size: number,
  b: Record<string, number>,
  prefix: string,
): DrawOp[] {
  return lines.map((l, i) => text(l, size, b[`${prefix}${i}`]));
}

export function layoutVariant(
  layout: Exclude<DiplomaLayout, "v4">,
  copy: DiplomaText,
  measure: Measure,
  hasItalic: boolean,
): LayoutResult {
  const headline = copy.headline.toLocaleUpperCase("cs");
  switch (layout) {
    case "A": {
      const panel = { x: 180, y: 105, w: 720, h: 870, r: 34, opacity: 0.55 };
      const maxW = panel.w - 2 * 64;
      const lg = logo(168, CX - 84, panel.y + 64);
      const dateY = panel.y + panel.h - 64;
      const title = fitTitle(measure, copy.title, [44, 38, 32], maxW);
      const name = fitName(measure, copy.name, 68, 46, maxW);
      const b = stack([
        { key: "head", size: 46, gap: 0 },
        { key: "pro", size: 28, gap: 92 },
        ...nameItems(name, Math.round(name.size * 1.09)),
        { key: "body", size: 28, gap: 98 },
        ...titleItems(title, 70, 1.22),
      ], panel.y + 64 + lg.h, dateY - 28 * CAP);
      return {
        panel,
        ops: [
          lg.op,
          text(headline, 46, b.head, { letterSpacing: 0.16 * 46 }),
          text(copy.preposition, 28, b.pro),
          ...linesOps(name.lines, name.size, b, "n"),
          text(copy.body, 28, b.body),
          ...linesOps(title.lines, title.size, b, "t"),
          text(copy.duration, 28, dateY, { letterSpacing: 0.03 * 28 }),
        ],
      };
    }
    case "B": {
      const panel = { x: 180, y: 105, w: 720, h: 870, r: 34, opacity: 0.62 };
      const maxW = panel.w - 2 * 72;
      const lg = logo(136, CX - 68, panel.y + 60);
      const dateY = panel.y + panel.h - 60;
      const rule2Y = dateY - 56;
      const title = fitTitle(measure, copy.title, [42, 38, 32], maxW);
      const name = fitName(measure, copy.name, 76, 48, maxW);
      const b = stack([
        { key: "head", size: 24, gap: 0 },
        { key: "rule1", size: 0, gap: 44 },
        { key: "pro", size: 30, gap: 76 },
        ...nameItems(name, Math.round(name.size * 1.1)),
        { key: "body", size: 30, gap: 100 },
        ...titleItems(title, 66, 1.24),
      ], panel.y + 60 + lg.h, rule2Y - 24);
      const muted = { opacity: 0.75, italic: hasItalic };
      return {
        panel,
        ops: [
          lg.op,
          text(headline, 24, b.head, { letterSpacing: 0.42 * 24 }),
          { kind: "rule", x0: CX - 32, x1: CX + 32, y: b.rule1, opacity: 0.35 },
          text(copy.preposition, 30, b.pro, muted),
          ...linesOps(name.lines, name.size, b, "n"),
          text(copy.body, 30, b.body, muted),
          ...linesOps(title.lines, title.size, b, "t"),
          { kind: "rule", x0: CX - 32, x1: CX + 32, y: rule2Y, opacity: 0.35 },
          text(copy.duration, 24, dateY, { letterSpacing: 0.08 * 24 }),
        ],
      };
    }
    case "C": {
      const panel = { x: 180, y: 105, w: 720, h: 870, r: 34, opacity: 0.6 };
      const pad = 64;
      const maxW = panel.w - 2 * pad;
      const left = panel.x + pad;
      const right = panel.x + panel.w - pad;
      const headY = panel.y + 64 + Math.round(72 * CAP);
      const logoW = 132;
      const logoH = Math.round(logoW * LOGO_ASPECT);
      const logoY = panel.y + panel.h - 56 - logoH;
      const ruleY = logoY - 36;
      const dateY = Math.round(logoY + logoH / 2 + 24 * CAP / 2);
      const title = fitTitle(measure, copy.title, [44, 38, 32], maxW);
      const name = fitName(measure, copy.name, 70, 46, maxW);
      const b = stack([
        { key: "pro", size: 28, gap: 0 },
        ...nameItems(name, Math.round(name.size * 1.09)),
        { key: "body", size: 28, gap: 100 },
        ...titleItems(title, 70, 1.22),
      ], headY + 20, ruleY - 10);
      return {
        panel,
        ops: [
          text(headline, 72, headY, { letterSpacing: 0.12 * 72 }),
          text(copy.preposition, 28, b.pro),
          ...linesOps(name.lines, name.size, b, "n"),
          text(copy.body, 28, b.body),
          ...linesOps(title.lines, title.size, b, "t"),
          { kind: "rule", x0: left, x1: right, y: ruleY, opacity: 0.28 },
          logo(logoW, right - logoW, logoY).op,
          { kind: "text", text: copy.duration, size: 24, x: left, y: dateY, anchor: "start", letterSpacing: 0.06 * 24 },
        ],
      };
    }
    case "D": {
      const panel = { x: 120, y: 140, w: 840, h: 800, r: 34, opacity: 0.72 };
      const maxW = panel.w - 2 * 72;
      const lg = logo(152, CX - 76, panel.y + 56);
      const dateY = panel.y + panel.h - 56;
      const title = fitTitle(measure, copy.title, [48, 42, 36], maxW);
      const name = fitName(measure, copy.name, 76, 50, maxW);
      const b = stack([
        { key: "head", size: 36, gap: 0 },
        { key: "pro", size: 28, gap: 92 },
        ...nameItems(name, name.size),
        { key: "body", size: 28, gap: 94 },
        ...titleItems(title, 72, 1.2),
      ], panel.y + 56 + lg.h, dateY - 28 * CAP); // 28 (not 26) matches the UX mockup rhythm
      return {
        panel,
        ops: [
          lg.op,
          text(headline, 36, b.head, { letterSpacing: 0.24 * 36 }),
          text(copy.preposition, 28, b.pro),
          ...linesOps(name.lines, name.size, b, "n"),
          text(copy.body, 28, b.body),
          ...linesOps(title.lines, title.size, b, "t"),
          text(copy.duration, 26, dateY, { letterSpacing: 0.04 * 26 }),
        ],
      };
    }
  }
}
