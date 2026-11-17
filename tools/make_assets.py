#!/usr/bin/env python3
"""Generate every texture and model Backcountry uses. Deterministic: run it
again and you get the same files.   python3 tools/make_assets.py
Sounds are handled by tools/make_sounds.py."""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "mods/bc/textures"
MODELS = ROOT / "mods/bc/models"
TEX.mkdir(parents=True, exist_ok=True)
MODELS.mkdir(parents=True, exist_ok=True)
S = 16


def clamp(v):
    return max(0, min(255, int(round(v))))


def mul(c, f):
    return (clamp(c[0] * f), clamp(c[1] * f), clamp(c[2] * f)) + tuple(c[3:])


def mix(a, b, t):
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(3))


def save(img, name):
    img.save(TEX / f"bc_{name}.png")


class VNoise:
    """Tileable value noise on a small lattice."""

    def __init__(self, seed, cells=4, size=S):
        r = random.Random(seed)
        self.cells, self.size = cells, size
        self.g = [[r.random() for _ in range(cells)] for _ in range(cells)]

    def at(self, x, y):
        c = self.cells
        fx, fy = x / self.size * c, y / self.size * c
        x0, y0 = int(fx) % c, int(fy) % c
        x1, y1 = (x0 + 1) % c, (y0 + 1) % c
        tx, ty = fx - int(fx), fy - int(fy)
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = self.g[y0][x0] + (self.g[y0][x1] - self.g[y0][x0]) * tx
        b = self.g[y1][x0] + (self.g[y1][x1] - self.g[y1][x0]) * tx
        return a + (b - a) * ty


def tile(name, fn, size=S, seed=None):
    r = random.Random(seed if seed is not None else name)
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            c = fn(x, y, r)
            px[x, y] = c if len(c) == 4 else c + (255,)
    save(img, name)
    return img


def grainy(base, var=0.1, blotch=0.12, seed=1, specks=()):
    """Factory: a noisy flat material. specks = [(color, probability)]."""
    vn = VNoise(seed)

    def fn(x, y, r):
        f = 1 + (vn.at(x, y) - 0.5) * 2 * blotch + (r.random() - 0.5) * 2 * var
        c = mul(base, f)
        for col, p in specks:
            if r.random() < p:
                c = mul(col, 1 + (r.random() - 0.5) * 0.2)
        return c

    return fn


# ----------------------------------------------------------------------------
# Terrain
# ----------------------------------------------------------------------------
def terrain():
    def stone(x, y, r, vn=VNoise(3), vn2=VNoise(8, 8)):
        f = 0.9 + vn.at(x, y) * 0.22 + (r.random() - 0.5) * 0.08
        c = mul((128, 126, 122), f)
        if abs(vn2.at(x, y) - 0.5) < 0.035:
            c = mul(c, 0.72)
        return c

    tile("stone", stone)

    pts = [(random.Random(41).random() * S, random.Random(i * 7 + 1).random() * S, 0.75 + random.Random(i).random() * 0.5) for i in range(22)]
    pr = random.Random(5)
    pts = [(pr.random() * S, pr.random() * S, 0.72 + pr.random() * 0.5) for _ in range(22)]

    def gravel(x, y, r):
        best, second, shade = 99, 99, 1
        for px_, py_, sh in pts:
            dx = min(abs(x - px_), S - abs(x - px_))
            dy = min(abs(y - py_), S - abs(y - py_))
            d = dx * dx + dy * dy
            if d < best:
                second, best, shade = best, d, sh
            elif d < second:
                second = d
        c = mul((138, 132, 124), shade + (r.random() - 0.5) * 0.06)
        if math.sqrt(second) - math.sqrt(best) < 0.7:
            c = mul(c, 0.6)
        return c

    tile("gravel", gravel)
    tile("dirt", grainy((112, 84, 58), 0.09, 0.12, 11, [((84, 62, 42), 0.06), ((136, 106, 76), 0.04)]))
    tile("grass_top", grainy((86, 128, 56), 0.1, 0.16, 12, [((112, 152, 70), 0.1), ((64, 104, 44), 0.08)]))
    tile("dry_grass_top", grainy((170, 152, 88), 0.09, 0.14, 13, [((196, 178, 110), 0.1), ((140, 122, 70), 0.08)]))
    tile("needles_top", grainy((104, 82, 56), 0.09, 0.14, 14, [((150, 104, 58), 0.1), ((70, 84, 50), 0.08), ((76, 58, 40), 0.06)]))
    tile("snow", grainy((238, 242, 248), 0.015, 0.035, 15, [((222, 230, 244), 0.06)]))
    tile("sand", grainy((214, 196, 150), 0.045, 0.07, 16, [((190, 172, 128), 0.05), ((232, 216, 172), 0.04)]))

    def clay(x, y, r, vn=VNoise(17)):
        f = 0.94 + vn.at(x, y) * 0.12 + math.sin(y * 1.3 + vn.at(x, y) * 4) * 0.03
        return mul((170, 138, 120), f + (r.random() - 0.5) * 0.03)

    tile("clay", clay)

    def ice(x, y, r, vn=VNoise(18, 5)):
        f = 0.94 + vn.at(x, y) * 0.12
        c = mul((176, 210, 234), f)
        if abs(vn.at(y, x) - 0.5) < 0.02:
            c = (236, 246, 252)
        return c + (215,)

    tile("ice", ice)

    def side(name, col, depth, seed):
        r = random.Random(seed)
        edge = [depth + r.choice((-1, 0, 0, 1, 1, 2)) for _ in range(S)]

        def fn(x, y, rr):
            if y < edge[x]:
                f = 1 + (rr.random() - 0.5) * 0.18 - (0.18 if y == edge[x] - 1 else 0)
                return mul(col, f) + (255,)
            return (0, 0, 0, 0)

        tile(name, fn)

    side("grass_side", (86, 128, 56), 3, 21)
    side("dry_grass_side", (170, 152, 88), 3, 22)
    side("needles_side", (104, 82, 56), 2, 23)
    side("snow_side", (238, 242, 248), 4, 24)

    def water(name, col, alpha, frames, flow):
        vn = VNoise(name, 4)
        img = Image.new("RGBA", (S, S * frames))
        px = img.load()
        for f in range(frames):
            ph = f / frames
            for y in range(S):
                for x in range(S):
                    if flow:
                        v = vn.at(x, (y - ph * S) % S)
                        w = math.sin((x * 0.9) + v * 5)
                    else:
                        v = vn.at((x + math.sin(ph * 2 * math.pi) * 2) % S, (y + math.cos(ph * 2 * math.pi) * 2) % S)
                        w = math.sin((x + y) * 0.55 + ph * 2 * math.pi + v * 6)
                    c = mul(col, 0.9 + v * 0.2)
                    a = alpha
                    if w > 0.86:
                        c = mix(c, (220, 236, 248), 0.5)
                        a = min(255, alpha + 30)
                    px[x, f * S + y] = c + (a,)
        save(img, name)

    water("water_anim", (38, 86, 138), 176, 8, False)
    water("water_flow_anim", (38, 86, 138), 176, 8, True)
    water("river_anim", (52, 118, 146), 150, 8, False)
    water("river_flow_anim", (52, 118, 146), 150, 8, True)
    for name, col, a in (("water", (38, 86, 138), 176), ("river", (52, 118, 146), 150)):
        tile(name, lambda x, y, r, col=col, a=a, vn=VNoise(name): mul(col, 0.9 + vn.at(x, y) * 0.2) + (a,))


