import opentype from "npm:opentype.js@1.3.4";

/** Fallback when the TTF cannot be parsed: Playfair Regular averages ~0.45–0.50 em. */
export const FALLBACK_EM_PER_CHAR = 0.52;

export type Measure = (text: string, size: number, letterSpacing?: number) => number;

/**
 * Advance width from the same TTF resvg draws with (kerning on). Within ~2 %
 * of resvg's ink box, slightly wider, so wrapping errs on the safe side.
 * resvg 2.6.2 applies letter-spacing between glyphs only (n − 1 gaps).
 */
export function createMeasure(fontBytes: Uint8Array): Measure {
  let font: opentype.Font | null = null;
  try {
    const copy = fontBytes.slice();
    font = opentype.parse(copy.buffer);
  } catch (error) {
    console.warn("diploma: font metrics unavailable, using estimate", error);
  }
  return (text, size, letterSpacing = 0) => {
    const glyphs = [...text].length;
    const base = font
      ? font.getAdvanceWidth(text, size, { kerning: true })
      : glyphs * size * FALLBACK_EM_PER_CHAR;
    return base + letterSpacing * Math.max(0, glyphs - 1);
  };
}
