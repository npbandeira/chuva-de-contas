"""Gera android/icon.png (512x512) com a fonte e as cores do jogo."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SIZE = 512

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# fundo: céu com chão, cantos arredondados
d.rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=110, fill=(214, 237, 245))
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=110, fill=255)
ground = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(ground).ellipse((-120, 380, SIZE + 120, 760), fill=(166, 153, 146))
img.paste(ground, (0, 0), Image.composite(ground, Image.new("RGBA", (SIZE, SIZE)), mask))

font = ImageFont.truetype(str(ROOT / "assets" / "PressStart2P.ttf"), 64)


def tile(cx, cy, text, color):
    w = d.textlength(text, font=font) + 60
    h = 110
    box = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
    shadow = tuple(v + 10 for v in box)
    d.rounded_rectangle(shadow, radius=26, fill=(0, 0, 0, 70))
    d.rounded_rectangle(box, radius=26, fill=color, outline=(255, 255, 255), width=10)
    d.text((cx, cy + 4), text, font=font, fill=(255, 255, 255), anchor="mm")


tile(SIZE / 2, 150, "2+3", (64, 140, 242))
tile(SIZE / 2, 310, "9:3", (242, 140, 51))

img.save(ROOT / "android" / "icon.png")
print("icone gerado:", ROOT / "android" / "icon.png")
