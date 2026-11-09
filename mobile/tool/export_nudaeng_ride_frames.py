# Usage (Python with Pillow and NumPy):
#   python tool/export_nudaeng_ride_frames.py <aligned-dir> assets/images
# (straight into assets/images: pubspec lists that folder, not its subfolders)
"""Export the aligned side poses for the app.

All frames share one canvas: the union of their opaque pixels plus a small
margin, scaled to WIDTH px. The wheel anchors are measured on the result
and printed for `HomeSceneHero` (rear and front hub x, road y, canvas size).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
dst.mkdir(parents=True, exist_ok=True)
WIDTH = 480
MARGIN = 6
frames = [Image.open(src / f'nudaeng-side-draft-{i:02d}.png').convert('RGBA')
          for i in range(1, 13)]
alpha = np.zeros(frames[0].size[::-1], bool)
for f in frames:
    alpha |= np.array(f)[..., 3] > 8
ys, xs = np.nonzero(alpha)
box = (xs.min() - MARGIN, ys.min() - MARGIN, xs.max() + 1 + MARGIN,
       ys.max() + 1 + MARGIN)
scale = WIDTH / (box[2] - box[0])
size = (WIDTH, round((box[3] - box[1]) * scale))
for i, f in enumerate(frames, 1):
    # Flat cartoon colours: a 256-colour palette keeps the drawing and
    # cuts the size several times.
    f.crop(box).resize(size, Image.LANCZOS).quantize(
        256, method=Image.Quantize.FASTOCTREE).save(
            dst / f'nudaeng-ride-{i:02d}.png', optimize=True)

# Anchors, measured on frame 1 of the export.
px = np.array(Image.open(dst / 'nudaeng-ride-01.png').convert('RGBA')).astype(int)
hub = np.all((px[..., :3] >= (175, 190, 210)) & (px[..., :3] <= (215, 230, 250)),
             axis=-1) & (px[..., 3] > 200)
tyre = np.all((px[..., :3] >= (40, 40, 40)) & (px[..., :3] <= (125, 125, 135)),
              axis=-1) & (px[..., 3] > 200)
floor = np.nonzero(tyre)[0].max()
hub[: floor - round(60 * scale)] = False
hy, hx = np.nonzero(hub)
order = np.unique(hx)
split = order[np.argmax(np.diff(order))] + 1
print(f'canvas {size[0]} x {size[1]}')
print(f'rear hub x {hx[hx < split].mean():.1f}, front hub x {hx[hx >= split].mean():.1f}')
print(f'road y {floor + 1}')
