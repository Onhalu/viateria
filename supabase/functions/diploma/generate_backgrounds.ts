/**
 * Temporary 1080×1080 backgrounds. Final artwork replaces these later.
 *   deno run --allow-write supabase/functions/diploma/generate_backgrounds.ts
 */
import { encodeRgbaPng } from "./png.ts";

const variants: Array<[number, number]> = [
  [0x1b4332, 0x95d5b2],
  [0xf3e5c4, 0xc4a484],
  [0x1d3557, 0xa8dadc],
  [0x6f4e37, 0xe6ccb2],
];

function channel(color: number, shift: number): number {
  return (color >> shift) & 0xff;
}

function gradient(from: number, to: number): Uint8Array {
  const rgba = new Uint8Array(1080 * 1080 * 4);
  for (let y = 0; y < 1080; y++) {
    const t = y / 1079;
    const r = Math.round(channel(from, 16) + (channel(to, 16) - channel(from, 16)) * t);
    const g = Math.round(channel(from, 8) + (channel(to, 8) - channel(from, 8)) * t);
    const b = Math.round(channel(from, 0) + (channel(to, 0) - channel(from, 0)) * t);
    for (let x = 0; x < 1080; x++) {
      const i = (y * 1080 + x) * 4;
      rgba[i] = r;
      rgba[i + 1] = g;
      rgba[i + 2] = b;
      rgba[i + 3] = 255;
    }
  }
  return rgba;
}

const dir = new URL("./assets/bg/", import.meta.url);
await Deno.mkdir(dir, { recursive: true });
for (let i = 0; i < variants.length; i++) {
  const [from, to] = variants[i];
  const png = await encodeRgbaPng(1080, 1080, gradient(from, to));
  const path = new URL(`${i + 1}.png`, dir);
  await Deno.writeFile(path, png);
  console.log(`wrote ${path.pathname} (${png.byteLength} bytes)`);
}