# ----------------------------------------------------------------------------
# Trees
# ----------------------------------------------------------------------------
def trees():
    def bark(name, base, dark, seed):
        r0 = random.Random(seed)
        cols = [0.85 + r0.random() * 0.3 for _ in range(S)]
        vn = VNoise(seed, 8)

        def fn(x, y, r):
            f = cols[x] + (r.random() - 0.5) * 0.08
            c = mul(base, f)
            if vn.at(x * 2.5, y * 0.6) > 0.72:
                c = mul(dark, 0.9 + r.random() * 0.2)
            return c

        tile(name, fn)

    bark("pine_trunk", (98, 70, 48), (62, 44, 32), 31)
    bark("oak_trunk", (108, 88, 62), (72, 58, 42), 32)

    def birch(x, y, r, vn=VNoise(33, 8)):
        c = mul((226, 222, 212), 0.95 + (r.random() - 0.5) * 0.06 + (x % 5 == 0) * -0.04)
        if vn.at(x * 0.7, y * 3.1) > 0.8:
            c = (52, 48, 46)
        return c

    tile("birch_trunk", birch)

    def top(name, wood, barkc, seed):
        def fn(x, y, r):
            d = math.hypot(x - 7.5, y - 7.5)
            if d > 7.2:
                return mul(barkc, 0.9 + r.random() * 0.2)
            ring = 0.92 + 0.1 * math.sin(d * 2.4) + (r.random() - 0.5) * 0.05
            return mul(wood, ring)

        tile(name, fn, seed=seed)

    top("pine_trunk_top", (190, 150, 100), (98, 70, 48), 34)
    top("oak_trunk_top", (176, 142, 96), (108, 88, 62), 35)
    top("birch_trunk_top", (214, 190, 146), (200, 196, 186), 36)

    def leaves(name, base, light, dark, hole, seed, needles=False):
        vn = VNoise(seed, 8)

        def fn(x, y, r):
            v = vn.at(x, y)
            if r.random() < hole and v < 0.5:
                return (0, 0, 0, 0)
            c = base
            if needles:
                if (x + y * 2 + int(v * 6)) % 4 == 0:
                    c = light
                elif (x * 2 + y) % 5 == 0:
                    c = dark
            else:
                c = light if v > 0.62 else dark if v < 0.36 else base
            return mul(c, 0.92 + r.random() * 0.16) + (255,)

        tile(name, fn)

    leaves("pine_leaves", (46, 88, 56), (66, 112, 68), (30, 62, 44), 0.2, 37, True)
    leaves("oak_leaves", (70, 118, 48), (96, 146, 62), (50, 90, 38), 0.22, 38)
    leaves("birch_leaves", (120, 160, 70), (150, 186, 88), (92, 132, 56), 0.26, 39)

    for name, leaf in (("pine", (46, 96, 58)), ("oak", (78, 128, 52)), ("birch", (126, 168, 74))):
        img = Image.new("RGBA", (S, S))
        d = ImageDraw.Draw(img)
        d.line([(8, 15), (8, 6)], fill=(98, 72, 48, 255))
        for (x, y) in ((6, 9), (10, 8), (5, 6), (10, 5), (7, 4), (9, 3), (8, 2)):
            d.point((x, y), fill=leaf + (255,))
            d.point((x + (1 if x < 8 else -1), y + 1), fill=mul(leaf, 0.8) + (255,))
        d.line([(6, 10), (8, 11)], fill=mul(leaf, 0.9) + (255,))
        d.line([(10, 9), (8, 10)], fill=mul(leaf, 0.9) + (255,))
        save(outline(img), f"{name}_sapling")


# ----------------------------------------------------------------------------
# Sprites
# ----------------------------------------------------------------------------
def outline(img, strength=0.45):
    """Dark edge round every opaque shape, so sprites read against anything."""
    px = img.load()
    w, h = img.size
    out = img.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 200:
                        op[x, y] = mul(px[nx, ny][:3], strength) + (255,)
                        break
    return out


def speckle(img, amount=0.1, seed=0):
    r = random.Random(seed)
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            c = px[x, y]
            if c[3] > 0:
                px[x, y] = mul(c[:3], 1 + (r.random() - 0.5) * 2 * amount) + (c[3],)
    return img


def sprite(name, draw, edge=True, noise=0.07, size=S):
    img = Image.new("RGBA", (size, size))
    draw(ImageDraw.Draw(img), img)
    speckle(img, noise, name)
    if edge:
        img = outline(img)
    save(img, name)


WOOD, WOOD_D, WOOD_L = (136, 98, 60), (96, 68, 42), (168, 128, 84)
STONE, STONE_L, STONE_D = (128, 126, 122), (166, 164, 158), (92, 90, 88)
FLINT, FLINT_L = (64, 68, 78), (120, 126, 140)
TAN, TAN_D = (186, 168, 104), (146, 128, 74)
GREEN, GREEN_D, GREEN_L = (92, 138, 58), (62, 100, 44), (124, 168, 76)
BONE, BONE_D = (230, 222, 198), (190, 180, 152)
HIDE, FUR, FUR_D = (170, 126, 84), (126, 94, 66), (92, 68, 48)
MEAT, COOKED = (186, 62, 58), (146, 88, 50)
CLAY = (178, 122, 90)


def A(c, a=255):
    return tuple(c) + (a,)


def blob(col, hi):
    def draw(d, img):
        d.ellipse([3, 5, 12, 13], fill=A(col))
        d.ellipse([5, 6, 9, 9], fill=A(hi))
    return draw


