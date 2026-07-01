"""Generate a branded 'Loan Manager' icon: gradient rounded square + white
rupee glyph + rising growth bars. Exports the in-app logo asset and all
Android launcher mipmap sizes."""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
ASSETS = os.path.join(ROOT, "assets")
os.makedirs(ASSETS, exist_ok=True)

S = 1024
TOP = (0x2E, 0x6B, 0xF0)      # blue
BOT = (0x15, 0x3A, 0xA8)      # deep indigo-blue


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def build(size):
    # vertical gradient
    grad = Image.new("RGB", (size, size))
    px = grad.load()
    for y in range(size):
        c = lerp(TOP, BOT, y / (size - 1))
        for x in range(size):
            px[x, y] = c
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.paste(grad, (0, 0), rounded_mask(size, int(size * 0.22)))

    d = ImageDraw.Draw(img)
    # rising growth bars (bottom-left), semi-transparent white
    bar_w = int(size * 0.075)
    gap = int(size * 0.045)
    base_y = int(size * 0.74)
    x0 = int(size * 0.28)
    heights = [0.10, 0.17, 0.24]
    for i, h in enumerate(heights):
        x = x0 + i * (bar_w + gap)
        top = base_y - int(size * h)
        d.rounded_rectangle([x, top, x + bar_w, base_y],
                            radius=bar_w // 2, fill=(255, 255, 255, 90))

    # rupee glyph, bold white, centered upper area
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", int(size * 0.62))
    except Exception:
        font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", int(size * 0.62))
    glyph = "₹"  # ₹
    bbox = d.textbbox((0, 0), glyph, font=font)
    gw, gh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    gx = (size - gw) / 2 - bbox[0]
    gy = (size - gh) / 2 - bbox[1] - int(size * 0.04)
    d.text((gx, gy), glyph, font=font, fill=(255, 255, 255, 255))
    return img


master = build(S)
master.save(os.path.join(ASSETS, "logo.png"))
print("wrote assets/logo.png")

sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for name, px in sizes.items():
    out = os.path.join(RES, f"mipmap-{name}", "ic_launcher.png")
    master.resize((px, px), Image.LANCZOS).save(out)
    print("wrote", out)
print("done")
