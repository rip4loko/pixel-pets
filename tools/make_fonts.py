#!/usr/bin/env python3
"""Fabrique les polices « film » du défilé.

Une Live Activity ne peut pas animer librement. Seul un minuteur système
(Text(timerInterval:)) se met à jour tout seul, chaque seconde, même écran
verrouillé. Astuce : une police où chaque texte « mm:ss » est remplacé
(ligature) par une image du défilé. Le minuteur devient un film d'1 heure
à 1 image/seconde.

Trois polices :
  ParadeLeft / ParadeRight : les deux côtés de la caméra (île compacte).
  ParadeWide               : bande large (écran verrouillé + île ouverte).

Usage : python3 tools/make_fonts.py   (régénère Widget/Fonts/*.ttf)
"""
import io
import os
import random
import re

from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables.sbixGlyph import Glyph as SbixGlyph
from fontTools.ttLib.tables.sbixStrike import Strike
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Widget", "Fonts")

LOOP = 3600          # secondes : le film dure 1 h puis recommence
H = 18               # hauteur de la scène en pixels « art » (16 + place pour sauter)
SCALE = 4            # pixels écran par pixel art (écran 3x : 1 px art = 1,33 pt)
PPEM = H * SCALE     # 72 px écran = police de 24 pt
UPEM = PPEM * 10
STEP = 4             # pixels art parcourus par seconde

SIDE = 28            # largeur de chaque côté de la caméra
GAP = 6              # « derrière la caméra »
WIDE = 270           # bande large

DIGITS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]


# ---------------------------------------------------------------- les pets

def load_pets():
    src = open(os.path.join(ROOT, "Shared", "PetData.swift"), encoding="utf-8").read()
    pets = []
    for m in re.finditer(r'Pet\(name: "([^"]+)".*?palette: \[(.*?)\],\s*frames: \[(.*?)\]\]\)', src, re.S):
        palette = {k: int(v, 16) for k, v in re.findall(r'"(.)": 0x([0-9a-fA-F]{6})', m.group(2))}
        frames = [re.findall(r'"([^"]{16})"', f) for f in re.findall(r'\[([^\[\]]+)\]', m.group(3) + "]")]
        frames = [f for f in frames if len(f) == 16]
        pets.append((m.group(1), palette, frames))
    assert len(pets) >= 10, f"seulement {len(pets)} pets lus"
    return pets


PETS = load_pets()


def sprite_pixels(pet, frame):
    _, palette, frames = PETS[pet]
    rows = frames[min(frame, len(frames) - 1)]
    out = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette:
                c = palette[ch]
                out.append((x, y, (c >> 16) & 255, (c >> 8) & 255, c & 255))
    return out


SPRITES = {(p, f): sprite_pixels(p, f) for p in range(len(PETS)) for f in range(3)}


def draw(img, pet, frame, x0, y0):
    px = img.load()
    w, h = img.size
    for x, y, r, g, b in SPRITES[(pet, frame)]:
        X, Y = x0 + x, y0 + y
        if 0 <= X < w and 0 <= Y < h:
            px[X, Y] = (r, g, b, 255)


class Bag:
    """Tire les pets au hasard, sans répétition avant d'avoir vu tout le monde."""

    def __init__(self, rng):
        self.rng, self.items, self.last = rng, [], None

    def next(self):
        if not self.items:
            self.items = list(range(len(PETS)))
            self.rng.shuffle(self.items)
            if self.items[-1] == self.last:
                self.items.insert(0, self.items.pop())
        self.last = self.items.pop()
        return self.last


# ------------------------------------------------------------ les scénarios

def compact_schedule(rng):
    """Un perso à la fois traverse l'île, parfois dans un sens, parfois dans l'autre."""
    width = SIDE + GAP + SIDE
    bag, walkers, t = Bag(rng), [], 0
    while True:
        gap = rng.randint(1, 4)
        pet, direction = bag.next(), rng.choice([1, -1])
        steps = []  # (x, dy, frame) seconde par seconde
        x = -16 if direction == 1 else width
        pause_at = None
        if rng.random() < 0.6:  # s'arrête pour dire coucou d'un côté
            side = rng.choice([0, 1])
            pause_at = rng.randint(2, SIDE - 18) + side * (SIDE + GAP)
        paused = False
        while -16 <= x <= width:
            walking_frame = len(steps) % 2
            steps.append((x, 0, walking_frame))
            if pause_at is not None and not paused and abs(x - pause_at) < STEP:
                paused = True
                for f, dy in rng.choice([[(2, 0), (0, 0), (0, -2), (0, 0)],
                                         [(0, 0), (2, 0), (0, 0), (2, 0), (0, 0)],
                                         [(0, -2), (0, 0), (0, -2), (0, 0), (2, 0)]]):
                    steps.append((x, dy, f))
            x += STEP * direction
        if t + gap + len(steps) > LOOP:
            break
        walkers.append((t + gap, pet, steps))
        t += gap + len(steps)
    return width, walkers