def plants():
    def blades(col, col2, seed, n=7, top=3):
        def draw(d, img):
            r = random.Random(seed)
            for i in range(n):
                x0 = 3 + i * (10 / max(1, n - 1)) + r.uniform(-0.7, 0.7)
                x1 = x0 + r.uniform(-3, 3)
                y1 = top + r.uniform(0, 5)
                d.line([(x0, 15), (x1, y1)], fill=A(col if i % 2 else col2))
        return draw

    sprite("grass_tuft", blades(GREEN, GREEN_L, 1), edge=False)
    sprite("dry_grass_tuft", blades(TAN, (210, 192, 126), 2), edge=False)

    def dead_bush(d, img):
        c = A((112, 86, 60))
        d.line([(8, 15), (8, 9)], fill=c)
        for a, b in (((8, 11), (4, 6)), ((8, 10), (12, 5)), ((6, 8), (3, 9)), ((10, 7), (13, 8)), ((8, 9), (7, 4)), ((5, 7), (5, 3)), ((11, 6), (10, 2))):
            d.line([a, b], fill=c)

    sprite("dead_bush", dead_bush, edge=False)

    def cattail(d, img):
        for x, top in ((5, 3), (8, 1), (11, 4)):
            d.line([(x, 15), (x, top)], fill=A(GREEN_D))
            d.line([(x, top + 1), (x, top + 4)], fill=A((96, 60, 38)))
            d.line([(x + 1, top + 1), (x + 1, top + 4)], fill=A((122, 78, 48)))
        for a, b in (((6, 15), (3, 7)), ((9, 15), (13, 8)), ((7, 15), (7, 9))):
            d.line([a, b], fill=A(GREEN))

    sprite("cattail", cattail, edge=False)

    def nettle(d, img):
        d.line([(8, 15), (8, 2)], fill=A(GREEN_D))
        for y in (4, 7, 10, 13):
            w = 2 + (y - 2) // 4
            d.polygon([(8, y), (8 - w - 1, y - 1), (8 - w, y + 1)], fill=A((58, 112, 52)))
            d.polygon([(8, y), (8 + w + 1, y - 1), (8 + w, y + 1)], fill=A((70, 126, 58)))

    sprite("nettle", nettle, edge=False)

    def yarrow(d, img):
        d.line([(8, 15), (8, 5)], fill=A(GREEN_D))
        d.line([(8, 9), (5, 6)], fill=A(GREEN_D))
        d.line([(8, 8), (11, 6)], fill=A(GREEN_D))
        for x, y in ((4, 4), (5, 3), (6, 4), (7, 3), (8, 3), (9, 4), (10, 3), (11, 4), (12, 4), (6, 5), (10, 5), (8, 4), (5, 5), (11, 5)):
            d.point((x, y), fill=A((244, 244, 232)))
        for x, y in ((7, 4), (9, 3)):
            d.point((x, y), fill=A((226, 206, 110)))
        for y in (11, 13):
            d.line([(8, y), (5, y - 1)], fill=A(GREEN_L))
            d.line([(8, y), (11, y - 1)], fill=A(GREEN_L))

    sprite("yarrow", yarrow, edge=False)

    def onion_plant(d, img):
        for a, b in (((8, 15), (6, 6)), ((8, 15), (10, 5)), ((8, 15), (8, 7)), ((7, 15), (4, 9))):
            d.line([a, b], fill=A((98, 150, 92)))
        d.ellipse([7, 2, 10, 5], fill=A((186, 140, 196)))
        d.line([(8, 6), (8, 9)], fill=A(GREEN_D))

    sprite("onion_plant", onion_plant, edge=False)

    def bush(berry=None):
        def draw(d, img):
            d.line([(8, 15), (8, 11)], fill=A(WOOD_D))
            d.ellipse([1, 3, 14, 13], fill=A((60, 104, 50)))
            r = random.Random(7)
            for _ in range(26):
                x, y = r.randint(2, 13), r.randint(4, 12)
                if img.getpixel((x, y))[3]:
                    d.point((x, y), fill=A(r.choice(((84, 132, 62), (44, 82, 40)))))
            if berry:
                for _ in range(9):
                    x, y = r.randint(3, 12), r.randint(5, 11)
                    d.point((x, y), fill=A(berry))
                    d.point((x + 1, y), fill=A(mul(berry, 0.75)))
        return draw

    sprite("bush", bush(), noise=0.04)
    sprite("bush_blue", bush((70, 90, 190)), noise=0.04)
    sprite("bush_red", bush((206, 54, 70)), noise=0.04)

    def cactus(fruit):
        def draw(d, img):
            pad = (96, 142, 84)
            d.ellipse([4, 8, 11, 15], fill=A(pad))
            d.ellipse([1, 4, 7, 10], fill=A(mul(pad, 0.92)))
            d.ellipse([8, 2, 14, 9], fill=A(mul(pad, 1.06)))
            r = random.Random(9)
            for _ in range(16):
                x, y = r.randint(2, 13), r.randint(3, 14)
                if img.getpixel((x, y))[3]:
                    d.point((x, y), fill=A((222, 226, 190)))
            if fruit:
                for x, y in ((3, 3), (10, 1), (12, 2), (6, 7)):
                    d.ellipse([x, y, x + 2, y + 2], fill=A((198, 54, 120)))
        return draw

    sprite("cactus", cactus(False))
    sprite("cactus_ripe", cactus(True))

    def mushroom(cap, dots=None):
        def draw(d, img):
            d.rectangle([7, 9, 8, 14], fill=A((232, 226, 208)))
            d.pieslice([3, 4, 12, 14], 180, 360, fill=A(cap))
            d.line([(4, 9), (11, 9)], fill=A(mul(cap, 0.7)))
            if dots:
                for x, y in ((5, 7), (8, 5), (10, 7), (7, 8)):
                    d.point((x, y), fill=A(dots))
        return draw

    sprite("mushroom_brown", mushroom((142, 98, 60)))
    sprite("mushroom_red", mushroom((196, 52, 44), (244, 240, 230)))
    sprite("mushroom_yellow", mushroom((226, 180, 66)))
    sprite("mushroom_white", mushroom((238, 234, 222), (210, 204, 188)))


