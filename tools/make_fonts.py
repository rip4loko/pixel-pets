#!/usr/bin/env python3
"""Fabrique les polices « film » du défilé.

Une Live Activity ne peut pas animer librement. Seul un minuteur système
(Text(timerInterval:)) se met à jour tout seul, chaque seconde, même écran
verrouillé. Astuce : une police où chaque texte « mm:ss » est remplacé
(ligature) par une image du défilé. Le minuteur devient un film d'1 heure
à 1 image/seconde.

L'île ne dessine pas les polices en images couleur (sbix) : chaque image est
donc faite de carrés vectoriels, une police par couleur. Le widget empile
les couches, chacune teintée de sa couleur.

Trois scènes :
  ParadeLeft / ParadeRight : les deux côtés de la caméra (île compacte).
  ParadeWide               : bande large (écran verrouillé + île ouverte).
Fichiers : Widget/Fonts/<Scène><n°couche>.ttf, plus Shared/ParadeLayers.swift
(les couleurs) et la liste UIAppFonts de project.yml.

Usage : python3 tools/make_fonts.py   (il faut `pip install fonttools pillow`)
"""
import os
import random
import re

from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Widget", "Fonts")

LOOP = 3600          # secondes : le film dure 1 h puis recommence
H = 18               # hauteur de la scène en pixels « art » (16 + place pour sauter)
UNIT = 40            # unités de police par pixel art
UPEM = H * UNIT      # police de 24 pt → 1 pixel art = 1,33 pt
STEP = 4             # pixels art parcourus par seconde
LAYERS = 11          # teintes regroupées (la plus sombre, le contour, est retirée)

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


def rgb(c):
    return ((c >> 16) & 255, (c >> 8) & 255, c & 255)


def luminance(c):
    r, g, b = rgb(c)
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255


def group_colors():
    """Regroupe les couleurs de tous les pets en LAYERS teintes (k-moyennes)."""
    weight = {}
    for _, palette, frames in PETS:
        for rows in frames:
            for row in rows:
                for ch in row:
                    if ch in palette:
                        weight[palette[ch]] = weight.get(palette[ch], 0) + 1
    colors = sorted(weight)
    pts = {c: rgb(c) for c in colors}

    def dist(a, b):
        return sum((x - y) ** 2 for x, y in zip(a, b))

    # départ : les couleurs les plus éloignées les unes des autres
    centers = [pts[max(colors, key=lambda c: weight[c])]]
    while len(centers) < LAYERS:
        centers.append(max((pts[c] for c in colors), key=lambda p: min(dist(p, q) for q in centers)))
    for _ in range(50):
        groups = [[] for _ in centers]
        for c in colors:
            groups[min(range(len(centers)), key=lambda i: dist(pts[c], centers[i]))].append(c)
        centers = [tuple(sum(pts[c][k] * weight[c] for c in g) / sum(weight[c] for c in g) for k in range(3))
                   if g else centers[i] for i, g in enumerate(groups)]
    hexes = [(int(r) << 16) | (int(g) << 8) | int(b) for r, g, b in centers]
    layer_of = {c: min(range(len(centers)), key=lambda i: dist(pts[c], centers[i])) for c in colors}
    darkest = min(range(len(hexes)), key=lambda i: luminance(hexes[i]))
    keep = [i for i in range(len(hexes)) if i != darkest and any(layer_of[c] == i for c in colors)]
    remap = {old: new for new, old in enumerate(keep)}
    return [hexes[i] for i in keep], {c: remap.get(layer_of[c]) for c in colors}


LAYER_COLORS, LAYER_OF = group_colors()


def sprite_pixels(pet, frame):
    _, palette, frames = PETS[pet]
    rows = frames[min(frame, len(frames) - 1)]
    out = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette and LAYER_OF[palette[ch]] is not None:
                out.append((x, y, LAYER_OF[palette[ch]]))
    return out


SPRITES = {(p, f): sprite_pixels(p, f) for p in range(len(PETS)) for f in range(3)}


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
    """Une image = grille de n° de couche (None = transparent)."""
    grid = [[None] * width for _ in range(H)]
    for start, pet, steps in walkers:
        age = (t - start) % LOOP
        if age < len(steps):
            x0, dy, f = steps[age]
            for x, y, layer in SPRITES[(pet, f)]:
                X, Y = x0 + x, 2 + dy + y
                if 0 <= X < width and 0 <= Y < H:
                    grid[Y][X] = layer
    return grid


def crop(grid, x0, x1):
    return [row[x0:x1] for row in grid]


# ----------------------------------------------------------------- la police

def layer_glyph(grid, layer):
    """Les pixels d'une couche, en rectangles (un par suite horizontale)."""
    pen = TTGlyphPen(None)
    for y, row in enumerate(grid):
        top = (H - y) * UNIT
        x = 0
        while x < len(row):
            if row[x] == layer:
                start = x
                while x < len(row) and row[x] == layer:
                    x += 1
                a, b = start * UNIT, x * UNIT
                pen.moveTo((a, top - UNIT))
                pen.lineTo((a, top))
                pen.lineTo((b, top))
                pen.lineTo((b, top - UNIT))
                pen.closePath()
            else:
                x += 1
    return pen.glyph()


