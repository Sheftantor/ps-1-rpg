"""Procedural low-res PS1-style textures for the night-street kit."""
import os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont

STORE_NAME = "6-12"          # <- change this and re-run to re-letter the shop sign
BILLBOARD_NAME = "BIG BITE"

rnd = random.Random(1999)
nrng = np.random.default_rng(1999)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except Exception:
        return ImageFont.load_default()


def jitter(img, amt):
    a = np.asarray(img).astype(np.int16)
    n = nrng.integers(-amt, amt + 1, size=a.shape[:2] + (1,))
    a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def save(img, outdir, name):
    img.save(os.path.join(outdir, name + ".png"))


def brick_fill(d, W, H, colors, mortar=(92, 80, 74), bh=4, bw=10):
    d.rectangle([0, 0, W, H], fill=mortar)
    for r, y in enumerate(range(0, H, bh)):
        off = (bw // 2) if r % 2 else 0
        for x in range(-off, W, bw):
            c = rnd.choice(colors)
            d.rectangle([x + 1, y + 1, x + bw - 1, y + bh - 1], fill=c)


def facade(outdir, name, colors, bays=4, floors=2, bay=64, lit=0.28, ground_door=True, trim=(190, 180, 165)):
    W, H = bays * bay, floors * bay
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    brick_fill(d, W, H, colors)
    for f in range(floors):
        for b in range(bays):
            x0, y0 = b * bay, f * bay
            wx, wy, ww, wh = x0 + 17, y0 + 12, 30, 38
            if ground_door and f == floors - 1 and b == 1:
                d.rectangle([x0 + 14, y0 + 8, x0 + 50, y0 + bay], fill=(70, 40, 34))
                d.rectangle([x0 + 18, y0 + 12, x0 + 46, y0 + bay], fill=(40, 26, 24))
                d.rectangle([x0 + 22, y0 + 16, x0 + 42, y0 + 30], fill=(160, 150, 120))
                continue
            d.rectangle([wx - 2, wy - 2, wx + ww + 2, wy + wh + 2], fill=trim)
            islit = rnd.random() < lit
            glass = (255, 214, 120) if islit else rnd.choice([(30, 40, 70), (38, 50, 84), (24, 30, 52)])
            d.rectangle([wx, wy, wx + ww, wy + wh], fill=glass)
            if islit and rnd.random() < 0.5:
                d.rectangle([wx, wy, wx + ww, wy + 10], fill=(220, 120, 80))  # curtain
            d.line([wx + ww // 2, wy, wx + ww // 2, wy + wh], fill=trim)
            d.line([wx, wy + wh // 2, wx + ww, wy + wh // 2], fill=trim)
            d.rectangle([wx - 3, wy + wh + 2, wx + ww + 3, wy + wh + 4], fill=trim)  # sill
    save(jitter(img, 8), outdir, name)


def tower_panels(outdir, name, panel=(200, 96, 54), base=(150, 144, 138), cols=8, rows=8, cell=32, lit=0.2):
    W, H = cols * cell, rows * cell
    img = Image.new("RGB", (W, H), base)
    d = ImageDraw.Draw(img)
    for r in range(rows):
        d.rectangle([0, r * cell + cell - 5, W, r * cell + cell - 1], fill=(112, 108, 104))
    for c in range(cols):
        for r in range(rows):
            x0, y0 = c * cell, r * cell
            if c % 2 == 0:
                d.rectangle([x0 + 2, y0 + 2, x0 + cell - 2, y0 + cell - 7], fill=panel)
            islit = rnd.random() < lit
            glass = (255, 214, 120) if islit else rnd.choice([(26, 36, 62), (34, 46, 78), (22, 28, 50)])
            d.rectangle([x0 + 8, y0 + 7, x0 + cell - 9, y0 + cell - 11], fill=glass)
    save(jitter(img, 10), outdir, name)


def highrise(outdir, name, base=(44, 48, 58), cols=10, rows=20, cell=16, lit=0.35):
    img = Image.new("RGB", (cols * cell, rows * cell), base)
    d = ImageDraw.Draw(img)
    for c in range(cols):
        for r in range(rows):
            x0, y0 = c * cell, r * cell
            v = rnd.random()
            if v < lit:
                col = rnd.choice([(255, 220, 140), (200, 220, 255), (255, 240, 200), (240, 200, 90)])
            else:
                col = rnd.choice([(30, 34, 46), (36, 42, 58), (26, 28, 38)])
            d.rectangle([x0 + 2, y0 + 3, x0 + cell - 3, y0 + cell - 4], fill=col)
    save(jitter(img, 6), outdir, name)


def concrete(outdir, name, base=(120, 118, 112), stain=True, size=64):
    img = Image.new("RGB", (size, size), base)
    d = ImageDraw.Draw(img)
    if stain:
        for _ in range(10):
            x = rnd.randrange(size)
            d.rectangle([x, 0, x + rnd.randrange(1, 4), rnd.randrange(size // 3, size)], fill=tuple(max(0, c - 28) for c in base))
    save(jitter(img, 10), outdir, name)


def graffiti(outdir, name, base=(138, 136, 130)):
    size = 64
    img = Image.new("RGB", (size, size), base)
    d = ImageDraw.Draw(img)
    for _ in range(3):
        x, y = rnd.randrange(8, 40), rnd.randrange(12, 50)
        pts = [(x, y)]
        for _ in range(7):
            x += rnd.randrange(-9, 10)
            y += rnd.randrange(-9, 10)
            pts.append((max(1, min(62, x)), max(1, min(62, y))))
        d.line(pts, fill=rnd.choice([(14, 14, 18), (240, 240, 235), (200, 40, 60)]), width=2)
    save(jitter(img, 8), outdir, name)


def asphalt(outdir, name, size=128, marks="center_dashed"):
    img = Image.new("RGB", (size, size), (56, 56, 62))
    d = ImageDraw.Draw(img)
    if marks == "center_dashed":
        for y in range(0, size, 32):
            d.rectangle([size // 2 - 1, y + 4, size // 2 + 1, y + 20], fill=(222, 218, 200))
        d.rectangle([4, 0, 5, size], fill=(222, 218, 200))
        d.rectangle([size - 6, 0, size - 5, size], fill=(222, 218, 200))
    save(jitter(img, 9), outdir, name)


def pavers(outdir, name):
    size = 64
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    pal = [(92, 90, 104), (84, 82, 98), (104, 100, 112), (96, 92, 108), (78, 76, 92)]
    for x in range(0, size, 8):
        for y in range(0, size, 8):
            d.rectangle([x, y, x + 7, y + 7], fill=rnd.choice(pal))
    save(jitter(img, 5), outdir, name)


def slabs(outdir, name):
    size = 64
    img = Image.new("RGB", (size, size), (110, 112, 112))
    d = ImageDraw.Draw(img)
    for x in range(0, size, 32):
        for y in range(0, size, 32):
            d.rectangle([x, y, x + 31, y + 31], outline=(74, 76, 78))
    save(jitter(img, 8), outdir, name)


def grass(outdir, name):
    size = 64
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    pal = [(60, 92, 48), (48, 78, 40), (72, 104, 54), (40, 64, 36)]
    for x in range(0, size, 4):
        for y in range(0, size, 4):
            d.rectangle([x, y, x + 3, y + 3], fill=rnd.choice(pal))
    save(img, outdir, name)


def leaves(outdir, name):
    size = 64
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    pal = [(54, 86, 40), (74, 108, 44), (38, 62, 34), (96, 122, 52), (28, 48, 30)]
    for x in range(0, size, 3):
        for y in range(0, size, 3):
            d.rectangle([x, y, x + 2, y + 2], fill=rnd.choice(pal))
    save(img, outdir, name)


def bark(outdir, name):
    size = 32
    img = Image.new("RGB", (size, size), (66, 52, 44))
    d = ImageDraw.Draw(img)
    for x in range(0, size, 3):
        d.rectangle([x, 0, x + 1, size], fill=rnd.choice([(48, 38, 32), (78, 62, 52)]))
    save(jitter(img, 8), outdir, name)


def metal(outdir, name, col=(40, 42, 46)):
    save(jitter(Image.new("RGB", (16, 16), col), 6), outdir, name)


def flat(outdir, name, col):
    save(jitter(Image.new("RGB", (16, 16), col), 5), outdir, name)


def wood(outdir, name, col=(118, 80, 48)):
    img = Image.new("RGB", (32, 32), col)
    d = ImageDraw.Draw(img)
    for y in range(0, 32, 8):
        d.line([0, y, 32, y], fill=tuple(int(c * 0.7) for c in col))
    save(jitter(img, 8), outdir, name)


def chainlink(outdir, name):
    size = 32
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(-size, size * 2, 8):
        d.line([i, 0, i + size, size], fill=(150, 152, 156, 255))
        d.line([i, size, i + size, 0], fill=(150, 152, 156, 255))
    img.save(os.path.join(outdir, name + ".png"))


def store_front(outdir, name):
    """Lit convenience-store front: glass + shelves glow, door, posters, 4m x 3m tile."""
    W, H = 256, 128
    img = Image.new("RGB", (W, H), (236, 232, 222))
    d = ImageDraw.Draw(img)
    for (x0, x1) in [(10, 118), (138, 246)]:
        d.rectangle([x0, 14, x1, 122], fill=(30, 34, 40))
        d.rectangle([x0 + 3, 17, x1 - 3, 119], fill=(255, 236, 190))
        for sy in (40, 66, 92):
            d.rectangle([x0 + 3, sy, x1 - 3, sy + 3], fill=(150, 150, 150))
            for sx in range(x0 + 6, x1 - 8, 10):
                d.rectangle([sx, sy - 14, sx + 6, sy - 1],
                            fill=rnd.choice([(220, 60, 50), (60, 120, 220), (240, 200, 40), (60, 170, 90), (230, 120, 40)]))
        d.line([(x0 + x1) // 2, 14, (x0 + x1) // 2, 122], fill=(30, 34, 40), width=2)
    d.rectangle([122, 14, 134, 122], fill=(30, 34, 40))
    save(jitter(img, 4), outdir, name)


def store_sign(outdir, name):
    W, H = 256, 64
    img = Image.new("RGB", (W, H), (22, 26, 22))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, 11], fill=(236, 120, 40))
    d.rectangle([0, 12, W - 1, 19], fill=(30, 140, 70))
    d.rectangle([0, 20, W - 1, 27], fill=(210, 40, 50))
    f = font(34)
    tw = d.textlength(STORE_NAME, font=f)
    d.text(((W - tw) / 2, 28), STORE_NAME, fill=(250, 250, 240), font=f)
    save(img, outdir, name)


def stripe_band(outdir, name):
    img = Image.new("RGB", (16, 16))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 5], fill=(236, 120, 40))
    d.rectangle([0, 5, 15, 10], fill=(30, 140, 70))
    d.rectangle([0, 11, 15, 15], fill=(210, 40, 50))
    save(img, outdir, name)


def billboard(outdir, name):
    W, H = 128, 64
    img = Image.new("RGB", (W, H), (240, 196, 40))
    d = ImageDraw.Draw(img)
    d.ellipse([6, 14, 60, 56], fill=(210, 140, 60))
    d.rectangle([10, 30, 56, 38], fill=(90, 60, 30))
    d.rectangle([10, 38, 56, 42], fill=(240, 220, 60))
    d.rectangle([10, 42, 56, 46], fill=(190, 50, 40))
    f = font(18)
    d.text((66, 18), BILLBOARD_NAME, fill=(200, 30, 36), font=f)
    d.text((66, 40), "OPEN LATE", fill=(40, 30, 30), font=font(12))
    save(jitter(img, 4), outdir, name)


def goods(outdir, name):
    img = Image.new("RGB", (64, 64), (200, 200, 200))
    d = ImageDraw.Draw(img)
    for y in range(0, 64, 16):
        for x in range(0, 64, 8):
            d.rectangle([x + 1, y + 2, x + 6, y + 14],
                        fill=rnd.choice([(220, 60, 50), (60, 120, 220), (240, 200, 40), (60, 170, 90), (230, 120, 40), (240, 240, 240)]))
        d.line([0, y + 15, 64, y + 15], fill=(120, 120, 120))
    save(img, outdir, name)


def fridge_glass(outdir, name):
    img = Image.new("RGB", (64, 64), (190, 220, 235))
    d = ImageDraw.Draw(img)
    for x in range(0, 64, 16):
        d.rectangle([x, 0, x + 1, 63], fill=(70, 80, 90))
        for y in range(4, 60, 14):
            d.rectangle([x + 3, y, x + 12, y + 10], fill=rnd.choice([(220, 50, 50), (50, 110, 230), (60, 190, 90), (250, 210, 40)]))
    save(img, outdir, name)


def checker_tile(outdir, name):
    img = Image.new("RGB", (32, 32), (214, 212, 206))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 15], fill=(90, 96, 104))
    d.rectangle([16, 16, 31, 31], fill=(90, 96, 104))
    save(jitter(img, 5), outdir, name)


def cig_wall(outdir, name):
    """Behind-the-counter wall: rows of small packs/boxes with shelf lips."""
    img = Image.new("RGB", (64, 64), (60, 60, 66))
    d = ImageDraw.Draw(img)
    for y in range(0, 64, 11):
        for x in range(1, 64, 5):
            c = rnd.choice([(230, 230, 220), (200, 40, 40), (40, 60, 160), (230, 190, 40), (30, 120, 70), (120, 30, 30)])
            d.rectangle([x, y + 2, x + 3, y + 9], fill=c)
            d.point((x + 1, y + 3), fill=(250, 250, 250))
        d.line([0, y + 10, 64, y + 10], fill=(150, 150, 156))
    save(img, outdir, name)


def menu_board(outdir, name):
    W, H = 128, 48
    img = Image.new("RGB", (W, H), (20, 22, 26))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, 4], fill=(236, 120, 40))
    d.rectangle([0, 5, W - 1, 7], fill=(30, 140, 70))
    f = font(10)
    for i, t in enumerate(("HOT DOGS", "SLUSH", "COFFEE")):
        d.text((6, 11 + i * 12), t, fill=(250, 220, 90), font=f)
    d.text((76, 11), "LOTTO", fill=(240, 60, 60), font=font(12))
    d.text((76, 28), "24 HR", fill=(240, 240, 240), font=font(12))
    save(img, outdir, name)


def make_all(outdir):
    os.makedirs(outdir, exist_ok=True)
    facade(outdir, "facade_brick_red", [(150, 70, 52), (138, 62, 46), (160, 80, 58), (126, 58, 44)])
    facade(outdir, "facade_brick_dark", [(104, 56, 48), (92, 50, 44), (112, 62, 52)], lit=0.22, trim=(150, 140, 128))
    facade(outdir, "facade_brick_tan", [(176, 140, 96), (164, 128, 88), (186, 150, 104)], lit=0.3)
    facade(outdir, "facade_shopfront", [(150, 70, 52), (138, 62, 46)], bays=4, floors=2, lit=0.4, ground_door=False)
    tower_panels(outdir, "tower_orange")
    tower_panels(outdir, "tower_green", panel=(86, 128, 104), base=(158, 156, 148))
    highrise(outdir, "highrise_glass")
    highrise(outdir, "highrise_warm", base=(70, 62, 54), lit=0.5)
    concrete(outdir, "concrete")
    concrete(outdir, "concrete_dark", base=(84, 84, 84))
    graffiti(outdir, "wall_graffiti")
    asphalt(outdir, "road_lines")
    asphalt(outdir, "road_plain", marks=None)
    pavers(outdir, "pavers")
    slabs(outdir, "slabs")
    grass(outdir, "grass")
    leaves(outdir, "leaves")
    bark(outdir, "bark")
    metal(outdir, "metal_dark")
    metal(outdir, "metal_grey", col=(120, 124, 130))
    flat(outdir, "red", (170, 40, 44))
    flat(outdir, "green_dark", (30, 70, 52))
    flat(outdir, "bin_green", (40, 86, 56))
    flat(outdir, "orange", (236, 110, 30))
    flat(outdir, "white", (232, 232, 226))
    flat(outdir, "yellow", (236, 200, 50))
    flat(outdir, "bottle_red", (200, 40, 36))
    flat(outdir, "lamp_glow", (255, 190, 90))
    flat(outdir, "light_strip", (250, 250, 240))
    flat(outdir, "black", (14, 14, 16))
    flat(outdir, "car_green", (30, 62, 50))
    flat(outdir, "roof_slate", (62, 64, 74))
    flat(outdir, "roof_tile", (112, 58, 46))
    flat(outdir, "dark_glass", (20, 26, 42))
    wood(outdir, "wood")
    chainlink(outdir, "chainlink")
    store_front(outdir, "store_front")
    store_sign(outdir, "store_sign")
    stripe_band(outdir, "store_stripes")
    billboard(outdir, "billboard_ad")
    goods(outdir, "goods")
    fridge_glass(outdir, "fridge_glass")
    checker_tile(outdir, "checker_tile")
    cig_wall(outdir, "cig_wall")
    menu_board(outdir, "menu_board")
    flat(outdir, "skin", (196, 146, 108))
    flat(outdir, "hair", (40, 28, 22))
    flat(outdir, "uniform", (34, 112, 66))
    flat(outdir, "trousers", (36, 38, 48))
    flat(outdir, "sausage", (170, 76, 52))
    flat(outdir, "bun", (222, 170, 96))
    flat(outdir, "door_mat", (40, 40, 44))


if __name__ == "__main__":
    import sys
    make_all(sys.argv[1])