def items():
    def stick(d, img):
        d.line([(3, 13), (12, 3)], fill=A(WOOD), width=2)
        d.line([(8, 8), (11, 9)], fill=A(WOOD_D))
        d.point((12, 3), fill=A(WOOD_L))

    sprite("stick", stick)

    def rock(d, img):
        d.polygon([(3, 10), (4, 6), (8, 4), (12, 6), (13, 10), (10, 13), (5, 13)], fill=A(STONE))
        d.polygon([(5, 7), (8, 5), (11, 7), (8, 8)], fill=A(STONE_L))
        d.line([(5, 12), (10, 12)], fill=A(STONE_D))

    sprite("rock", rock)

    def flint(d, img):
        d.polygon([(3, 12), (6, 4), (11, 3), (13, 8), (9, 13)], fill=A(FLINT))
        d.polygon([(6, 5), (10, 4), (8, 8)], fill=A(FLINT_L))
        d.line([(4, 11), (8, 12)], fill=A((40, 42, 50)))

    sprite("flint", flint)

    def pyrite(d, img):
        g = (196, 166, 76)
        d.rectangle([3, 7, 8, 12], fill=A(g))
        d.rectangle([7, 4, 12, 9], fill=A(mul(g, 1.12)))
        d.rectangle([9, 9, 13, 13], fill=A(mul(g, 0.86)))
        for x, y in ((4, 8), (8, 5), (10, 10)):
            d.point((x, y), fill=A((246, 232, 160)))

    sprite("pyrite", pyrite)

    def bundle(col, col2, band):
        def draw(d, img):
            for i, x in enumerate(range(4, 12)):
                d.line([(x, 14), (x + (i % 3) - 1, 2 + (i * 5) % 3)], fill=A(col if i % 2 else col2))
            d.rectangle([4, 8, 11, 9], fill=A(band))
        return draw

    sprite("grass", bundle(GREEN, GREEN_L, TAN_D))
    sprite("dry_grass", bundle(TAN, (212, 194, 130), WOOD_D))

    def cordage(d, img):
        d.ellipse([3, 4, 12, 13], outline=A(TAN), width=2)
        d.ellipse([5, 6, 10, 11], outline=A(TAN_D))
        d.line([(11, 11), (14, 14)], fill=A(TAN), width=1)
        for x, y in ((4, 6), (8, 4), (11, 7), (7, 12)):
            d.point((x, y), fill=A(TAN_D))

    sprite("cordage", cordage)

    def bark(d, img):
        d.polygon([(3, 5), (12, 3), (13, 11), (4, 13)], fill=A((228, 222, 210)))
        d.line([(3, 5), (4, 13)], fill=A((196, 160, 120)))
        for x, y in ((6, 6), (10, 5), (7, 9), (11, 9), (6, 11)):
            d.line([(x, y), (x + 2, y)], fill=A((60, 54, 50)))

    sprite("bark", bark)

    def lichen(d, img):
        c = (150, 170, 140)
        r = random.Random(3)
        for _ in range(11):
            x = r.randint(4, 11)
            d.line([(x, 3), (x + r.randint(-2, 2), 8 + r.randint(0, 5))], fill=A(mul(c, 0.8 + r.random() * 0.4)))

    sprite("lichen", lichen)

    sprite("clay_lump", blob(CLAY, mul(CLAY, 1.15)))

    def charcoal(d, img):
        d.polygon([(3, 11), (5, 5), (11, 4), (13, 9), (9, 13)], fill=A((40, 38, 38)))
        d.line([(6, 6), (10, 5)], fill=A((92, 90, 90)))
        d.line([(7, 9), (11, 9)], fill=A((70, 68, 68)))

    sprite("charcoal", charcoal)

    def bone(d, img):
        d.line([(5, 11), (11, 5)], fill=A(BONE), width=2)
        for x, y in ((3, 11), (5, 13), (11, 3), (13, 5)):
            d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=A(BONE))
        d.point((8, 9), fill=A(BONE_D))

    sprite("bone", bone)

    def sinew(d, img):
        for i in range(4):
            d.line([(3 + i * 2, 13), (6 + i * 2, 8), (5 + i * 2, 3)], fill=A((226, 196, 186) if i % 2 else (204, 168, 160)))

    sprite("sinew", sinew)

    def hide(col, inner):
        def draw(d, img):
            d.polygon([(2, 3), (5, 4), (8, 2), (11, 4), (14, 3), (12, 7), (14, 12), (11, 11), (8, 14), (5, 11), (2, 12), (4, 7)], fill=A(col))
            d.polygon([(6, 6), (10, 6), (10, 10), (6, 10)], fill=A(inner))
        return draw

    sprite("hide_raw", hide(FUR, (206, 150, 140)))
    sprite("hide_cured", hide(HIDE, mul(HIDE, 1.15)))

    def feather(d, img):
        d.line([(3, 13), (12, 3)], fill=A((240, 240, 236)))
        d.polygon([(6, 10), (12, 3), (13, 6), (9, 11)], fill=A((176, 170, 160)))
        d.polygon([(5, 9), (11, 3), (8, 4), (5, 7)], fill=A((142, 134, 124)))

    sprite("feather", feather)

    def antler(d, img):
        for a, b in (((5, 14), (7, 8)), ((7, 8), (11, 2)), ((7, 9), (3, 5)), ((8, 6), (12, 7)), ((9, 4), (7, 2))):
            d.line([a, b], fill=A(BONE), width=2)

    sprite("antler", antler)

    def hook(d, img):
        d.line([(9, 3), (9, 10)], fill=A(BONE))
        d.arc([5, 7, 9, 13], 0, 180, fill=A(BONE))
        d.point((5, 9), fill=A(BONE))
        d.point((9, 2), fill=A(TAN))

    sprite("hook", hook)

    def worm(d, img):
        d.line([(3, 10), (5, 7), (8, 9), (10, 6), (13, 8)], fill=A((216, 140, 136)), width=2)

    sprite("worm", worm)

    def arrow(d, img):
        d.line([(3, 13), (12, 4)], fill=A(WOOD_L))
        d.polygon([(11, 3), (14, 2), (13, 5)], fill=A(FLINT))
        d.line([(2, 12), (4, 14)], fill=A((230, 230, 224)))
        d.line([(3, 11), (5, 13)], fill=A((230, 230, 224)))

    sprite("arrow", arrow)

    def torch(flame):
        def draw(d, img):
            d.line([(8, 15), (8, 7)], fill=A(WOOD), width=2)
            d.rectangle([6, 5, 10, 8], fill=A((222, 214, 198)))
            d.line([(6, 7), (10, 6)], fill=A((70, 60, 54)))
            if flame:
                d.polygon([(6, 5), (8, 0), (10, 5)], fill=A((240, 130, 40)))
                d.polygon([(7, 5), (8, 2), (9, 5)], fill=A((252, 220, 100)))
        return draw

    sprite("torch_unlit", torch(False))
    sprite("torch", torch(True))

    def sharp_stone(d, img):
        d.polygon([(4, 12), (6, 4), (10, 3), (12, 9), (8, 13)], fill=A(STONE))
        d.polygon([(10, 3), (12, 9), (11, 8)], fill=A(STONE_L))
        d.line([(6, 5), (9, 11)], fill=A(STONE_D))

    sprite("sharp_stone", sharp_stone)

    def knife(d, img):
        d.line([(3, 13), (7, 9)], fill=A(WOOD), width=2)
        d.polygon([(7, 10), (6, 8), (12, 2), (13, 4)], fill=A(FLINT))
        d.line([(8, 7), (12, 3)], fill=A(FLINT_L))
        d.line([(6, 9), (8, 11)], fill=A(TAN))

    sprite("knife_flint", knife)

    def hatchet(d, img):
        d.line([(3, 14), (11, 4)], fill=A(WOOD), width=2)
        d.polygon([(8, 2), (13, 3), (14, 8), (11, 8), (9, 6)], fill=A(STONE))
        d.line([(13, 4), (14, 7)], fill=A(STONE_L))
        d.line([(9, 5), (11, 7)], fill=A(TAN))

    sprite("hatchet", hatchet)

    def digging_stick(d, img):
        d.line([(3, 13), (11, 5)], fill=A(WOOD), width=3)
        d.polygon([(10, 4), (14, 2), (12, 6)], fill=A(WOOD_L))

    sprite("digging_stick", digging_stick)

    def pick(d, img):
        d.line([(3, 14), (10, 5)], fill=A(WOOD), width=2)
        d.arc([4, 1, 15, 12], 190, 320, fill=A(BONE), width=2)
        d.line([(9, 5), (11, 6)], fill=A(TAN))

    sprite("pick_antler", pick)

    def spear(tip):
        def draw(d, img):
            d.line([(2, 14), (11, 5)], fill=A(WOOD), width=1)
            d.line([(3, 14), (12, 5)], fill=A(WOOD_D), width=1)
            if tip:
                d.polygon([(10, 4), (14, 1), (13, 6)], fill=A(FLINT))
                d.line([(10, 5), (12, 7)], fill=A(TAN))
            else:
                d.polygon([(11, 4), (14, 1), (13, 5)], fill=A((70, 54, 40)))
        return draw

    sprite("spear_wood", spear(False))
    sprite("spear_flint", spear(True))

    def bow(d, img):
        d.arc([-4, 1, 12, 15], 300, 60, fill=A(WOOD), width=2)
        d.line([(8, 2), (8, 14)], fill=A((232, 226, 206)))

    sprite("bow", bow)

    def rod(d, img):
        d.line([(2, 14), (12, 2)], fill=A(WOOD), width=1)
        d.line([(12, 2), (12, 11)], fill=A((230, 226, 210)))
        d.arc([10, 10, 13, 13], 0, 180, fill=A(BONE))

    sprite("fishing_rod", rod)

    def drill(d, img):
        d.arc([1, 2, 13, 14], 200, 340, fill=A(WOOD), width=2)
        d.line([(2, 9), (12, 9)], fill=A(TAN))
        d.line([(7, 4), (7, 13)], fill=A(WOOD_L), width=2)
        d.rectangle([3, 13, 12, 14], fill=A(WOOD_D))

    sprite("fire_drill", drill)

    def striker(d, img):
        d.polygon([(2, 11), (4, 5), (8, 4), (8, 11), (5, 13)], fill=A(FLINT))
        d.rectangle([9, 6, 13, 11], fill=A((196, 166, 76)))
        for x, y in ((8, 3), (10, 2), (9, 4)):
            d.point((x, y), fill=A((255, 230, 120)))

    sprite("striker", striker)

    def bandage(patch=None):
        def draw(d, img):
            d.rectangle([3, 6, 12, 11], fill=A((214, 200, 150)))
            for x in range(4, 12, 2):
                d.line([(x, 6), (x, 11)], fill=A((180, 164, 116)))
            if patch:
                d.rectangle([6, 7, 9, 10], fill=A(patch))
        return draw

    sprite("bandage", bandage())
    sprite("lichen_dressing", bandage((150, 170, 140)))

    def poultice(d, img):
        d.ellipse([2, 5, 13, 13], fill=A((70, 120, 56)))
        d.ellipse([5, 7, 10, 11], fill=A((176, 196, 150)))
        d.line([(2, 9), (13, 9)], fill=A((52, 96, 44)))

    sprite("poultice", poultice)


