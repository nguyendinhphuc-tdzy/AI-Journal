# Usage (Python with Pillow and NumPy):
#   python tool/align_nudaeng_side_frames.py <sprite-sheet.png> <out-dir>
# The grid below matches docs/design/nudaeng-street/drafts/nudaeng-side-sheet-draft.png.
"""Measure and align the 12 draft Nudaeng side poses.

Wheels: the light blue-grey hubs (and dark grey tyres around them), split
into rear and front by x. Each frame is moved (and scaled when its wheelbase
differs) so both wheels sit where frame 1's do. Feet: the lowest body
(beige) pixel, compared with the deck top and the road (wheel bottoms).
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sheet_path, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)
sheet = Image.open(sheet_path).convert('RGBA')
cols = [(32, 345), (384, 716), (760, 1063), (1126, 1424)]
rows = [(34, 363), (390, 719), (745, 1071)]
PAD = 24


def mask(px, lo, hi):
    return np.all((px[..., :3] >= lo) & (px[..., :3] <= hi), axis=-1) & (px[..., 3] > 200)


def wheels(px):
    """Rear and front wheel: centre from the hub, bottom from the tyre.

    The light blue-grey hubs near the ground are only inside the wheels;
    the stem, fork and grips share the tyres' greys and a lowered foot
    reaches the rear tyre, so neither can place a wheel.
    """
    tyre = mask(px, (40, 40, 40), (125, 125, 135)) & (
        np.abs(px[..., 0] - px[..., 2]) < 25)
    hub = mask(px, (175, 190, 210), (215, 230, 250))
    floor = np.nonzero(tyre)[0].max()
    hub[: floor - 60] = False
    ys, xs = np.nonzero(hub)
    order = np.unique(xs)
    split = order[np.argmax(np.diff(order))] + 1
    out = []
    for side in (xs < split, xs >= split):
        cx, cy = float(xs[side].mean()), float(ys[side].mean())
        lo, hi = int(cx) - 28, int(cx) + 28
        rows = np.nonzero(tyre[:, lo:hi].any(axis=1))[0]
        rows = rows[rows > cy]
        out.append(dict(cx=cx, cy=cy, bottom=float(rows.max() + 1)))
    return out


def feet(px, road):
    body = mask(px, (215, 180, 110), (255, 230, 175))
    deck = mask(px, (100, 200, 185), (160, 245, 235))
    by, bx = np.nonzero(body)
    dy, _ = np.nonzero(deck)
    return dict(lowest_body=float(by.max() + 1), deck_top=float(dy.min()),
                gap_to_road=float(road - (by.max() + 1)))


frames = []
for r, (y0, y1) in enumerate(rows):
    for c, (x0, x1) in enumerate(cols):
        crop = sheet.crop((x0 - PAD, y0 - PAD, x1 + PAD, y1 + PAD))
        px = np.array(crop).astype(int)
        rear, front = wheels(px)
        frames.append(dict(index=len(frames) + 1, image=crop, rear=rear,
                           front=front, feet=feet(px, rear['bottom'])))

ref = frames[0]
base = ref['front']['cx'] - ref['rear']['cx']
size = max(f['image'].size[0] for f in frames), max(f['image'].size[1] for f in frames)
canvas = (size[0] + 80, size[1] + 40)
# Frame 1's rear wheel lands here in every output frame.
anchor = (60 + ref['rear']['cx'], 20 + ref['rear']['bottom'])
report = []
for f in frames:
    wheelbase = f['front']['cx'] - f['rear']['cx']
    scale = base / wheelbase
    img = f['image']
    if abs(scale - 1) > .01:
        img = img.resize((round(img.size[0] * scale), round(img.size[1] * scale)),
                         Image.LANCZOS)
    rx, rb = f['rear']['cx'] * scale, f['rear']['bottom'] * scale
    out = Image.new('RGBA', canvas, (0, 0, 0, 0))
    dx, dy = round(anchor[0] - rx), round(anchor[1] - rb)
    out.alpha_composite(img, (dx, dy))
    out.save(out_dir / f"nudaeng-side-draft-{f['index']:02d}.png")
    # Re-measure after alignment.
    px = np.array(out).astype(int)
    rear, front = wheels(px)
    ft = feet(px, rear['bottom'])
    report.append(dict(
        frame=f['index'],
        before=dict(rear_x=f['rear']['cx'], rear_bottom=f['rear']['bottom'],
                    front_bottom=f['front']['bottom'], wheelbase=wheelbase),
        scale=round(scale, 4), shift=(dx, dy),
        after=dict(rear_x=rear['cx'], front_x=front['cx'],
                   rear_bottom=rear['bottom'], front_bottom=front['bottom']),
        feet=ft))

# A sheet to review: aligned frames side by side on the road line.
cell = canvas
review = Image.new('RGBA', (cell[0] * 4, cell[1] * 3), (238, 244, 241, 255))
for i in range(12):
    frame = Image.open(out_dir / f'nudaeng-side-draft-{i + 1:02d}.png')
    review.alpha_composite(frame, ((i % 4) * cell[0], (i // 4) * cell[1]))
line_y = round(anchor[1])
px = np.array(review)
for row in range(3):
    y = row * cell[1] + line_y
    px[y:y + 1, :, :3] = (220, 60, 60)
Image.fromarray(px).save(out_dir / 'review-sheet.png')
(out_dir / 'alignment-report.json').write_text(json.dumps(report, indent=1))
for r in report:
    a = r['after']
    print(f"{r['frame']:2d} scale {r['scale']:.3f} shift {r['shift']} | after: "
          f"rear x {a['rear_x']:.1f} front x {a['front_x']:.1f} "
          f"bottoms {a['rear_bottom']:.0f}/{a['front_bottom']:.0f} | "
          f"lowest foot {r['feet']['lowest_body']:.0f} deck top {r['feet']['deck_top']:.0f} "
          f"gap to road {r['feet']['gap_to_road']:.0f}")
