"""Draw the campcraft inventory icons and node faces on the game's pixel grid."""
from pathlib import Path
from random import Random

from PIL import Image, ImageDraw

TEX = Path(__file__).resolve().parents[1] / "mods" / "bc" / "textures"


def pallet():
    """Loose, overlapping straw over a pair of crosswise sticks."""
    palette = ["#816d43", "#927c49", "#a68b51", "#b99c5c", "#c9ad70", "#dec283"]
    rng = Random(126)
    top = Image.new("RGB", (32, 32), palette[0])
    d = ImageDraw.Draw(top)
    for y in (7, 24):
        d.line((1, y, 30, y + 1), fill="#694b31", width=3)
        d.line((2, y - 1, 29, y), fill="#a17c50")
    for _ in range(155):
        x, y = rng.randrange(2, 29), rng.randrange(-4, 32)
        end = x + rng.randrange(-3, 4)
        length = rng.randrange(4, 11)
        d.line((x, y, x, y + length // 2, end, y + length), fill=rng.choice(palette))
    top.save(TEX / "bc_grass_pallet.png")
    side = Image.new("RGB", (16, 16), palette[0])
    d = ImageDraw.Draw(side)
    for y in range(16):
        for _ in range(8):
            x = rng.randrange(-3, 16)
            d.line((x, y, x + rng.randrange(2, 8), y), fill=rng.choice(palette))
    side.save(TEX / "bc_grass_pallet_side.png")


def markers():
    bark = Image.new("RGB", (32, 32))
    rng = Random(287)
    for y in range(32):
        for x in range(32):
            v = rng.randrange(-8, 9) + (9 if x % 7 == 2 else 0)
            bark.putpixel((x, y), (191 + v, 159 + v, 105 + v))
    d = ImageDraw.Draw(bark)
    for _ in range(26):
        x, y = rng.randrange(32), rng.randrange(30)
        d.line((x, y, x, y + rng.randrange(2, 8)), fill="#ac8a60")
    # Luanti maps the north edge of the upper face to the top of the tile.
    d.polygon([(16, 5), (23, 12), (19, 12), (19, 15), (14, 15),
               (14, 12), (9, 12)], fill="#3d3226")
    for sign in ("trail", "camp", "water", "fish", "berries"):
        image = bark.copy()
        d = ImageDraw.Draw(image)
        if sign == "trail":
            d.line((15, 17, 15, 24), fill="#473629", width=3)
            d.line((18, 17, 18, 24), fill="#594533", width=1)
        elif sign == "water":
            d.polygon([(16, 16), (20, 21), (20, 24), (18, 26),
                       (14, 26), (12, 24), (12, 21)], fill="#346377")
            d.line((14, 21, 14, 23), fill="#91b4b5")
        elif sign == "fish":
            d.polygon([(8, 22), (13, 18), (18, 18), (21, 21),
                       (24, 18), (24, 25), (21, 23), (17, 26),
                       (13, 26)], fill="#445947")
            d.point((13, 21), fill="#ded3a5")
        elif sign == "berries":
            d.line((12, 18, 18, 17, 21, 19), fill="#4c5631", width=2)
            for x, y in [(11, 19), (17, 20), (14, 23)]:
                d.ellipse((x, y, x + 4, y + 4), fill="#89483d")
                d.point((x + 1, y + 1), fill="#b76b51")
        else:
            d.line((9, 25, 22, 25), fill="#49382a", width=2)
            d.polygon([(12, 23), (11, 20), (14, 20), (15, 16), (19, 19),
                       (20, 17), (21, 22), (19, 24), (14, 24)], fill="#9c5131")
            d.line((16, 21, 17, 23), fill="#d38a50", width=2)
        image.save(TEX / f"bc_marker_{sign}.png")


def tools():
    stone = Image.new("RGB", (32, 32))
    rng = Random(309)
    for y in range(32):
        for x in range(32):
            v = rng.randrange(-7, 8)
            if ((x - y * 0.19 - 17) / 8) ** 2 + ((y - 16) / 13) ** 2 < 1:
                v -= 21
            stone.putpixel((x, y), (130 + v, 128 + v, 117 + v))
    d = ImageDraw.Draw(stone)
    for _ in range(18):
        x, y = rng.randrange(10, 24), rng.randrange(5, 21)
        d.line((x, y, x + 1, y + rng.randrange(3, 8)), fill="#929185")
    stone.save(TEX / "bc_honing_slab.png")
    image = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(image)
    d.line((6, 28, 23, 4), fill="#513b29", width=4)
    d.line((7, 26, 23, 4), fill="#b28453", width=2)
    for x, y in [(12, 20), (15, 16), (17, 13), (19, 9)]:
        d.line((x, y, x - 5, y - 2, x - 7, y - 6, x - 5, y - 7), fill="#634a32", width=3)
        d.line((x, y - 1, x - 5, y - 3, x - 6, y - 6, x - 5, y - 7), fill="#edc48a", width=2)
        d.line((x + 1, y, x + 5, y, x + 8, y - 5), fill="#c79760", width=2)
    image.save(TEX / "bc_feather_stick.png")
    image = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(image)
    d.polygon([(3, 20), (15, 4), (21, 3), (26, 6), (28, 11),
               (15, 28), (9, 29), (4, 26)], fill="#55402d")
    d.polygon([(5, 20), (16, 6), (21, 6), (26, 10), (13, 26),
               (9, 27), (5, 24)], fill="#c7945d")
    d.line((8, 21, 19, 7), fill="#e6bf87", width=3)
    d.line((12, 23, 22, 10), fill="#a56f43", width=2)
    for x, y in [(9, 15), (11, 12), (13, 10)]:
        d.line((x, y, x + 2, y + 3, x + 8, y + 7), fill="#64533b", width=3)
        d.line((x, y + 1, x + 3, y + 4, x + 8, y + 7), fill="#afab74")
    d.polygon([(16, 6), (20, 4), (24, 6), (26, 9), (23, 11), (18, 9)], fill="#3d352c")
    image.save(TEX / "bc_ember_roll.png")
    d.polygon([(17, 6), (20, 5), (23, 6), (25, 9), (22, 10), (18, 8)], fill="#a64e30")
    d.line((19, 6, 21, 8, 23, 8), fill="#ffc766", width=2)
    image.save(TEX / "bc_ember_roll_lit.png")


if __name__ == "__main__":
    pallet()
    markers()
    tools()