def food():
    def meat(col, fat):
        def draw(d, img):
            d.polygon([(3, 6), (7, 3), (12, 4), (13, 9), (10, 13), (5, 12)], fill=A(col))
            d.line([(5, 7), (10, 6)], fill=A(fat))
            d.line([(6, 10), (11, 9)], fill=A(fat))
            d.ellipse([10, 10, 12, 12], fill=A(BONE))
        return draw

    sprite("meat_raw", meat(MEAT, (236, 190, 180)))
    sprite("meat_cooked", meat(COOKED, (190, 136, 84)))
    sprite("meat_spoiled", meat((116, 124, 72), (160, 166, 110)))

    def dried(col):
        def draw(d, img):
            for i, x in enumerate((3, 7, 11)):
                d.polygon([(x, 3 + i), (x + 2, 3 + i), (x + 3, 12 - i), (x + 1, 13 - i)], fill=A(mul(col, 0.9 + i * 0.1)))
        return draw

    sprite("meat_dried", dried((112, 52, 44)))
    sprite("fish_dried", dried((176, 150, 110)))

    def fish(body, belly):
        def draw(d, img):
            d.ellipse([2, 5, 11, 11], fill=A(body))
            d.pieslice([2, 6, 11, 12], 20, 160, fill=A(belly))
            d.polygon([(10, 8), (14, 4), (14, 12)], fill=A(mul(body, 0.85)))
            d.point((4, 7), fill=A((20, 20, 24)))
        return draw

    sprite("fish_raw", fish((104, 132, 150), (206, 214, 218)))
    sprite("fish_cooked", fish((158, 104, 60), (204, 158, 100)))

    def chunk(col):
        def draw(d, img):
            d.polygon([(3, 7), (7, 4), (12, 6), (12, 11), (7, 13), (3, 11)], fill=A(col))
            d.line([(3, 7), (7, 9), (12, 6)], fill=A(mul(col, 1.08)))
            d.line([(7, 9), (7, 13)], fill=A(mul(col, 0.88)))
        return draw

    sprite("fat", chunk((240, 228, 192)))
    sprite("acorn_mash", chunk((206, 176, 126)))

    def berries(col):
        def draw(d, img):
            d.line([(8, 2), (8, 6)], fill=A(GREEN_D))
            d.polygon([(8, 3), (12, 2), (11, 5)], fill=A(GREEN))
            for x, y in ((4, 7), (8, 6), (6, 10), (10, 9)):
                d.ellipse([x, y, x + 3, y + 3], fill=A(col))
                d.point((x + 1, y + 1), fill=A(mix(col, (255, 255, 255), 0.5)))
        return draw

    sprite("berries_blue", berries((66, 86, 186)))
    sprite("berries_red", berries((204, 52, 70)))

    def cactus_fruit(d, img):
        d.ellipse([4, 3, 11, 13], fill=A((198, 54, 120)))
        for x, y in ((6, 5), (9, 7), (6, 10), (8, 4)):
            d.point((x, y), fill=A((250, 210, 220)))

    sprite("cactus_fruit", cactus_fruit)

    def onion(d, img):
        d.ellipse([4, 7, 11, 14], fill=A((232, 222, 226)))
        d.pieslice([4, 7, 11, 14], 300, 60, fill=A((196, 160, 200)))
        d.line([(7, 7), (6, 2)], fill=A(GREEN))
        d.line([(8, 7), (10, 3)], fill=A(GREEN_L))

    sprite("onion", onion)

    def root(col):
        def draw(d, img):
            d.line([(3, 12), (12, 5)], fill=A(col), width=3)
            for x, y in ((4, 13), (6, 12), (9, 9)):
                d.line([(x, y), (x - 1, y + 2)], fill=A(mul(col, 0.7)))
            d.line([(12, 5), (14, 2)], fill=A(GREEN_D))
        return draw

    sprite("cattail_root", root((216, 196, 160)))
    sprite("cattail_root_roasted", root((150, 104, 62)))

    def acorn(d, img):
        d.ellipse([5, 6, 10, 13], fill=A((170, 120, 66)))
        d.pieslice([4, 3, 11, 10], 180, 360, fill=A((110, 80, 50)))
        d.line([(8, 1), (8, 3)], fill=A(WOOD_D))

    sprite("acorn", acorn)
    sprite("snowball", blob((238, 242, 248), (255, 255, 255)), noise=0.02)

    def skin(drop):
        def draw(d, img):
            d.polygon([(6, 2), (9, 2), (9, 5), (12, 8), (12, 13), (3, 13), (3, 8), (6, 5)], fill=A(HIDE))
            d.line([(6, 4), (9, 4)], fill=A(TAN_D))
            d.line([(4, 12), (11, 12)], fill=A(mul(HIDE, 0.8)))
            if drop:
                d.polygon([(7, 7), (9, 10), (8, 11), (6, 10)], fill=A(drop))
        return draw

    sprite("waterskin", skin(None))
    sprite("waterskin_raw", skin((96, 130, 110)))
    sprite("waterskin_clean", skin((120, 190, 236)))

    def rabbit(d, img):
        c = (150, 126, 100)
        d.ellipse([3, 7, 12, 13], fill=A(c))
        d.ellipse([10, 5, 14, 9], fill=A(mul(c, 1.05)))
        d.line([(11, 5), (9, 2)], fill=A(mul(c, 0.9)), width=1)
        d.line([(12, 5), (11, 1)], fill=A(c), width=1)
        d.ellipse([2, 9, 4, 11], fill=A((236, 232, 226)))
        d.point((13, 7), fill=A((30, 26, 26)))

    sprite("rabbit_dead", rabbit)


def pots_and_clothes():
    def band(col):
        def fn(x, y, r):
            f = 1.0 - 0.1 * (y % 5 == 0) + (r.random() - 0.5) * 0.06 - abs(x - 7.5) * 0.012
            return mul(col, f)
        return fn

    tile("pot_side", band(CLAY))
    tile("pot_unfired", band((150, 138, 128)))

    def top(inner):
        def fn(x, y, r):
            d = math.hypot(x - 7.5, y - 7.5)
            if d < 5:
                return mul(inner, 0.95 + r.random() * 0.1 + (0.12 if (x + y) % 7 == 0 and inner[2] > 150 else 0))
            return mul(CLAY, 1.05 - (d > 7) * 0.2 + (r.random() - 0.5) * 0.06)
        return fn

    tile("pot_top", top((66, 44, 34)))
    tile("pot_water", top((70, 130, 190)))

    def shirt(d, img):
        c = (120, 136, 150)
        d.polygon([(2, 4), (5, 2), (10, 2), (13, 4), (12, 7), (10, 6), (10, 13), (5, 13), (5, 6), (3, 7)], fill=A(c))
        d.line([(6, 2), (7, 4), (9, 2)], fill=A(mul(c, 0.7)))

    sprite("shirt", shirt)

    def trousers(col):
        def draw(d, img):
            d.polygon([(4, 2), (11, 2), (12, 14), (9, 14), (8, 6), (7, 6), (6, 14), (3, 14)], fill=A(col))
            d.line([(4, 3), (11, 3)], fill=A(mul(col, 0.75)))
        return draw

    sprite("trousers", trousers((110, 96, 78)))
    sprite("fur_leggings", trousers(FUR), noise=0.16)

    def shoes(col):
        def draw(d, img):
            for ox in (1, 8):
                d.polygon([(ox + 1, 5), (ox + 4, 5), (ox + 4, 9), (ox + 6, 11), (ox + 6, 13), (ox, 13)], fill=A(col))
                d.line([(ox, 13), (ox + 6, 13)], fill=A(mul(col, 0.6)))
        return draw

    sprite("shoes", shoes((78, 66, 58)))
    sprite("hide_boots", shoes(HIDE), noise=0.12)

    def hat(d, img):
        d.pieslice([2, 3, 13, 17], 180, 360, fill=A(FUR))
        d.rectangle([2, 9, 13, 11], fill=A(mul(FUR, 1.25)))
        d.rectangle([2, 11, 4, 13], fill=A(FUR_D))
        d.rectangle([11, 11, 13, 13], fill=A(FUR_D))

    sprite("fur_hat", hat, noise=0.16)

    def coat(d, img):
        d.polygon([(1, 5), (5, 2), (10, 2), (14, 5), (13, 9), (11, 8), (11, 14), (4, 14), (4, 8), (2, 9)], fill=A(FUR))
        d.line([(7, 2), (7, 14)], fill=A(FUR_D))
        d.line([(5, 2), (7, 4), (10, 2)], fill=A(mul(FUR, 1.3)), width=1)
        d.line([(4, 13), (11, 13)], fill=A(mul(FUR, 1.25)))

    sprite("fur_coat", coat, noise=0.16)

    def mittens(d, img):
        for ox in (1, 8):
            d.rounded_rectangle([ox + 1, 3, ox + 5, 11], 2, fill=A(FUR))
            d.rectangle([ox, 7, ox + 1, 9], fill=A(FUR))
            d.rectangle([ox + 1, 11, ox + 5, 13], fill=A(mul(FUR, 1.3)))

    sprite("fur_mittens", mittens, noise=0.16)

    def cape(d, img):
        d.polygon([(6, 2), (9, 2), (14, 13), (1, 13)], fill=A(TAN))
        r = random.Random(4)
        for _ in range(24):
            x, y = r.randint(2, 13), r.randint(3, 12)
            if img.getpixel((x, y))[3]:
                d.line([(x, y), (x, y + 2)], fill=A(r.choice((TAN_D, GREEN, (210, 194, 130)))))
        d.line([(6, 2), (9, 2)], fill=A(WOOD_D))

    sprite("grass_cape", cape)


