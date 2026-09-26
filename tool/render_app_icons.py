#!/usr/bin/env python3
"""Draw the Wirdi app icon and write every size iOS and Android ask for.

The icon is a tasbih: a loop of 33 beads, two-thirds of them counted, closed
by the long imam bead and a tassel. It is described once, below, as circles,
one ellipse and two convex polygons, and everything else is generated from
that description:

    assets/icon/wirdi_icon.svg                    the master, for design tools
    ios/Runner/Assets.xcassets/AppIcon.appiconset every size in its Contents.json
    android/app/src/main/res/mipmap-*dpi/         legacy icon, and the adaptive
                                                  icon's foreground and
                                                  monochrome layers
    assets/icon/play_store_icon.png               the 512px icon for the Google
                                                  Play listing

Run it after changing the geometry or the palette:

    python3 tool/render_app_icons.py

The rasteriser is hand-rolled rather than cairosvg or Pillow, for the same
reason the other tools here parse by hand: every shape in the icon is a circle,
an ellipse or a convex polygon, and antialiasing those from a signed distance
is a page of standard library — cheaper to trust than a native dependency.
"""

from __future__ import annotations

import json
import math
import struct
import zlib
from array import array
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# The design is drawn on a 1024-unit square.
UNITS = 1024

# The light theme's surface, primary and tertiary (lib/theme/color_schemes.dart),
# and a muted brick for the beads not yet counted: dark enough to hold its own
# against the cream at small sizes, where a paler tint disappears.
CREAM = "#FBF6EC"
BRICK = "#9E4630"
UNCOUNTED = "#D9BFA7"
GOLD = "#8A6A2E"

# The loop.
BEADS = 33
COUNTED = 22
LOOP_CX, LOOP_CY, LOOP_R = 512, 434, 228
BEAD_R = 19
# Degrees left open either side of the bottom, where the imam bead hangs.
GAP = 16

# Android's adaptive icon: the layer is 108dp, the launcher shows at most the
# middle 72dp, and only a 66dp circle is guaranteed to survive every mask. The
# design is shrunk to sit at the same visual size inside the 72dp as it does on
# iOS, which puts it well inside that circle.
ADAPTIVE_SCALE = 0.68
# Uncounted beads in the monochrome layer, which the launcher tints: alpha is
# the only way left to tell them apart from the counted ones.
MONO_UNCOUNTED_ALPHA = 0.4


@dataclass(frozen=True)
class Circle:
    cx: float
    cy: float
    r: float
    colour: str


@dataclass(frozen=True)
class Ellipse:
    cx: float
    cy: float
    rx: float
    ry: float
    colour: str


@dataclass(frozen=True)
class Polygon:
    """Convex, with its points listed clockwise on screen (y pointing down)."""

    points: tuple[tuple[float, float], ...]
    colour: str


Shape = Circle | Ellipse | Polygon


def design() -> list[Shape]:
    shapes: list[Shape] = []
    span = 360 - 2 * GAP
    for i in range(BEADS):
        # Angles run clockwise from the top. The first bead sits just left of
        # the gap, so counting starts beside the imam bead and runs up the
        # left side and over the top.
        a = math.radians(180 + GAP + i * span / (BEADS - 1))
        x = LOOP_CX + LOOP_R * math.sin(a)
        y = LOOP_CY - LOOP_R * math.cos(a)
        shapes.append(Circle(x, y, BEAD_R, BRICK if i < COUNTED else UNCOUNTED))

    bottom = LOOP_CY + LOOP_R
    # The cord from the loop down to the imam bead.
    shapes.append(Polygon(((507, bottom - 6), (517, bottom - 6), (517, bottom + 30), (507, bottom + 30)), BRICK))
    shapes.append(Ellipse(512, bottom + 62, 25, 40, GOLD))
    # The tassel.
    shapes.append(Polygon(((504, bottom + 100), (520, bottom + 100), (550, bottom + 176), (474, bottom + 176)), BRICK))
    return shapes


def scaled(shapes: list[Shape], s: float) -> list[Shape]:
    """Shrink the design by `s` about the middle of the canvas."""

    def p(x: float, y: float) -> tuple[float, float]:
        return (UNITS / 2 + (x - UNITS / 2) * s, UNITS / 2 + (y - UNITS / 2) * s)

    out: list[Shape] = []
    for sh in shapes:
        if isinstance(sh, Circle):
            out.append(Circle(*p(sh.cx, sh.cy), sh.r * s, sh.colour))
        elif isinstance(sh, Ellipse):
            out.append(Ellipse(*p(sh.cx, sh.cy), sh.rx * s, sh.ry * s, sh.colour))
        else:
            out.append(Polygon(tuple(p(x, y) for x, y in sh.points), sh.colour))
    return out