LIGATURES = "\n".join(
    f"    sub {DIGITS[t // 600]} {DIGITS[t // 60 % 10]} colon {DIGITS[t % 60 // 10]} {DIGITS[t % 10]} by frame{t:04d};"
    for t in range(LOOP))
FEATURES = (f"lookup film {{\n{LIGATURES}\n}} film;\n"
            + "".join(f"feature {tag} {{ lookup film; }} {tag};\n" for tag in ("rlig", "liga", "calt")))


def build_font(name, frames, width, layer):
    names = [".notdef", "space", "colon"] + DIGITS + [f"frame{i:04d}" for i in range(LOOP)]
    # Chaque caractère du minuteur fait 1/5 de l'image, et l'image remplace
    # exactement « mm:ss » (5 caractères) : même largeur avant et après.
    advance = width * UNIT
    char = advance // 5
    assert char * 5 == advance
    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(names)
    cmap = {0x20: "space", 0x3A: "colon"}
    cmap.update({0x30 + i: d for i, d in enumerate(DIGITS)})
    fb.setupCharacterMap(cmap)
    empty = TTGlyphPen(None).glyph()
    fb.setupGlyf({n: layer_glyph(frames[int(n[5:])], layer) if n.startswith("frame") else empty
                  for n in names})
    fb.setupHorizontalMetrics({n: (advance if n.startswith("frame") else char, 0) for n in names})
    fb.setupHorizontalHeader(ascent=UPEM, descent=0)
    fb.setupNameTable({"familyName": name, "styleName": "Regular", "psName": name,
                       "fullName": name, "uniqueFontIdentifier": name})
    fb.setupOS2(sTypoAscender=UPEM, sTypoDescender=0, sTypoLineGap=0,
                usWinAscent=UPEM, usWinDescent=0)
    fb.setupPost()
    addOpenTypeFeaturesFromString(fb.font, FEATURES)
    fb.save(os.path.join(OUT, f"{name}.ttf"))
    return f"{name}.ttf"


def preview(frames, width, path):
    """Planche de contrôle : quelques images du film, en couleurs regroupées."""
    picks = list(range(0, LOOP, 97))[:12]
    img = Image.new("RGB", (width * 3, len(picks) * (H + 2) * 3), (0, 0, 0))
    px = img.load()
    for i, t in enumerate(picks):
        for y, row in enumerate(frames[t]):
            for x, layer in enumerate(row):
                if layer is not None:
                    for dx in range(3):
                        for dy in range(3):
                            px[x * 3 + dx, (i * (H + 2) + y) * 3 + dy] = rgb(LAYER_COLORS[layer])
    img.save(path)


def write_swift():
    colors = ", ".join(f"0x{c:06x}" for c in LAYER_COLORS)
    with open(os.path.join(ROOT, "Shared", "ParadeLayers.swift"), "w", encoding="utf-8") as f:
        f.write("// Généré par tools/make_fonts.py : ne pas modifier à la main.\n\n"
                "extension Parade {\n"
                "    /// Une couleur par couche de police (ParadeLeft0, ParadeLeft1…).\n"
                f"    static let layerColors: [UInt32] = [{colors}]\n"
                "}\n")


def write_project(files):
    path = os.path.join(ROOT, "project.yml")
    src = open(path, encoding="utf-8").read()
    listing = "".join(f"          - {f}\n" for f in files)
    src = re.sub(r"(        UIAppFonts:\n)(?:          - .*\n)*", lambda m: m.group(1) + listing, src)
    open(path, "w", encoding="utf-8").write(src)


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith(".ttf"):
            os.remove(os.path.join(OUT, old))
    rng = random.Random(2709)
    files = []

    width, walkers = compact_schedule(rng)
    frames = [render(width, walkers, t) for t in range(LOOP)]
    preview(frames, width, os.path.join(ROOT, "tools", "apercu-ile.png"))
    left = [crop(g, 0, SIDE) for g in frames]
    right = [crop(g, SIDE + GAP, width) for g in frames]

    width, walkers = wide_schedule(rng)
    wide = [render(width, walkers, t) for t in range(LOOP)]
    preview(wide, width, os.path.join(ROOT, "tools", "apercu-large.png"))

    for layer in range(len(LAYER_COLORS)):
        files.append(build_font(f"ParadeLeft{layer}", left, SIDE, layer))
        files.append(build_font(f"ParadeRight{layer}", right, SIDE, layer))
        files.append(build_font(f"ParadeWide{layer}", wide, WIDE, layer))
    write_swift()
    write_project(sorted(files))
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in files)
    print(f"{len(LAYER_COLORS)} couches, {len(files)} polices, {total // 1024} Ko")


if __name__ == "__main__":
    main()