def fire_and_build():
    def lay(d):
        for a, b in (((3, 14), (8, 6)), ((13, 14), (8, 6)), ((6, 14), (9, 7)), ((10, 14), (7, 7)), ((2, 14), (14, 14))):
            d.line([a, b], fill=A(WOOD), width=1)
        d.line([(4, 15), (12, 15)], fill=A(WOOD_D))

    def unlit(d, img):
        lay(d)
        d.line([(6, 13), (10, 13)], fill=A(TAN))

    sprite("campfire_unlit", unlit)

    def embers(d, img):
        for a, b in (((3, 14), (8, 9)), ((13, 14), (8, 9)), ((2, 14), (14, 14))):
            d.line([a, b], fill=A((52, 44, 40)))
        d.line([(4, 15), (12, 15)], fill=A((70, 66, 64)))
        for x, y in ((6, 13), (8, 12), (10, 13), (7, 14), (9, 14), (8, 10)):
            d.point((x, y), fill=A((250, 120, 40)))
        for x, y in ((8, 13), (5, 14)):
            d.point((x, y), fill=A((255, 210, 90)))

    sprite("campfire_embers", embers, noise=0.03)

    def flame_frames(name, base_draw, cx, by, h, w, frames=4):
        img = Image.new("RGBA", (S, S * frames))
        for f in range(frames):
            fr = Image.new("RGBA", (S, S))
            d = ImageDraw.Draw(fr)
            base_draw(d)
            r = random.Random(f * 13 + 5)
            sway = r.randint(-1, 1)
            tip = by - h + r.randint(-1, 1)
            d.polygon([(cx - w, by), (cx - w + 1, by - h // 2), (cx + sway, tip), (cx + w - 1, by - h // 2 - r.randint(0, 2)), (cx + w, by)], fill=A((234, 110, 34)))
            d.polygon([(cx - w + 2, by), (cx + sway, tip + 3), (cx + w - 2, by)], fill=A((250, 180, 60)))
            d.polygon([(cx - 1, by), (cx, tip + 6), (cx + 1, by)], fill=A((255, 240, 170)))
            for _ in range(2):
                d.point((cx + r.randint(-w, w), tip - r.randint(0, 2)), fill=A((255, 200, 90)))
            img.paste(outline(fr, 0.5), (0, f * S))
        save(img, name)

    flame_frames("campfire_anim", lay, 8, 13, 11, 4)

    def torch_base(d):
        d.line([(8, 15), (8, 9)], fill=A(WOOD), width=2)
        d.rectangle([6, 7, 10, 9], fill=A((90, 70, 56)))

    flame_frames("torch_anim", torch_base, 8, 8, 7, 2)

    def smoke(d, img):
        d.ellipse([2, 2, 13, 13], fill=A((150, 150, 150), 110))
        d.ellipse([5, 4, 11, 10], fill=A((190, 190, 190), 130))

    sprite("smoke", smoke, edge=False, noise=0.03)

    def thatch(x, y, r):
        v = (x + y * 3 + (y // 4) * 5) % 4
        c = ((196, 172, 104), (176, 152, 88), (212, 190, 122), (158, 134, 76))[v]
        if y % 4 == 0:
            c = mul(c, 0.78)
        return mul(c, 0.94 + r.random() * 0.12)

    tile("thatch", thatch)

    def wattle(x, y, r):
        row, colm = y // 2, x // 4
        over = (row + colm) % 2 == 0
        c = (146, 106, 66) if over else (104, 74, 46)
        if x % 4 == 0:
            c = mul((86, 62, 40), 1.0)
        return mul(c, 0.92 + r.random() * 0.16 - (y % 2) * 0.08)

    tile("wattle", wattle)
    tile("daub", grainy((204, 184, 150), 0.035, 0.08, 51, [((176, 156, 120), 0.05), ((214, 196, 120), 0.04)]))

    def drystone(x, y, r):
        row = y // 4
        off = (row * 5) % 7
        gap = y % 4 == 3 or (x + off) % 7 == 6
        if gap:
            return (58, 56, 54)
        shade = 0.82 + ((((x + off) // 7) * 3 + row * 5) % 5) * 0.07
        return mul(STONE, shade + (r.random() - 0.5) * 0.08)

    tile("drystone", drystone)
    tile("bed", grainy((58, 100, 60), 0.14, 0.2, 52, [((84, 128, 70), 0.14), ((38, 70, 44), 0.1), ((110, 84, 56), 0.04)]))

    def bed_side(x, y, r):
        if y > 10:
            return mul(WOOD, 0.85 + ((x // 3) % 2) * 0.2 + (r.random() - 0.5) * 0.1)
        return mul((58, 100, 60), 0.85 + r.random() * 0.3)

    tile("bed_side", bed_side)
    tile("bedroll", grainy(FUR, 0.14, 0.18, 53, [(mul(FUR, 1.3), 0.12), (FUR_D, 0.1)]))
    tile("bedroll_side", grainy(mul(FUR, 0.85), 0.14, 0.18, 54, [(HIDE, 0.2)]))

    def weave(x, y, r):
        over = ((x // 2) + (y // 2)) % 2 == 0
        c = (198, 172, 108) if over else (160, 134, 78)
        return mul(c, 0.94 + r.random() * 0.12 - (0.1 if (x % 2 == 1 and over) else 0))

    tile("basket", weave)

    def basket_top(x, y, r):
        if 2 <= x <= 13 and 2 <= y <= 13:
            return mul((70, 56, 38), 0.9 + r.random() * 0.2)
        return weave(x, y, r)

    tile("basket_top", basket_top)
    tile("remains", grainy((126, 112, 96), 0.1, 0.16, 55, [((92, 80, 68), 0.1), ((150, 60, 54), 0.02)]))

    def snare(rabbit):
        def draw(d, img):
            d.line([(3, 15), (4, 5)], fill=A(WOOD), width=1)
            d.line([(4, 5), (9, 3)], fill=A(WOOD))
            d.line([(9, 3), (10, 9)], fill=A(TAN))
            d.ellipse([7, 9, 13, 14], outline=A(TAN))
            if rabbit:
                d.ellipse([6, 10, 13, 15], fill=A((150, 126, 100)))
                d.ellipse([11, 8, 14, 11], fill=A((160, 136, 108)))
                d.line([(12, 8), (11, 5)], fill=A((150, 126, 100)))
        return draw

    sprite("snare", snare(False))
    sprite("snare_caught", snare(True))

    def bobber(d, img):
        d.ellipse([4, 4, 11, 11], fill=A((240, 240, 236)))
        d.pieslice([4, 4, 11, 11], 180, 360, fill=A((210, 50, 44)))
        d.line([(7, 1), (7, 4)], fill=A(WOOD_D))

    sprite("bobber", bobber)


def hud_and_fx():
    Image.new("RGBA", (1, 1), (255, 255, 255, 255)).save(TEX / "bc_white.png")

    def heart(d, img):
        c = (214, 62, 56)
        d.ellipse([2, 3, 8, 9], fill=A(c))
        d.ellipse([7, 3, 13, 9], fill=A(c))
        d.polygon([(2, 7), (13, 7), (8, 13), (7, 13)], fill=A(c))
        d.point((4, 5), fill=A((250, 170, 160)))

    sprite("hud_health", heart, noise=0.02)

    def temp(d, img):
        d.rounded_rectangle([6, 1, 9, 11], 1, fill=A((236, 236, 232)))
        d.ellipse([4, 9, 11, 15], fill=A((226, 110, 40)))
        d.line([(7, 5), (7, 11)], fill=A((226, 110, 40)), width=2)

    sprite("hud_temp", temp, noise=0.02)

    def drum(d, img):
        d.ellipse([5, 2, 13, 10], fill=A((196, 122, 62)))
        d.ellipse([8, 3, 11, 6], fill=A((226, 160, 96)))
        d.line([(6, 9), (3, 12)], fill=A(BONE), width=2)
        d.ellipse([1, 11, 4, 14], fill=A(BONE))

    sprite("hud_food", drum, noise=0.02)

    def drop(d, img):
        c = (78, 156, 222)
        d.polygon([(7, 1), (8, 1), (12, 9), (3, 9)], fill=A(c))
        d.ellipse([3, 6, 12, 14], fill=A(c))
        d.line([(5, 9), (5, 11)], fill=A((190, 226, 250)))

    sprite("hud_water", drop, noise=0.02)

    def moon(d, img):
        d.ellipse([2, 2, 13, 13], fill=A((176, 146, 214)))
        d.ellipse([6, 0, 15, 10], fill=(0, 0, 0, 0))

    sprite("hud_rest", moon, noise=0.02)

    def hand(x, y, r):
        return mul((214, 168, 136), 0.94 + r.random() * 0.1 - (0.12 if x in (0, 15) else 0))

    tile("hand", hand)

    # one thin streak on a transparent square (particles are drawn square)
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y in range(16):
        img.putpixel((8, y), (200, 216, 238, int(40 + 150 * (y / 15))))
    save(img, "rain")
    img = Image.new("RGBA", (5, 5))
    for y in range(5):
        for x in range(5):
            d = math.hypot(x - 2, y - 2)
            if d < 2.4:
                img.putpixel((x, y), (250, 252, 255, clamp(255 - d * 80)))
    save(img, "snowflake")


# ----------------------------------------------------------------------------
# Box models: animals and the player are built from cuboids, each face mapped
# to one cell of a small colour atlas.
# ----------------------------------------------------------------------------
GRID = 4          # atlas is GRID x GRID cells
CELL = 16


class Model:
    def __init__(self):
        self.v, self.vt, self.vn, self.f = [], [], [], []

    def uv(self, cell):
        cx, cy = cell % GRID, cell // GRID
        e = 0.6 / (GRID * CELL)
        u0, u1 = cx / GRID + e, (cx + 1) / GRID - e
        v1, v0 = 1 - cy / GRID - e, 1 - (cy + 1) / GRID + e
        base = len(self.vt)
        self.vt += [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        return [base + 1, base + 2, base + 3, base + 4]

    def box(self, x0, y0, z0, x1, y1, z1, cell, faces=None):
        faces = faces or {}
        c = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        quads = {
            "front": ([5, 4, 7, 6], (0, 0, 1)),    # +z
            "back": ([0, 1, 2, 3], (0, 0, -1)),
            "right": ([1, 5, 6, 2], (1, 0, 0)),
            "left": ([4, 0, 3, 7], (-1, 0, 0)),
            "top": ([3, 2, 6, 7], (0, 1, 0)),
            "bottom": ([4, 5, 1, 0], (0, -1, 0)),
        }
        for name, (idx, normal) in quads.items():
            base = len(self.v)
            self.v += [c[i] for i in idx]
            self.vn.append(normal)
            uv = self.uv(faces.get(name, cell))
            n = len(self.vn)
            # Wind the face outward, keeping each vertex paired with its UV.
            self.f.append([(base + k + 1, uv[k], n) for k in (0, 3, 2, 1)])

    def transform(self, fn):
        self.v = [fn(*p) for p in self.v]
        self.vn = [fn(*n, True) for n in self.vn]

    def write(self, name, scale=10):
        lines = ["# Backcountry model, generated by tools/make_assets.py", f"o {name}"]
        lines += [f"v {x * scale:.4f} {y * scale:.4f} {z * scale:.4f}" for x, y, z in self.v]
        lines += [f"vt {u:.5f} {v:.5f}" for u, v in self.vt]
        lines += [f"vn {x:.3f} {y:.3f} {z:.3f}" for x, y, z in self.vn]
        for face in self.f:
            lines.append("f " + " ".join(f"{a}/{b}/{c}" for a, b, c in face))
        (MODELS / f"bc_{name}.obj").write_text("\n".join(lines) + "\n")


def atlas(name, cells, details=None):
    """cells: list of (colour, noise). details: {cell: fn(draw, ox, oy)}."""
    img = Image.new("RGBA", (GRID * CELL, GRID * CELL), (0, 0, 0, 255))
    px = img.load()
    r = random.Random(name)
    for i in range(GRID * GRID):
        col, noise = cells[i] if i < len(cells) else cells[0]
        vn = VNoise(f"{name}{i}", 4, CELL)
        for y in range(CELL):
            for x in range(CELL):
                f = 1 + (vn.at(x, y) - 0.5) * noise * 1.4 + (r.random() - 0.5) * noise
                px[(i % GRID) * CELL + x, (i // GRID) * CELL + y] = mul(col, f) + (255,)
    d = ImageDraw.Draw(img)
    for cell, fn in (details or {}).items():
        fn(d, (cell % GRID) * CELL, (cell // GRID) * CELL)
    save(img, name)


def eyes(color=(20, 18, 18), y=5, x1=3, x2=11, nose=None, nose_y=11):
    def fn(d, ox, oy):
        d.rectangle([ox + x1, oy + y, ox + x1 + 1, oy + y + 1], fill=color + (255,))
        d.rectangle([ox + x2, oy + y, ox + x2 + 1, oy + y + 1], fill=color + (255,))
        if nose:
            d.rectangle([ox + 6, oy + nose_y, ox + 9, oy + nose_y + 2], fill=nose + (255,))
    return fn


def quadruped(m, body, legs, leg_w, cells):
    """body = (half_width, y0, y1, z0, z1); legs = (height, front_z, back_z)."""
    hw, y0, y1, z0, z1 = body
    m.box(-hw, y0, z0, hw, y1, z1, cells["body"], {"bottom": cells.get("belly", cells["body"])})
    h, fz, bz = legs
    for sx in (-1, 1):
        xa, xb = sorted((sx * (hw - leg_w), sx * hw))
        m.box(xa, 0, fz, xb, h, fz + leg_w, cells["leg"])
        m.box(xa, 0, bz, xb, h, bz + leg_w, cells["leg"])


def models():
    # Deer
    m = Model()
    c = {"body": 0, "belly": 1, "leg": 3}
    quadruped(m, (0.2, 0.62, 1.04, -0.55, 0.42), (0.64, 0.26, -0.52), 0.11, c)
    m.box(-0.09, 0.92, 0.32, 0.09, 1.36, 0.56, 0)
    m.box(-0.12, 1.26, 0.42, 0.12, 1.5, 0.84, 0, {"front": 2})
    m.box(-0.07, 1.26, 0.84, 0.07, 1.4, 0.92, 4)
    for sx in (-1, 1):
        xa, xb = sorted((sx * 0.12, sx * 0.2))
        m.box(xa, 1.46, 0.46, xb, 1.6, 0.52, 6)
        xa, xb = sorted((sx * 0.05, sx * 0.09))
        m.box(xa, 1.5, 0.52, xb, 1.82, 0.56, 5)
        xa, xb = sorted((sx * 0.09, sx * 0.22))
        m.box(xa, 1.7, 0.52, xb, 1.74, 0.56, 5)
        xa, xb = sorted((sx * 0.18, sx * 0.22))
        m.box(xa, 1.74, 0.52, xb, 1.9, 0.56, 5)
    m.box(-0.05, 0.88, -0.63, 0.05, 1.04, -0.55, 7)
    m.write("deer")
    atlas("deer", [((154, 114, 76), 0.14), ((204, 180, 146), 0.1), ((158, 118, 80), 0.1), ((112, 82, 56), 0.12),
                   ((40, 34, 32), 0.05), ((226, 216, 190), 0.06), ((132, 96, 66), 0.1), ((240, 236, 226), 0.05)],
          {2: eyes(nose=None, y=4)})

    # Wolf
    m = Model()
    c = {"body": 0, "belly": 1, "leg": 3}
    quadruped(m, (0.16, 0.4, 0.74, -0.5, 0.34), (0.42, 0.2, -0.48), 0.1, c)
    m.box(-0.14, 0.54, 0.3, 0.14, 0.86, 0.6, 0, {"front": 2})
    m.box(-0.07, 0.54, 0.6, 0.07, 0.68, 0.8, 1, {"front": 4})
    for sx in (-1, 1):
        xa, xb = sorted((sx * 0.06, sx * 0.14))
        m.box(xa, 0.86, 0.34, xb, 0.98, 0.4, 3)
    m.box(-0.05, 0.5, -0.86, 0.05, 0.62, -0.5, 3)
    m.write("wolf")
    atlas("wolf", [((112, 112, 116), 0.16), ((186, 184, 180), 0.1), ((118, 118, 122), 0.1), ((78, 78, 84), 0.12),
                   ((30, 28, 28), 0.05)],
          {2: eyes(color=(214, 170, 50), y=6)})

    # Bear
    m = Model()
    c = {"body": 0, "belly": 0, "leg": 3}
    quadruped(m, (0.38, 0.45, 1.08, -0.72, 0.5), (0.46, 0.24, -0.7), 0.22, c)
    m.box(-0.24, 0.72, 0.5, 0.24, 1.16, 0.9, 0, {"front": 2})
    m.box(-0.12, 0.72, 0.9, 0.12, 0.9, 1.08, 1, {"front": 4})
    for sx in (-1, 1):
        xa, xb = sorted((sx * 0.14, sx * 0.24))
        m.box(xa, 1.16, 0.56, xb, 1.26, 0.64, 3)
    m.write("bear")
    atlas("bear", [((84, 58, 40), 0.18), ((150, 116, 82), 0.1), ((90, 62, 44), 0.1), ((60, 42, 30), 0.14),
                   ((26, 22, 22), 0.05)],
          {2: eyes(y=5, x1=4, x2=10)})

    # Rabbit
    m = Model()
    m.box(-0.1, 0.06, -0.2, 0.1, 0.28, 0.12, 0, {"bottom": 1})
    m.box(-0.08, 0.2, 0.08, 0.08, 0.38, 0.26, 0, {"front": 2})
    for sx in (-1, 1):
        xa, xb = sorted((sx * 0.02, sx * 0.07))
        m.box(xa, 0.38, 0.12, xb, 0.58, 0.16, 3)
        xa, xb = sorted((sx * 0.04, sx * 0.1))
        m.box(xa, 0, 0.02, xb, 0.06, 0.1, 3)
        m.box(xa, 0, -0.2, xb, 0.08, -0.06, 3)
    m.box(-0.04, 0.12, -0.26, 0.04, 0.22, -0.2, 4)
    m.write("rabbit")
    atlas("rabbit", [((150, 126, 100), 0.16), ((214, 200, 180), 0.1), ((154, 130, 104), 0.1), ((122, 100, 80), 0.12),
                     ((242, 240, 234), 0.04)],
          {2: eyes(y=5, nose=(206, 150, 150), nose_y=10)})

    # Grouse
    m = Model()
    m.box(-0.09, 0.1, -0.15, 0.09, 0.28, 0.12, 0, {"bottom": 1})
    m.box(-0.05, 0.24, 0.07, 0.05, 0.38, 0.19, 0, {"front": 2})
    m.box(-0.015, 0.28, 0.19, 0.015, 0.32, 0.24, 4)
    m.box(-0.1, 0.18, -0.26, 0.1, 0.3, -0.15, 3)
    for sx in (-1, 1):
        xa, xb = sorted((sx * 0.03, sx * 0.05))
        m.box(xa, 0, -0.02, xb, 0.1, 0.0, 4)
    m.write("grouse")
    atlas("grouse", [((126, 100, 74), 0.24), ((190, 174, 150), 0.14), ((130, 104, 78), 0.14), ((86, 68, 52), 0.2),
                     ((208, 176, 96), 0.06)],
          {2: eyes(y=5, x1=2, x2=12)})

    # Player: standing and lying (asleep)
    def player():
        p = Model()
        skin, shirt, trou, hair, face, shoe = 0, 1, 2, 3, 4, 5
        for sx in (-1, 1):
            xa, xb = sorted((0, sx * 0.2))
            p.box(xa, 0.08, -0.1, xb, 0.72, 0.1, trou)
            p.box(xa, 0, -0.1, xb, 0.08, 0.14, shoe)
            xa, xb = sorted((sx * 0.2, sx * 0.34))
            p.box(xa, 0.92, -0.09, xb, 1.32, 0.09, shirt)
            p.box(xa, 0.66, -0.09, xb, 0.92, 0.09, skin)
        p.box(-0.2, 0.72, -0.1, 0.2, 1.32, 0.1, shirt)
        p.box(-0.19, 1.32, -0.19, 0.19, 1.7, 0.19, skin, {"front": face, "top": hair, "back": hair})
        return p

    cells = [((214, 168, 136), 0.05), ((120, 136, 150), 0.1), ((110, 96, 78), 0.1), ((74, 54, 40), 0.14),
             ((214, 168, 136), 0.04), ((70, 60, 54), 0.08)]

    def face(d, ox, oy):
        d.rectangle([ox, oy, ox + 15, oy + 3], fill=(74, 54, 40, 255))
        d.rectangle([ox + 3, oy + 7, ox + 5, oy + 8], fill=(40, 34, 34, 255))
        d.rectangle([ox + 10, oy + 7, ox + 12, oy + 8], fill=(40, 34, 34, 255))
        d.rectangle([ox + 5, oy + 12, ox + 10, oy + 12], fill=(150, 96, 86, 255))

    atlas("player", cells, {4: face})
    player().write("player")
    lying = player()
    # Swapping Y and Z lays the player face up and reverses the winding.
    lying.transform(lambda x, y, z, is_normal=False: (x, z, y) if is_normal else (x, z + 0.12, y - 0.85))
    for face_ in lying.f:
        face_.reverse()
    lying.write("player_lying")


def menu():
    menu_dir = ROOT / "menu"
    menu_dir.mkdir(exist_ok=True)
    # icon: a small fire under a pine, enlarged pixel art
    img = Image.new("RGBA", (16, 16), (24, 34, 40, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 12, 15, 15], fill=(52, 72, 50, 255))
    d.polygon([(4, 12), (7, 2), (10, 12)], fill=(38, 82, 52, 255))
    d.polygon([(5, 8), (7, 1), (9, 8)], fill=(52, 104, 64, 255))
    d.rectangle([7, 12, 7, 13], fill=(90, 64, 44, 255))
    d.polygon([(11, 13), (12, 9), (14, 13)], fill=(240, 130, 40, 255))
    d.point((12, 12), fill=(255, 226, 120, 255))
    for x, y in ((2, 2), (12, 3), (14, 6), (1, 7)):
        d.point((x, y), fill=(236, 240, 250, 255))
    img.resize((256, 256), Image.NEAREST).save(menu_dir / "icon.png")

    w, h = 96, 24
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = random.Random(77)
    for x in range(0, w, 5):
        hh = r.randint(8, 18)
        d.polygon([(x - 3, h), (x + 2, h - hh), (x + 7, h)], fill=(30, 66, 44, 255))
    d.rectangle([0, h - 3, w, h], fill=(40, 58, 40, 255))
    img.resize((w * 6, h * 6), Image.NEAREST).save(menu_dir / "header.png")


if __name__ == "__main__":
    terrain()
    trees()
    plants()
    items()
    food()
    pots_and_clothes()
    fire_and_build()
    hud_and_fx()
    models()
    menu()
    print(f"{len(list(TEX.glob('*.png')))} textures, {len(list(MODELS.glob('*.obj')))} models")
