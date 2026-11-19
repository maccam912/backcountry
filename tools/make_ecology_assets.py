"""Draw the forest-floor sprites and horizontal track mesh at game resolution."""
from pathlib import Path
from random import Random

from PIL import Image, ImageDraw

MOD = Path(__file__).resolve().parents[1] / "mods" / "bc"


def save(image, name):
    image.save(MOD / "textures" / f"bc_{name}.png")


def cuttings():
    for colour, stem, tips in (
        ("blue", "#77533b", "#a5bc66"), ("red", "#914e44", "#c1bb71"),
    ):
        im = Image.new("RGBA", (16, 16))
        d = ImageDraw.Draw(im)
        d.line([(6, 14), (8, 10), (8, 6), (11, 3)], fill="#443b2a", width=2)
        d.line([(6, 13), (7, 10), (8, 8), (8, 6), (10, 4)], fill=stem)
        for x, y, direction in [(7, 11, -1), (8, 8, 1), (8, 6, -1), (10, 4, 1)]:
            d.polygon([(x, y), (x+2*direction, y), (x+4*direction, y-3),
                       (x+direction, y-2)], fill="#3d643f")
            d.line((x+direction, y-1, x+3*direction, y-2), fill=tips)
        d.point((6, 14), fill="#e0c69b")
        save(im, f"bush_{colour}_cutting")


def nurse_log():
    rng = Random(317)
    im = Image.new("RGB", (16, 16), "#524134")
    d = ImageDraw.Draw(im)
    for _ in range(54):
        x, y = rng.randrange(16), rng.randrange(16)
        d.line((x, y, x+rng.randrange(2, 8), y),
               fill=rng.choice(["#2e3028", "#5c4733", "#786449", "#69523e"]))
    save(im, "log_bark")
    moss = im.copy()
    md = ImageDraw.Draw(moss)
    for _ in range(78):
        x, y = rng.randrange(16), rng.randrange(16)
        md.ellipse((x-1, y-1, x+rng.randrange(3), y+1),
                   fill=rng.choice(["#4a6342", "#61774b", "#40523a", "#738052", "#899360"]))
    save(moss, "log_moss")
    for x, y, w in [(3, 11, 3), (8, 13, 3), (11, 8, 2)]:
        d.line((x, y+1, x+w, y+1), fill="#302e28")
        d.line((x, y, x+w, y), fill="#ccb788")
        d.line((x+1, y-1, x+w-1, y-1), fill="#9a7552")
    save(im, "log_brackets")
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    d.polygon([(2, 11), (4, 6), (8, 4), (13, 6), (14, 9), (11, 12), (5, 13)], fill="#493b31")
    d.polygon([(3, 10), (5, 7), (9, 5), (12, 7), (13, 9), (10, 11), (5, 12)], fill="#dbbb83")
    d.line([(4, 9), (8, 7), (11, 7), (12, 8)], fill="#926c4a", width=2)
    d.point((8, 5), fill="#edce90")
    for x, y in [(5, 11), (7, 10), (9, 10), (10, 9)]:
        d.point((x, y), fill="#af8958")
    save(im, "tinder_conk")


def prints():
    # Two staggered impressions on a transparent tile, toes toward +Z.
    ink, edge = "#302d2b", "#72654d"
    for animal in ["rabbit", "grouse", "deer", "wolf", "bear"]:
        im = Image.new("RGBA", (32, 32))
        d = ImageDraw.Draw(im)
        for x, y in [(10, 14), (21, 23)]:
            if animal == "grouse":
                for dx, dy in [(-4, -4), (0, -6), (4, -4), (0, 2)]:
                    d.line((x+1, y+1, x+dx+1, y+dy+1), fill=edge)
                    d.line((x, y, x+dx, y+dy), fill=ink)
            elif animal == "deer":
                for side in [-1, 1]:
                    d.polygon([(x+side, y-5), (x+4*side, y-1),
                               (x+4*side, y+3), (x+2*side, y+4), (x+side, y+2)], fill=ink)
                    d.point((x+3*side, y+3), fill=edge)
            elif animal == "rabbit":
                d.ellipse((x-2, y-6, x+1, y+1), fill=ink)
                d.ellipse((x-1, y+6, x+1, y+9), fill=ink)
                d.point((x+1, y), fill=edge)
            else:
                bear = animal == "bear"
                w = 4 if bear else 3
                d.ellipse((x-w, y-1, x+w, y+4+(2 if bear else 0)), fill=ink)
                d.line((x-1, y+4, x+1, y+4), fill=edge)
                toes = [-5, -3, 0, 3, 5] if bear else [-4, -1, 2, 4]
                for dx in toes:
                    ty = y - (3 if abs(dx) > 3 else 5)
                    d.ellipse((x+dx-1, ty-1, x+dx, ty+1), fill=ink)
        save(im, f"track_{animal}")

    im = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(im)
    for x, y, r in [(6, 22, 3), (13, 27, 2), (18, 10, 3), (23, 6, 1), (15, 16, 1)]:
        d.ellipse((x-r, y-r, x+r, y+r), fill="#641d24")
        d.ellipse((x-r, y-r, x+r-1, y+r-1), fill="#ba3430")
        d.point((x-r+1, y-r+1), fill="#e2674c")
    save(im, "track_blood")

    (MOD / "models/bc_trail_print.obj").write_text(
        "# Track on the ground, +Z is forward. One Luanti block is ten OBJ units.\n"
        "o trail_print\nv -3.4 0 -4.2\nv 3.4 0 -4.2\nv 3.4 0 4.2\nv -3.4 0 4.2\n"
        "vt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\nvn 0 1 0\nf 1/1/1 4/4/1 3/3/1 2/2/1\n")


if __name__ == "__main__":
    cuttings()
    nurse_log()
    prints()
