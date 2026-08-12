#!/usr/bin/env python3
"""Generate a unique app icon for CastNow Standard (no lightning bolt)."""
from PIL import Image, ImageDraw, ImageFilter
import math, os

SIZE = 1024
img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background: dark gradient (slate-950 to slate-900)
for y in range(SIZE):
    r = int(2 + (15 - 2) * y / SIZE)
    g = int(6 + (23 - 6) * y / SIZE)
    b = int(23 + (42 - 23) * y / SIZE)
    draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

# Rounded rect mask for iOS
mask = Image.new('L', (SIZE, SIZE), 0)
mdraw = ImageDraw.Draw(mask)
mdraw.rounded_rectangle([0, 0, SIZE-1, SIZE-1], radius=225, fill=255)
bg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
bg.paste(img, (0, 0), mask)
img = bg
draw = ImageDraw.Draw(img)

cx, cy = SIZE // 2, SIZE // 2

# Draw a screen/monitor shape in the center
screen_w, screen_h = 420, 300
sx = cx - screen_w // 2
sy = cy - screen_h // 2 - 40

# Screen glow
for i in range(30, 0, -2):
    alpha = int(8 * (1 - i / 30))
    draw.rounded_rectangle(
        [sx - i, sy - i, sx + screen_w + i, sy + screen_h + i],
        radius=24 + i, outline=(6, 182, 212, alpha), width=2
    )

# Screen body
draw.rounded_rectangle(
    [sx, sy, sx + screen_w, sy + screen_h],
    radius=24, fill=(15, 23, 42, 255), outline=(6, 182, 212, 200), width=3
)

# Screen content - concentric signal arcs
arc_cx = cx
arc_cy = sy + screen_h // 2
for radius, alpha in [(50, 255), (80, 180), (110, 120), (140, 70)]:
    bbox = [arc_cx - radius, arc_cy - radius, arc_cx + radius, arc_cy + radius]
    draw.arc(bbox, start=200, end=340, fill=(6, 182, 212, alpha), width=max(3, radius // 20))

# Center dot
draw.ellipse(
    [arc_cx - 12, arc_cy - 12, arc_cx + 12, arc_cy + 12],
    fill=(6, 182, 212, 255)
)

# Stand/base under the screen
stand_w = 120
draw.rounded_rectangle(
    [cx - stand_w // 2, sy + screen_h + 10, cx + stand_w // 2, sy + screen_h + 30],
    radius=8, fill=(6, 182, 212, 180)
)
draw.rounded_rectangle(
    [cx - 80, sy + screen_h + 30, cx + 80, sy + screen_h + 42],
    radius=6, fill=(6, 182, 212, 120)
)

# Signal waves emanating from top-right of screen
wave_start_x = sx + screen_w - 60
wave_start_y = sy + 60
for radius, alpha in [(35, 100), (55, 70), (75, 40)]:
    draw.arc(
        [wave_start_x - radius, wave_start_y - radius,
         wave_start_x + radius, wave_start_y + radius],
        start=270, end=360, fill=(255, 255, 255, alpha), width=4
    )

# Save
out_dir = os.path.dirname(os.path.abspath(__file__))
out_path = os.path.join(out_dir, 'icon_standard_new.png')
img.save(out_path, 'PNG')
print(f'Generated: {out_path}')

# Generate all iOS sizes
SIZES = [
    (20, 1), (20, 2), (20, 3),
    (29, 1), (29, 2), (29, 3),
    (40, 1), (40, 2), (40, 3),
    (60, 2), (60, 3),
    (76, 1), (76, 2),
    (83.5, 2),
    (1024, 1),
]

appicon_dir = os.path.join(out_dir, '..', 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
os.makedirs(appicon_dir, exist_ok=True)

for base_size, scale in SIZES:
    actual = int(base_size * scale)
    resized = img.resize((actual, actual), Image.LANCZOS)
    if base_size == 1024:
        fname = f'Icon-App-{base_size}x{base_size}@1x.png'
    elif scale == 1:
        fname = f'Icon-App-{base_size}x{base_size}@1x.png'
    else:
        fname = f'Icon-App-{base_size}x{base_size}@{scale}x.png'
    resized.save(os.path.join(appicon_dir, fname), 'PNG')

print(f'All icon sizes generated in {appicon_dir}')
