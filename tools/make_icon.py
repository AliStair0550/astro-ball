#!/usr/bin/env python3
"""Draws the app icon.

The palette is the game's own: Pulse violet for the field, Volt for the
comet. A comet on a violet field, because that is what the player is.

Everything glowing is composited with alpha rather than blended toward
black. Blending a glow toward the background colour turns it the colour
of mud the moment the two are not the same hue, which is exactly what a
Volt halo on a violet field does.

Drawn at four times the size and shrunk down. iOS masks the corners
itself, so the square is filled edge to edge.

    python3 tools/make_icon.py
"""

import os
import random

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 4
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "icons")

VOID = (7, 7, 12)
FIELD_CORE = (74, 40, 132)
FIELD_EDGE = (18, 10, 34)
PULSE = (181, 123, 255)
VOLT = (214, 255, 61)
BONE = (242, 239, 230)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def glow_layer(n, cx, cy, radius, color, peak, power=2.2, steps=70):
    """A soft disc of light, alpha only. Composited, never blended."""
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(steps, 0, -1):
        t = i / float(steps)
        r = radius * t
        a = int(round(255 * peak * ((1.0 - t) ** power)))
        if a <= 0:
            continue
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    return layer


def main():
    n = SIZE * SS
    im = Image.new("RGB", (n, n), VOID)
    d = ImageDraw.Draw(im)

    # The violet field. Brightest behind the comet, falling to the
    # corners. It has to actually read as purple at 60 px, so the core is
    # a real violet and not a hint of one.
    fx, fy = n * 0.56, n * 0.44
    for i in range(120, 0, -1):
        t = i / 120.0
        r = n * 1.05 * t
        d.ellipse([fx - r, fy - r, fx + r, fy + r], fill=lerp(FIELD_CORE, FIELD_EDGE, t ** 0.5))

    rng = random.Random(31415)
    for _ in range(80):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        s = rng.choice([1, 1, 1, 2, 3]) * SS
        d.rectangle([x, y, x + s, y + s], fill=lerp(FIELD_EDGE, BONE, rng.uniform(0.3, 0.85)))

    im = im.convert("RGBA")

    hx, hy = n * 0.60, n * 0.40
    tx, ty = n * 0.15, n * 0.85

    # The tail, violet at its root turning Volt as it reaches the head.
    tail = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    td = ImageDraw.Draw(tail)
    steps = 300
    for i in range(steps):
        t = i / (steps - 1.0)
        x = tx + (hx - tx) * t
        y = ty + (hy - ty) * t
        w = (n * 0.004) + (n * 0.050) * (t ** 2.4)
        col = lerp(PULSE, VOLT, t ** 1.5)
        a = int(round(255 * min(1.0, 0.10 + t * 1.25)))
        td.ellipse([x - w, y - w, x + w, y + w], fill=col + (a,))
    tail = tail.filter(ImageFilter.GaussianBlur(SS * 2.0))
    im = Image.alpha_composite(im, tail)

    # The head: a wide soft halo, a tighter one, then the solid comet.
    im = Image.alpha_composite(im, glow_layer(n, hx, hy, n * 0.30, VOLT, 0.42, 2.6))
    im = Image.alpha_composite(im, glow_layer(n, hx, hy, n * 0.15, VOLT, 0.85, 1.8))

    head = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    hd = ImageDraw.Draw(head)
    r = n * 0.070
    hd.ellipse([hx - r, hy - r, hx + r, hy + r], fill=VOLT + (255,))
    r = n * 0.036
    hd.ellipse([hx - r, hy - r, hx + r, hy + r], fill=BONE + (255,))
    im = Image.alpha_composite(im, head)

    im = im.convert("RGB").filter(ImageFilter.GaussianBlur(SS * 0.35))
    im = im.resize((SIZE, SIZE), Image.LANCZOS)

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "icon_1024.png")
    im.save(path)
    print("wrote %s (%dx%d)" % (path, im.width, im.height))
    im.resize((180, 180), Image.LANCZOS).save(os.path.join(OUT, "icon_180_preview.png"))


if __name__ == "__main__":
    main()