def wide_schedule(rng):
    """Une parade continue : les persos entrent à gauche et sortent à droite."""
    bag, walkers = Bag(rng), []
    life = (WIDE + 16) // STEP + 1
    t = 0
    while t < LOOP - 7:
        pet = bag.next()
        steps = []
        hops = set(rng.sample(range(life), k=rng.randint(0, 3)))
        blinks = set(rng.sample(range(life), k=rng.randint(1, 3)))
        for i in range(life):
            x = -16 + i * STEP
            f = 2 if i in blinks else i % 2
            steps.append((x, -2 if i in hops else 0, f))
        walkers.append((t, pet, steps))
        t += rng.randint(7, 16)
    return WIDE, walkers


def render(width, walkers, t):
    img = Image.new("RGBA", (width, H), (0, 0, 0, 0))
    for start, pet, steps in walkers:
        age = (t - start) % LOOP
        if age < len(steps):
            x, dy, f = steps[age]
            draw(img, pet, f, x, 2 + dy)
    return img


# ----------------------------------------------------------------- la police

def png(img):
    big = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
    buf = io.BytesIO()
    big.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def build_font(name, frames, width):
    names = [".notdef", "space", "colon"] + DIGITS + [f"frame{i:04d}" for i in range(LOOP)]
    # Chaque caractère du minuteur fait 1/5 de l'image, et l'image remplace
    # exactement « mm:ss » (5 caractères). Ainsi la largeur est la même
    # que l'iPhone mesure le texte brut ou le texte transformé.
    advance = width * SCALE * UPEM // PPEM
    char = advance // 5
    assert char * 5 == advance
    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(names)
    cmap = {0x20: "space", 0x3A: "colon"}
    cmap.update({0x30 + i: d for i, d in enumerate(DIGITS)})
    fb.setupCharacterMap(cmap)
    empty = TTGlyphPen(None).glyph()
    fb.setupGlyf({n: empty for n in names})
    fb.setupHorizontalMetrics({n: (advance if n.startswith("frame") else char, 0) for n in names})
    fb.setupHorizontalHeader(ascent=UPEM, descent=0)
    fb.setupNameTable({"familyName": name, "styleName": "Regular", "psName": name,
                       "fullName": name, "uniqueFontIdentifier": name})
    fb.setupOS2(sTypoAscender=UPEM, sTypoDescender=0, sTypoLineGap=0,
                usWinAscent=UPEM, usWinDescent=0)
    fb.setupPost()

    rules = []
    for t in range(LOOP):
        mm, ss = divmod(t, 60)
        seq = [DIGITS[mm // 10], DIGITS[mm % 10], "colon", DIGITS[ss // 10], DIGITS[ss % 10]]
        rules.append(f"    sub {' '.join(seq)} by frame{t:04d};")
    body = "\n".join(rules)
    fea = "".join(f"feature {tag} {{\n{body}\n}} {tag};\n" for tag in ("rlig", "liga", "calt"))
    addOpenTypeFeaturesFromString(fb.font, fea)

    sbix = newTable("sbix")
    strike = Strike(ppem=PPEM, resolution=72)
    for n in names:
        if n.startswith("frame"):
            strike.glyphs[n] = SbixGlyph(glyphName=n, graphicType="png ",
                                         imageData=frames[int(n[5:])],
                                         originOffsetX=0, originOffsetY=0)
    sbix.strikes = {PPEM: strike}
    fb.font["sbix"] = sbix

    path = os.path.join(OUT, f"{name}.ttf")
    fb.save(path)
    print(f"{name}: {os.path.getsize(path) // 1024} Ko")


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(2709)

    width, walkers = compact_schedule(rng)
    left, right = [], []
    for t in range(LOOP):
        img = render(width, walkers, t)
        left.append(png(img.crop((0, 0, SIDE, H))))
        right.append(png(img.crop((SIDE + GAP, 0, width, H))))
    build_font("ParadeLeft", left, SIDE)
    build_font("ParadeRight", right, SIDE)

    width, walkers = wide_schedule(rng)
    build_font("ParadeWide", [png(render(width, walkers, t)) for t in range(LOOP)], WIDE)


if __name__ == "__main__":
    main()