def vertical_bounds(shapes: list[Shape]) -> tuple[float, float]:
    top, bottom = math.inf, -math.inf
    for sh in shapes:
        if isinstance(sh, Circle):
            top, bottom = min(top, sh.cy - sh.r), max(bottom, sh.cy + sh.r)
        elif isinstance(sh, Ellipse):
            top, bottom = min(top, sh.cy - sh.ry), max(bottom, sh.cy + sh.ry)
        else:
            ys = [y for _, y in sh.points]
            top, bottom = min(top, *ys), max(bottom, *ys)
    return top, bottom


# --- rasterising -------------------------------------------------------------


def rgb(hex_colour: str) -> tuple[float, float, float]:
    h = hex_colour.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))  # type: ignore[return-value]


class Canvas:
    """Straight-alpha RGBA, one float per channel, composited source-over."""

    def __init__(self, size: int, background: str | None) -> None:
        self.size = size
        n = size * size
        r, g, b = rgb(background) if background else (0.0, 0.0, 0.0)
        a = 1.0 if background else 0.0
        self.r, self.g, self.b = array("d", [r]) * n, array("d", [g]) * n, array("d", [b]) * n
        self.a = array("d", [a]) * n

    def draw(self, shape: Shape, colour: str | None = None, alpha: float = 1.0) -> None:
        k = self.size / UNITS  # pixels per design unit
        cr, cg, cb = rgb(colour or shape.colour)
        x0, y0, x1, y1 = _bounds(shape)
        for py in range(max(0, int(y0 * k) - 1), min(self.size, int(y1 * k) + 2)):
            v = (py + 0.5) / k
            row = py * self.size
            for px in range(max(0, int(x0 * k) - 1), min(self.size, int(x1 * k) + 2)):
                u = (px + 0.5) / k
                cover = min(1.0, max(0.0, 0.5 - _distance(shape, u, v) * k)) * alpha
                if cover <= 0:
                    continue
                i = row + px
                da = self.a[i]
                out_a = cover + da * (1 - cover)
                self.r[i] = (cr * cover + self.r[i] * da * (1 - cover)) / out_a
                self.g[i] = (cg * cover + self.g[i] * da * (1 - cover)) / out_a
                self.b[i] = (cb * cover + self.b[i] * da * (1 - cover)) / out_a
                self.a[i] = out_a

    def mask_rounded(self, radius_fraction: float) -> None:
        """Cut the corners to a rounded square, for Android's legacy icon."""
        n = self.size
        rad = radius_fraction * n
        for py in range(n):
            for px in range(n):
                qx = max(abs(px + 0.5 - n / 2) - (n / 2 - rad), 0.0)
                qy = max(abs(py + 0.5 - n / 2) - (n / 2 - rad), 0.0)
                d = math.hypot(qx, qy) - rad
                cover = min(1.0, max(0.0, 0.5 - d))
                self.a[py * n + px] *= cover

    def png(self, alpha: bool) -> bytes:
        n = self.size
        raw = bytearray()
        for y in range(n):
            raw.append(0)
            for i in range(y * n, (y + 1) * n):
                raw += bytes(round(c * 255) for c in (self.r[i], self.g[i], self.b[i]))
                if alpha:
                    raw.append(round(self.a[i] * 255))

        def chunk(tag: bytes, data: bytes) -> bytes:
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

        header = struct.pack(">IIBBBBB", n, n, 8, 6 if alpha else 2, 0, 0, 0)
        return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def _bounds(shape: Shape) -> tuple[float, float, float, float]:
    if isinstance(shape, Circle):
        return shape.cx - shape.r, shape.cy - shape.r, shape.cx + shape.r, shape.cy + shape.r
    if isinstance(shape, Ellipse):
        return shape.cx - shape.rx, shape.cy - shape.ry, shape.cx + shape.rx, shape.cy + shape.ry
    xs, ys = [x for x, _ in shape.points], [y for _, y in shape.points]
    return min(xs), min(ys), max(xs), max(ys)


