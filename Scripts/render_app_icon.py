#!/usr/bin/env python3
"""Renders the Rhythm mark as a PNG at any size.

The icon is generated rather than drawn by hand so the App Store asset, the
favicon and the touch icon can never drift apart, and so the palette stays tied
to the one in Palette.swift. Anti-aliased by 3x supersampling; no image library
required.

    python3 Scripts/render_app_icon.py 1024 Rhythm/Resources/.../AppIcon-1024.png
    python3 Scripts/render_app_icon.py 180  web/apple-touch-icon.png
"""

import math
import pathlib
import struct
import sys
import zlib

# Dark-theme values from Palette.swift, so the icon reads as the same product.
BG_TOP = (0x14, 0x17, 0x22)
BG_BOTTOM = (0x08, 0x09, 0x0D)
GLOW = (0x1E, 0x23, 0x33)
RING_TRACK = (0x2A, 0x2E, 0x37)
ARC_START = (0x5C, 0x77, 0xFC)   # business blue
ARC_END = (0x0B, 0xA0, 0x5D)     # body green
BARS = (0xF5, 0xF6, 0xF8)

SUPERSAMPLE = 3
SWEEP_DEGREES = 300


def _to_srgb(linear):
    linear = max(0.0, min(1.0, linear))
    value = 12.92 * linear if linear <= 0.0031308 else 1.055 * (linear ** (1 / 2.4)) - 0.055
    return int(round(value * 255))


def _to_linear(byte):
    channel = byte / 255
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def _mix(a, b, t):
    """Blend in linear light — mixing sRGB bytes directly muddies the gradient."""
    return tuple(_to_srgb(_to_linear(a[i]) * (1 - t) + _to_linear(b[i]) * t) for i in range(3))


def render(size):
    centre = size / 2
    r_outer, r_inner = size * 0.335, size * 0.245
    bar_half_width = size * 0.019
    bars = [(-0.105, 0.150), (0.0, 0.215), (0.105, 0.150)]
    start_angle = -math.pi / 2
    sweep = math.radians(SWEEP_DEGREES)

    def arc_at(px, py):
        """Returns (state, t) — 1 for arc with gradient position, -1 for track."""
        dx, dy = px - centre, py - centre
        radius = math.hypot(dx, dy)
        if not (r_inner <= radius <= r_outer):
            return 0, 0.0
        angle = (math.atan2(dy, dx) - start_angle) % (2 * math.pi)
        return (1, angle / sweep) if angle <= sweep else (-1, 0.0)

    def bar_at(px, py):
        for offset_x, half_height in bars:
            bx = centre + offset_x * size
            if abs(px - bx) > bar_half_width or abs(py - centre) > half_height * size:
                continue
            overshoot = abs(py - centre) - (half_height * size - bar_half_width)
            if overshoot > 0 and math.hypot(px - bx, overshoot) > bar_half_width:
                continue
            return True
        return False

    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            accumulator = [0.0, 0.0, 0.0]
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    px = x + (sx + 0.5) / SUPERSAMPLE
                    py = y + (sy + 0.5) / SUPERSAMPLE
                    colour = _mix(BG_TOP, BG_BOTTOM, py / size)
                    distance = math.hypot(px - centre, py - centre) / (size * 0.6)
                    colour = _mix(colour, GLOW, max(0.0, 0.35 * (1 - distance)))
                    state, t = arc_at(px, py)
                    if state == 1:
                        colour = _mix(ARC_START, ARC_END, t)
                    elif state == -1:
                        colour = _mix(colour, RING_TRACK, 0.9)
                    if bar_at(px, py):
                        colour = BARS
                    for i in range(3):
                        accumulator[i] += colour[i]
            row += bytes(int(round(v / (SUPERSAMPLE ** 2))) for v in accumulator)
        rows.append(bytes(row))
    return rows


def write_png(path, size, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)
    return len(png)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: render_app_icon.py <size> <output.png>")
    size = int(sys.argv[1])
    if not 16 <= size <= 2048:
        sys.exit("size must be between 16 and 2048")
    path = pathlib.Path(sys.argv[2])
    written = write_png(path, size, render(size))
    print(f"wrote {path} — {size}x{size}, {written} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
