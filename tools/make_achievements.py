#!/usr/bin/env python3
"""Genererer de ti achievement-billeder til App Store Connect.

512x512 PNG, RGB uden alfa, som Apple kraever. Alt er tegnet i kode, som
app-ikonet og lydbanken: en billedfil, ingen kan rette, er en fil, ingen
retter.

Sproget er spillets eget. Violet grund med stjerner, Volt som lyset, og
et maerke pr. achievement, der kan laeses ved 60 px, fordi det er dér,
Game Center viser dem.

    python3 tools/make_achievements.py
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 512
OUT = Path("docs/achievements")

VOID = (7, 7, 12)
DEEP = (26, 16, 48)
PULSE = (181, 123, 255)
VOLT = (214, 255, 61)
BONE = (242, 239, 230)
ICE = (77, 216, 255)
FLARE = (255, 159, 28)
EMBER = (255, 77, 46)
SLATE = (136, 135, 128)


def add_light(img, cx, cy, r, colour, strength=0.55, steps=14):
    """Lys lagt ovenpaa, ikke blandet mod sort.

    En glorie tegnet som cirkler, der blander mod VOID, bliver en moerk
    ring paa en violet grund. Den skal komponeres med alfa i stedet."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    for i in range(steps, 0, -1):
        t = i / steps
        rr = int(r * t)
        a = int(255 * strength * (1.0 - t) ** 2)
        ld.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=colour + (a,))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def background(seed):
    """Rummet, som spillet tegner det: en violet vask og et stjernefelt."""
    rng = random.Random(seed)
    img = Image.new("RGB", (SIZE, SIZE), VOID)
    d = ImageDraw.Draw(img)
    # Vasken, som en vifte af cirkler fra midten og ud.
    for i in range(28, 0, -1):
        t = i / 28.0
        r = int(SIZE * 0.78 * t)
        c = tuple(int(VOID[k] + (DEEP[k] - VOID[k]) * (1.0 - t) ** 1.6) for k in range(3))
        d.ellipse([SIZE // 2 - r, SIZE // 2 - r, SIZE // 2 + r, SIZE // 2 + r], fill=c)
    for _ in range(90):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        s = rng.choice([1, 1, 2, 2, 3])
        v = rng.randint(90, 210)
        d.rectangle([x, y, x + s, y + s], fill=(v, v, min(255, v + 20)))
    return img, d


def brick(d, x, y, w, h, colour, gloss=True):
    """En klods med v2's affasning, saa maerket er lavet af spillets egne dele."""
    b = max(2, h // 7)
    dark = tuple(int(c * 0.55) for c in colour)
    light = tuple(min(255, int(c * 1.4)) for c in colour)
    base = tuple(int(c * 0.86) for c in colour)
    d.rectangle([x, y, x + w, y + h], fill=base)
    d.polygon([(x, y), (x + w, y), (x + w - b, y + b), (x + b, y + b)], fill=light)
    d.polygon([(x, y), (x + b, y + b), (x + b, y + h - b), (x, y + h)], fill=light)
    d.polygon([(x + w, y), (x + w, y + h), (x + w - b, y + h - b), (x + w - b, y + b)], fill=dark)
    d.polygon([(x, y + h), (x + b, y + h - b), (x + w - b, y + h - b), (x + w, y + h)], fill=dark)
    if gloss:
        d.rectangle([x + b + 2, y + b + 1, x + b + 2 + int(w * 0.5), y + b + 3], fill=BONE)


def diamond(d, cx, cy, r, colour):
    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=colour)


def glow(d, cx, cy, r, colour, steps=7):
    """Bevidst tom: lys lægges med add_light, efter maerket er tegnet.

    Den ligger her, fordi maerkerne kalder den, og fordi et kald, der
    ikke goer noget, er lettere at laese end tolv steder uden lys."""
    return


def comet(d, cx, cy, r, colour=VOLT):
    """Kometen: hvid kerne, Volt-kant, hale bagud."""
    for i in range(9, 0, -1):
        t = i / 9.0
        rr = r * t
        d.ellipse([cx - rr - i * 12, cy - rr + i * 9, cx + rr - i * 12, cy + rr + i * 9],
                  fill=tuple(int(colour[k] * (0.35 + 0.65 * t)) for k in range(3)))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)
    d.ellipse([cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55], fill=BONE)


def burst(d, cx, cy, r, colour=FLARE):
    d.rectangle([cx - r, cy - r // 8, cx + r, cy + r // 8], fill=colour)
    d.rectangle([cx - r // 8, cy - r, cx + r // 8, cy + r], fill=colour)
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        for k in range(3):
            o = int(r * (0.35 + k * 0.2))
            s = max(4, r // 12)
            d.rectangle([cx + sx * o - s, cy + sy * o - s, cx + sx * o + s, cy + sy * o + s], fill=colour)
    d.ellipse([cx - r // 4, cy - r // 4, cx + r // 4, cy + r // 4], fill=(255, 231, 194))


# Konstellationen, med spillets egne koordinater fra star_map.gd, skaleret
# ind i rammen. Det er den samme figur, spilleren selv har tegnet faerdig.
NODES = [(62, 640), (112, 612), (92, 552), (154, 570), (206, 534), (168, 478),
         (232, 462), (286, 428), (312, 372), (216, 330), (300, 250), (276, 320)]
EDGES = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8),
         (8, 9), (9, 10), (10, 8), (8, 11), (9, 11), (10, 11)]


def constellation(d, lights=None, pad=86):
    xs = [p[0] for p in NODES]
    ys = [p[1] for p in NODES]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    scale = min((SIZE - pad * 2) / (x1 - x0), (SIZE - pad * 2) / (y1 - y0))
    ox = (SIZE - (x1 - x0) * scale) / 2 - x0 * scale
    oy = (SIZE - (y1 - y0) * scale) / 2 - y0 * scale
    pts = [(p[0] * scale + ox, p[1] * scale + oy) for p in NODES]
    for a, b in EDGES:
        d.line([pts[a], pts[b]], fill=PULSE, width=4)
    for p in pts:
        if lights is not None:
            lights.append((int(p[0]), int(p[1]), 40, VOLT, 0.5))
        diamond(d, int(p[0]), int(p[1]), 11, VOLT)
    return pts


def make(name, draw_mark, seed):
    img, d = background(seed)
    lights = []
    draw_mark(d, lights)
    for cx, cy, r, colour, strength in lights:
        img = add_light(img, cx, cy, r, colour, strength)
        d = ImageDraw.Draw(img)
        # Maerket tegnes igen ovenpaa lyset, saa lyset ligger bag det.
    if lights:
        img2, d2 = background(seed)
        for cx, cy, r, colour, strength in lights:
            img2 = add_light(img2, cx, cy, r, colour, strength)
        d2 = ImageDraw.Draw(img2)
        draw_mark(d2, [])
        img = img2
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / ("%s.png" % name)
    img.convert("RGB").save(path)
    print("  %-26s %s" % (name, path))


def first_breach(d, lights=None):
    for i in range(4):
        brick(d, 96 + i * 82, 300, 74, 46, [VOLT, ICE, PULSE, FLARE][i])
    for i in range(2):
        brick(d, 137 + i * 82, 360, 74, 46, [ICE, VOLT][i])
    comet(d, 300, 190, 34)


def chain_of_five(d, lights=None):
    for i in range(5):
        x = 46 + i * 86
        y = 210 + int(math.sin(i * 0.9) * 26)
        brick(d, x, y, 78, 50, FLARE if i % 2 else EMBER)
        if i:
            d.line([(x - 12, y + 25), (x + 6, y + 25)], fill=VOLT, width=7)
    burst(d, 256, 360, 66)


def clean_sweep(d, lights=None):
    for i in range(6):
        brick(d, 40 + i * 74, 120, 66, 42, [VOLT, ICE, PULSE, FLARE, ICE, VOLT][i])
    # Boldens bane, ubrudt, ned til skjoldet og op igen.
    pts = [(120, 200), (200, 300), (256, 360), (330, 300), (410, 200)]
    for i in range(len(pts) - 1):
        d.line([pts[i], pts[i + 1]], fill=BONE, width=5)
    d.rectangle([176, 386, 336, 408], fill=BONE)
    d.rectangle([240, 386, 272, 408], fill=VOLT)
    comet(d, 256, 352, 20)


def ahead_of_schedule(d, lights=None):
    if lights is not None:
        lights.append((256, 256, 230, PULSE, 0.35))
    d.ellipse([106, 106, 406, 406], outline=BONE, width=12)
    for h in range(12):
        a = h * math.pi / 6
        r0, r1 = 118, 138
        d.line([(256 + math.sin(a) * r0, 256 - math.cos(a) * r0),
                (256 + math.sin(a) * r1, 256 - math.cos(a) * r1)], fill=SLATE, width=5)
    d.line([(256, 256), (256, 150)], fill=VOLT, width=12)
    d.line([(256, 256), (330, 300)], fill=VOLT, width=10)
    diamond(d, 256, 256, 14, BONE)


def three_of_three(d, lights=None):
    for i in range(3):
        x = 128 + i * 128
        if lights is not None:
            lights.append((x, 256, 110, VOLT, 0.55))
        diamond(d, x, 256, 44, VOLT)
        diamond(d, x, 256, 18, BONE)


def patience(d, lights=None):
    grey = (136, 135, 128)
    for i in range(9):
        brick(d, 70 + i * 42, 150, 38, 40, grey, gloss=False)
    for i in range(7):
        brick(d, 112 + i * 42, 196, 38, 40, grey, gloss=False)
    for i in range(2):
        brick(d, 196 + i * 42, 242, 38, 40, grey, gloss=False)
    for i in range(2):
        brick(d, 196 + i * 42, 288, 38, 40, grey, gloss=False)
    for i in range(5):
        brick(d, 154 + i * 42, 334, 38, 40, FLARE)
    burst(d, 256, 262, 30)


def one_hit(d, lights=None):
    for r in range(4):
        for c in range(9):
            x, y = 34 + c * 50, 120 + r * 54
            dist = math.hypot(c - 4, r - 1.5)
            if dist < 1.6:
                continue
            shade = [ICE, PULSE, VOLT, FLARE][int(dist) % 4]
            brick(d, x, y, 44, 44, shade)
    if lights is not None:
        lights.append((256, 200, 210, FLARE, 0.6))
    burst(d, 256, 200, 96, FLARE)


def the_drift_cleared(d, lights=None):
    comet(d, 300, 200, 40)
    for i in range(11):
        a = -0.35 + i * 0.32
        x = 256 + math.cos(a) * 190
        y = 330 + math.sin(a) * 60
        diamond(d, int(x), int(y), 13, VOLT if i < 11 else SLATE)
    d.rectangle([176, 420, 336, 442], fill=BONE)
    d.rectangle([240, 420, 272, 442], fill=VOLT)


def constellation_charted(d, lights=None):
    constellation(d, lights)


def full_chart(d, lights=None):
    pts = constellation(d, lights, pad=104)
    # Seks og tredive: tre stjerner over hver af de tolv.
    for p in pts:
        for k in range(3):
            diamond(d, int(p[0] - 16 + k * 16), int(p[1] - 34), 6, BONE)


MARKS = [
    ("first_breach", first_breach),
    ("chain_of_five", chain_of_five),
    ("clean_sweep", clean_sweep),
    ("ahead_of_schedule", ahead_of_schedule),
    ("three_of_three", three_of_three),
    ("patience", patience),
    ("one_hit", one_hit),
    ("the_drift_cleared", the_drift_cleared),
    ("constellation_charted", constellation_charted),
    ("full_chart", full_chart),
]

if __name__ == "__main__":
    print("Achievement-billeder, 512x512 RGB:")
    for i, (name, fn) in enumerate(MARKS):
        make(name, fn, seed=1000 + i)
    print("Faerdig.")
