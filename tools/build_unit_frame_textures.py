"""Build the Unit Frames Onyx textures: the rounded rim and gap, the round
portrait circle and the satin bar fill (the retired Satin Matte, Inset Wells
and tile textures were removed with layout version 9).

Every texture is
neutral luminance (R=G=B) multiplied in-game by the frame's tint, so colour
choices stay in settings. Shapes are supersampled 8x for anti-aliased rounded
edges; grain uses a fixed seed so rebuilding is byte-identical.

    python tools/build_unit_frame_textures.py
"""
from pathlib import Path
import math
import random

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'ModeUI/Media/Textures/UnitFrames'
SS = 8  # supersampling factor for silhouettes

# Shape constants shared with Modules/UnitFrames/Layout.lua and Shared/Media/Media.lua
# (slice margins must cover each corner radius).
FRAME = (32, 32, 5)     # Onyx bar block rim; sliced at 6
FRAME_INNER = (32, 32, 3) # inner dark line backing, inset 2px inside FrameFill; sliced at 4
CIRCLE = 128            # anti-aliased circle for the portrait ring layers (downscaled crisply)
BAR = (64, 32)         # stretched status bar fill


def rounded_mask(width, height, radius, inset=0.0):
    """Anti-aliased rounded-rectangle alpha mask, optionally inset (in pixels)."""
    big = Image.new('L', (width * SS, height * SS), 0)
    i = inset * SS
    ImageDraw.Draw(big).rounded_rectangle(
        (i, i, width * SS - 1 - i, height * SS - 1 - i), radius=max(0, (radius - inset)) * SS, fill=255)
    return big.resize((width, height), Image.Resampling.LANCZOS)


def circle_mask(size, inset=0.0):
    big = Image.new('L', (size * SS, size * SS), 0)
    i = inset * SS
    ImageDraw.Draw(big).ellipse((i, i, size * SS - 1 - i, size * SS - 1 - i), fill=255)
    return big.resize((size, size), Image.Resampling.LANCZOS)


def grain(width, height, amplitude, seed):
    """Fine, slightly softened luminance noise in [-amplitude, amplitude]."""
    rng = random.Random(seed)
    raw = [[rng.uniform(-1, 1) for _ in range(width)] for _ in range(height)]
    out = []
    for y in range(height):
        row = []
        for x in range(width):
            # 3x3 weighted blur keeps the texture fine but never noisy.
            total = weight = 0.0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    w = 4 if dx == dy == 0 else (2 if dx == 0 or dy == 0 else 1)
                    total += raw[(y + dy) % height][(x + dx) % width] * w
                    weight += w
            row.append(total / weight * amplitude * 1.8)
        out.append(row)
    return out


def luminance_image(width, height, lum, alpha):
    img = Image.new('RGBA', (width, height))
    px = img.load()
    a = alpha.load()
    for y in range(height):
        for x in range(width):
            v = max(0, min(255, round(lum(x, y) * 255)))
            px[x, y] = (v, v, v, a[x, y])
    return img


def save(img, name):
    DEST.mkdir(parents=True, exist_ok=True)
    target = DEST / name
    img.save(target, compression=None)
    assert Image.open(target).convert('RGBA').tobytes() == img.tobytes()
    print('PASS', name, img.size)


def build():
    # Minimal Rounded (owner choice A): one thin, soft-cornered frame. The
    # backing doubles as the border and the 1px hairlines between portrait,
    # health and power; content sits 2 units in, inside the corner curve.
    w, h, r = FRAME
    save(luminance_image(w, h, lambda x, y: 1.0, rounded_mask(w, h, r)), 'FrameFill.tga')
    # Palette frame: tighter inner radius so the 1px inner line follows the
    # 2px outer border's curve; and a crisp circle for the round portrait cap.
    w, h, r = FRAME_INNER
    save(luminance_image(w, h, lambda x, y: 1.0, rounded_mask(w, h, r)), 'FrameInner.tga')
    save(luminance_image(CIRCLE, CIRCLE, lambda x, y: 1.0, circle_mask(CIRCLE)), 'Circle.tga')

    # Bar: satin fill for health/power, tinted by the bar colour.
    w, h = BAR
    noise = grain(w, h, 0.02, 3307)
    alpha = Image.new('L', (w, h), 255)

    def bar(x, y):
        t = y / (h - 1)
        v = 1.0 - 0.34 * t + 0.06 * math.exp(-((t - 0.18) / 0.14) ** 2)
        if y == 0:
            v = 1.0
        return min(1.0, v) + noise[y][x]
    save(luminance_image(w, h, bar, alpha), 'BarSatin.tga')


if __name__ == '__main__':
    build()
