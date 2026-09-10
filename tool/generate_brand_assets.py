#!/usr/bin/env python3
"""Rasterize VANDERY mark + lockup (color and cream-on-primary) at 1x/2x/3x."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FOREST = (0x35, 0x48, 0x3C, 255)
SAGE = (0x9C, 0x9A, 0x7B, 255)
CREAM = (0xF3, 0xEF, 0xE5, 255)

FONT_PATH = Path("/tmp/vandery-fonts/Jost-Medium.ttf")
ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets" / "brand"

# High-res working canvas for the mark (square). Downscaled per density.
MARK_MASTER = 1024
# Needle rotation: NW, matching the supplied lockup.
NEEDLE_DEG = -42
# Cardinal gaps in the ring, in degrees.
GAP_DEG = 16


def _rotate(x: float, y: float, cx: float, cy: float, deg: float) -> tuple[float, float]:
    rad = math.radians(deg)
    dx, dy = x - cx, y - cy
    return (
        cx + dx * math.cos(rad) - dy * math.sin(rad),
        cy + dx * math.sin(rad) + dy * math.cos(rad),
    )


def draw_mark(size: int, ring: tuple[int, int, int, int], needle: tuple[int, int, int, int]) -> Image.Image:
    """Draw a transparent compass mark at `size` px square."""
    master = Image.new("RGBA", (MARK_MASTER, MARK_MASTER), (0, 0, 0, 0))
    draw = ImageDraw.Draw(master)
    cx = cy = MARK_MASTER / 2
    # Ring sits inside a small margin so 1.5pt strokes don't clip.
    margin = 72
    bbox = [margin, margin, MARK_MASTER - margin, MARK_MASTER - margin]
    stroke = 88
    # PIL: 0° is 3 o'clock, clockwise. Center gaps on N/E/S/W.
    half_gap = GAP_DEG / 2
    starts = [0 + half_gap, 90 + half_gap, 180 + half_gap, 270 + half_gap]
    span = 90 - GAP_DEG
    for start in starts:
        draw.arc(bbox, start=start, end=start + span, fill=ring, width=stroke)

    # Diamond compass needle — long NW tip, short SE tail, shoulders near center.
    tip = (cx, cy - 348)
    left = (cx - 128, cy + 8)
    tail = (cx, cy + 188)
    right = (cx + 128, cy + 8)
    kite = [_rotate(*pt, cx, cy, NEEDLE_DEG) for pt in (tip, right, tail, left)]
    draw.polygon(kite, fill=needle)

    # Slight blur then resize for clean edges.
    master = master.filter(ImageFilter.GaussianBlur(radius=0.6))
    return master.resize((size, size), Image.Resampling.LANCZOS)


def draw_tracked_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int, int],
    center_x: float,
    baseline_y: float,
    tracking: float,
) -> None:
    widths = [font.getlength(ch) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = center_x - total / 2
    for ch, width in zip(text, widths):
        draw.text((x, baseline_y), ch, font=font, fill=fill, anchor="ls")
        x += width + tracking


def draw_lockup(
    width: int,
    ring: tuple[int, int, int, int],
    needle: tuple[int, int, int, int],
    word: tuple[int, int, int, int],
) -> Image.Image:
    """Lockup: mark above tracked VANDERY wordmark. Transparent background."""
    # Proportions from the supplied cream lockup: mark ~0.62 of word width.
    mark_size = int(width * 0.58)
    pad_x = int(width * 0.04)
    pad_top = int(width * 0.02)
    gap = int(width * 0.06)
    font_size = int(width * 0.118)
    tracking = font_size * 0.28
    font = ImageFont.truetype(str(FONT_PATH), font_size)
    # Word row height.
    word_h = int(font_size * 1.25)
    pad_bot = int(width * 0.04)
    height = pad_top + mark_size + gap + word_h + pad_bot
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    mark = draw_mark(mark_size, ring, needle)
    mx = (width - mark_size) // 2
    canvas.alpha_composite(mark, (mx, pad_top))
    draw = ImageDraw.Draw(canvas)
    baseline = pad_top + mark_size + gap + font_size
    draw_tracked_text(
        draw,
        "VANDERY",
        font,
        word,
        center_x=width / 2,
        baseline_y=baseline,
        tracking=tracking,
    )
    return canvas


def save_density(image_1x: Image.Image, dest_name: str, sizes: list[tuple[str, int]]) -> None:
    """sizes: (folder or '', width). Height scales with aspect."""
    w0, h0 = image_1x.size
    for folder, width in sizes:
        height = max(1, round(h0 * (width / w0)))
        out = image_1x.resize((width, height), Image.Resampling.LANCZOS)
        directory = BRAND if folder == "" else BRAND / folder
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / dest_name
        out.save(path, "PNG", optimize=True)
        print(f"wrote {path.relative_to(ROOT)} ({out.size[0]}x{out.size[1]})")


def main() -> None:
    BRAND.mkdir(parents=True, exist_ok=True)

    # Generate masters at 3x then derive 1x/2x so every density shares the same drawing.
    mark_3x = draw_mark(288, SAGE, FOREST)
    lockup_3x = draw_lockup(960, SAGE, FOREST, FOREST)
    mark_on_3x = draw_mark(288, CREAM, CREAM)
    lockup_on_3x = draw_lockup(960, CREAM, CREAM, CREAM)

    mark_sizes = [("", 96), ("2.0x", 192), ("3.0x", 288)]
    lockup_sizes = [("", 320), ("2.0x", 640), ("3.0x", 960)]

    save_density(mark_3x, "vandery-mark.png", mark_sizes)
    save_density(lockup_3x, "vandery-lockup.png", lockup_sizes)
    save_density(mark_on_3x, "vandery-mark-on-primary.png", mark_sizes)
    save_density(lockup_on_3x, "vandery-lockup-on-primary.png", lockup_sizes)

    # Also keep @2x/@3x filename copies next to 1x for tooling that expects that layout.
    for src_folder, suffix in (("2.0x", "@2x"), ("3.0x", "@3x")):
        for name in (
            "vandery-mark.png",
            "vandery-lockup.png",
            "vandery-mark-on-primary.png",
            "vandery-lockup-on-primary.png",
        ):
            src = BRAND / src_folder / name
            dest = BRAND / name.replace(".png", f"{suffix}.png")
            Image.open(src).save(dest, "PNG", optimize=True)
            print(f"wrote {dest.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
