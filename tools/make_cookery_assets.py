"""Draw Backcountry's camp cookery tiles and pack icons at native pixel scale."""
from pathlib import Path

from PIL import Image, ImageDraw


TEX = Path(__file__).resolve().parents[1] / "mods/bc/textures"
RIM = "#cb936b"
SHADE = "#724736"
CLAY = "#a86b4c"
MEALS = {
    "stew": ("#9e592f", "#edc87f", "#713d31", "#96a150"),
    "chowder": ("#cda66a", "#f4dda1", "#997746", "#6a887b"),
}


def save(im, name):
    im.save(TEX / f"bc_{name}.png")


def surface(draw, box, palette, stage):
    broth, bright, dark, herb = palette
    x, y, w, h = box
    draw.ellipse((x, y, x + w, y + h), fill=broth)
    for dx, dy, color in [
        (2, 2, dark), (4, 1, bright), (5, 3, dark), (7, 2, herb), (3, 4, herb)
    ]:
        if stage == "last" and dx > 4:
            continue
        px, py = x + round(dx * w / 10), y + round(dy * h / 6)
        draw.line((px, py, px + (dx == 2 or stage == "raw"), py), fill=color)


def pot_art(dish, stage):
    name = f"pot_{dish}" + (f"_{stage}" if stage != "full" else "")
    palette = MEALS[dish]
    if stage == "raw":
        palette = ("#799293", palette[1], "#b77f76", "#64874e")
    tile = Image.open(TEX / "bc_pot_top.png").convert("RGBA")
    top = ImageDraw.Draw(tile)
    surface(top, (3, 3, 9, 9) if stage != "last" else (4, 5, 7, 6), palette, stage)
    save(tile, name)

    im = Image.new("RGBA", (16, 16))
    draw = ImageDraw.Draw(im)
    # Two loop handles, then the lip, belly, and foot of the earthen pot.
    for x in (0, 11):
        draw.rectangle((x, 6, x + 4, 9), fill=SHADE)
        draw.line((x + 1, 6, x + 3, 6), fill=RIM)
        draw.point((x + 2, 8), fill=(0, 0, 0, 0))
    draw.ellipse((2, 4, 13, 14), fill=SHADE)
    draw.ellipse((3, 4, 12, 12), fill=CLAY)
    draw.line((3, 9, 4, 11), fill=RIM)
    draw.ellipse((2, 3, 13, 8), fill=RIM)
    draw.ellipse((3, 3, 12, 7), fill=SHADE)
    surface(draw, (4, 5, 7, 1) if stage == "last" else (3, 4, 9, 2), palette, stage)
    if stage == "full":
        draw.line((6, 2, 5, 1), fill="#d4c6af")
        draw.point((9, 1), fill="#e2dac9")
    save(im, name + "_icon")


def cake_art():
    for baked in (False, True):
        im = Image.new("RGBA", (16, 16))
        draw = ImageDraw.Draw(im)
        if baked:
            draw.ellipse((1, 6, 14, 13), fill="#573a29")
            draw.ellipse((1, 5, 14, 11), fill="#cf975b")
            draw.arc((2, 5, 13, 11), 160, 295, fill="#efc083")
            draw.line((8, 11, 11, 10), fill="#9e653c")
        else:
            draw.polygon([(2, 8), (3, 6), (6, 4), (10, 4), (13, 7), (14, 10),
                          (11, 12), (6, 13), (2, 11)], fill="#8b6449")
            draw.ellipse((3, 5, 12, 11), fill="#c2a078")
        for x, y in ((4, 8), (9, 7), (7, 9), (11, 9)):
            draw.line((x, y, x + 1, y), fill="#73405a")
            draw.point((x, y - 1), fill="#a56a77")
        save(im, "berry_griddlecake" if baked else "berry_dough")


if __name__ == "__main__":
    for dish in MEALS:
        for stage in ("raw", "full", "last"):
            pot_art(dish, stage)
    rain = Image.open(TEX / "bc_pot_water.png").convert("RGBA")
    d = ImageDraw.Draw(rain)
    d.arc((3, 4, 10, 10), 110, 260, fill="#9ac7d4")
    d.line((7, 7, 9, 7), fill="#c2e1db")
    save(rain, "pot_rainwater")
    cake_art()