def _distance(shape: Shape, u: float, v: float) -> float:
    """Signed distance in design units: negative inside, positive outside."""
    if isinstance(shape, Circle):
        return math.hypot(u - shape.cx, v - shape.cy) - shape.r
    if isinstance(shape, Ellipse):
        dx, dy = u - shape.cx, v - shape.cy
        f = (dx / shape.rx) ** 2 + (dy / shape.ry) ** 2 - 1
        grad = 2 * math.hypot(dx / shape.rx**2, dy / shape.ry**2)
        return f / grad if grad else -min(shape.rx, shape.ry)
    d = -math.inf
    pts = shape.points
    for (ax, ay), (bx, by) in zip(pts, pts[1:] + pts[:1]):
        ex, ey = bx - ax, by - ay
        length = math.hypot(ex, ey)
        # Outward normal of a clockwise edge, with y pointing down.
        d = max(d, ((u - ax) * ey - (v - ay) * ex) / length)
    return d


# --- outputs -----------------------------------------------------------------


def svg(shapes: list[Shape]) -> str:
    parts = [f'<rect width="{UNITS}" height="{UNITS}" fill="{CREAM}"/>']
    for sh in shapes:
        if isinstance(sh, Circle):
            parts.append(f'<circle cx="{sh.cx:.2f}" cy="{sh.cy:.2f}" r="{sh.r:g}" fill="{sh.colour}"/>')
        elif isinstance(sh, Ellipse):
            parts.append(f'<ellipse cx="{sh.cx:g}" cy="{sh.cy:g}" rx="{sh.rx:g}" ry="{sh.ry:g}" fill="{sh.colour}"/>')
        else:
            pts = " ".join(f"{x:g},{y:g}" for x, y in sh.points)
            parts.append(f'<polygon points="{pts}" fill="{sh.colour}"/>')
    body = "\n  ".join(parts)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {UNITS} {UNITS}" width="{UNITS}" height="{UNITS}">\n'
        f"  <!-- Generated by tool/render_app_icons.py. Edit the script, not this file. -->\n"
        f"  {body}\n</svg>\n"
    )


def render(shapes: list[Shape], size: int, background: str | None, mono: bool = False) -> Canvas:
    canvas = Canvas(size, background)
    for sh in shapes:
        if mono:
            canvas.draw(sh, "#FFFFFF", MONO_UNCOUNTED_ALPHA if sh.colour == UNCOUNTED else 1.0)
        else:
            canvas.draw(sh)
    return canvas


def write(path: Path, data: bytes | str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        path.write_text(data)
    else:
        path.write_bytes(data)
    print(f"  {path.relative_to(ROOT)}")


ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def main() -> None:
    shapes = design()
    top, bottom = vertical_bounds(shapes)
    assert abs((top + bottom) / 2 - UNITS / 2) < 2, "the design has drifted off vertical centre"

    write(ROOT / "assets/icon/wirdi_icon.svg", svg(shapes))

    # iOS: full-bleed and opaque. The system rounds the corners, and App Store
    # Connect rejects a marketing icon with an alpha channel.
    iconset = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    cache: dict[int, bytes] = {}
    for image in json.loads((iconset / "Contents.json").read_text())["images"]:
        px = round(float(image["size"].split("x")[0]) * int(image["scale"].rstrip("x")))
        if px not in cache:
            cache[px] = render(shapes, px, CREAM).png(alpha=False)
        write(iconset / image["filename"], cache[px])

    # Android.
    res = ROOT / "android/app/src/main/res"
    adaptive = scaled(shapes, ADAPTIVE_SCALE)
    for name, density in ANDROID_DENSITIES.items():
        # Legacy (before API 26): a 48dp rounded square, drawn by us.
        legacy = render(shapes, round(48 * density), CREAM)
        legacy.mask_rounded(0.2)
        write(res / f"mipmap-{name}/ic_launcher.png", legacy.png(alpha=True))
        # Adaptive (API 26+): 108dp layers the launcher masks itself.
        layer = round(108 * density)
        write(res / f"mipmap-{name}/ic_launcher_foreground.png", render(adaptive, layer, None).png(alpha=True))
        write(res / f"mipmap-{name}/ic_launcher_monochrome.png", render(adaptive, layer, None, mono=True).png(alpha=True))

    # Google Play's listing icon: 512px, full-bleed and square, like iOS's,
    # but as the 32-bit PNG Play asks for — opaque all the same.
    # Play draws the rounded corners and the shadow itself, and asks for neither
    # in the upload. Not bundled with the app — it is uploaded to Play Console
    # by hand, from here.
    write(ROOT / "assets/icon/play_store_icon.png", render(shapes, 512, CREAM).png(alpha=True))


if __name__ == "__main__":
    main()
