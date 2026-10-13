const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(bytes: Uint8Array): number {
  let c = 0xffffffff;
  for (const byte of bytes) {
    c = CRC_TABLE[(c ^ byte) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type: string, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(12 + data.length);
  const view = new DataView(out.buffer);
  view.setUint32(0, data.length);
  out.set(new TextEncoder().encode(type), 4);
  out.set(data, 8);
  view.setUint32(8 + data.length, crc32(out.subarray(4, 8 + data.length)));
  return out;
}

function blobPart(data: Uint8Array): ArrayBuffer {
  return data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer;
}

async function deflate(data: Uint8Array): Promise<Uint8Array> {
  const stream = new Blob([blobPart(data)]).stream().pipeThrough(
    new CompressionStream("deflate"),
  );
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

async function inflate(data: Uint8Array): Promise<Uint8Array> {
  const stream = new Blob([blobPart(data)]).stream().pipeThrough(
    new DecompressionStream("deflate"),
  );
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

/** RGBA PNG. Scanlines use filter 0. */
export async function encodeRgbaPng(
  width: number,
  height: number,
  rgba: Uint8Array,
): Promise<Uint8Array> {
  const stride = width * 4;
  const raw = new Uint8Array((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw.set(rgba.subarray(y * stride, (y + 1) * stride), y * (stride + 1) + 1);
  }
  const ihdr = new Uint8Array(13);
  const view = new DataView(ihdr.buffer);
  view.setUint32(0, width);
  view.setUint32(4, height);
  ihdr[8] = 8;
  ihdr[9] = 6;
  const signature = Uint8Array.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const parts = [
    signature,
    chunk("IHDR", ihdr),
    chunk("IDAT", await deflate(raw)),
    chunk("IEND", new Uint8Array()),
  ];
  const size = parts.reduce((sum, part) => sum + part.length, 0);
  const png = new Uint8Array(size);
  let offset = 0;
  for (const part of parts) {
    png.set(part, offset);
    offset += part.length;
  }
  return png;
}

export type DecodedPng = {
  width: number;
  height: number;
  rgba: Uint8Array;
};

export async function decodeRgbaPng(png: Uint8Array): Promise<DecodedPng> {
  const view = new DataView(png.buffer, png.byteOffset, png.byteLength);
  let offset = 8;
  let width = 0;
  let height = 0;
  const idatParts: Uint8Array[] = [];
  while (offset + 8 <= png.length) {
    const length = view.getUint32(offset);
    const type = new TextDecoder().decode(png.subarray(offset + 4, offset + 8));
    const data = png.subarray(offset + 8, offset + 8 + length);
    if (type === "IHDR") {
      width = new DataView(data.buffer, data.byteOffset, data.byteLength).getUint32(0);
      height = new DataView(data.buffer, data.byteOffset, data.byteLength).getUint32(4);
    } else if (type === "IDAT") {
      idatParts.push(data);
    } else if (type === "IEND") {
      break;
    }
    offset += 12 + length;
  }
  const compressed = new Uint8Array(idatParts.reduce((sum, part) => sum + part.length, 0));
  let cursor = 0;
  for (const part of idatParts) {
    compressed.set(part, cursor);
    cursor += part.length;
  }
  const raw = await inflate(compressed);
  const stride = width * 4;
  const rgba = new Uint8Array(stride * height);
  let src = 0;
  for (let y = 0; y < height; y++) {
    const filter = raw[src++];
    const rowStart = y * stride;
    for (let x = 0; x < stride; x++) {
      const value = raw[src++];
      const left = x >= 4 ? rgba[rowStart + x - 4] : 0;
      const up = y > 0 ? rgba[rowStart - stride + x] : 0;
      const upLeft = y > 0 && x >= 4 ? rgba[rowStart - stride + x - 4] : 0;
      rgba[rowStart + x] = (value + recon(filter, left, up, upLeft)) & 0xff;
    }
  }
  return { width, height, rgba };
}

function recon(filter: number, left: number, up: number, upLeft: number): number {
  if (filter === 0) return 0;
  if (filter === 1) return left;
  if (filter === 2) return up;
  if (filter === 3) return (left + up) >> 1;
  const p = left + up - upLeft;
  const pa = Math.abs(p - left);
  const pb = Math.abs(p - up);
  const pc = Math.abs(p - upLeft);
  if (pa <= pb && pa <= pc) return left;
  if (pb <= pc) return up;
  return upLeft;
}

export function pixelAlpha(decoded: DecodedPng, x: number, y: number): number {
  return decoded.rgba[(y * decoded.width + x) * 4 + 3];
}
