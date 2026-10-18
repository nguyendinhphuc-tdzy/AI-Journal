#!/usr/bin/env python3
"""Split "Nudaeng remind.png" (OB10) into layers the screen can place freely.

The source is a screenshot-like frame: a grey border around a flat yellow
illustration. Output, without touching the source:
- `ob10-nudaeng-balloons.png`: Nudaeng with the balloons, soft alpha;
- `ob10-remind-decor.png`: the bottom decorations (star, heart, balloon) as
  a full-width strip, so they sit at the screen's bottom behind the CTA.
The flat yellow itself is drawn by the app (#FFEFAB).

Requires Pillow, NumPy and SciPy.
Usage: python mobile/tool/build_remind_layers.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

DEIMAGE = Path(__file__).resolve().parents[1] / 'assets' / 'Deimage'
SOURCE = DEIMAGE / 'Nudaeng remind.png'
NUDAENG = DEIMAGE / 'ob10-nudaeng-balloons.png'
DECOR = DEIMAGE / 'ob10-remind-decor.png'
STRUCTURE = np.ones((3, 3), dtype=bool)
BORDER_GREY = (128, 128, 128)
BACKDROP_TOLERANCE = 22


def main():
    rgb = np.asarray(Image.open(SOURCE).convert('RGB')).astype(np.int16)
    # Drop the grey frame around the illustration.
    grey = np.abs(rgb - BORDER_GREY).max(axis=2) < 6
    rows = np.where(~grey.all(axis=1))[0]
    cols = np.where(~grey.all(axis=0))[0]
    inner = rgb[rows.min():rows.max() + 1, cols.min():cols.max() + 1]

    backdrop = np.median(inner[20:200, 20:-20].reshape(-1, 3), axis=0)
    candidate = np.abs(inner - backdrop).max(axis=2) < BACKDROP_TOLERANCE
    seeds = np.zeros(candidate.shape, dtype=bool)
    seeds[[0, -1], :] = candidate[[0, -1], :]
    seeds[:, [0, -1]] = candidate[:, [0, -1]]
    outside = ndimage.binary_propagation(
        seeds, structure=STRUCTURE, mask=candidate)

    labels, count = ndimage.label(~outside, structure=STRUCTURE)
    areas = np.bincount(labels.ravel(), minlength=count + 1)
    areas[0] = 0
    order = np.argsort(areas)[::-1]
    nudaeng = labels == order[0]
    decor = np.isin(labels, [i for i in order[1:] if areas[i] > 1000])

    # Unmatte the black outlines against the yellow: pixel = a·black +
    # (1 − a)·backdrop, so a = 1 − brightness / backdrop brightness.
    subject = nudaeng | decor
    edge = subject & ndimage.binary_dilation(~subject, structure=STRUCTURE)
    brightness = inner.mean(axis=2)
    alpha = np.where(subject, 255.0, 0.0)
    soft = edge & (brightness < backdrop.mean())
    alpha[soft] = np.clip(1 - brightness[soft] / backdrop.mean(), 0, 1) * 255
    rgba = np.dstack([inner, alpha]).astype(np.uint8)
    rgba[soft, :3] = 0

    def save(mask, target, box):
        layer = rgba.copy()
        layer[~mask, 3] = 0
        layer[layer[:, :, 3] == 0, :3] = 0
        Image.fromarray(layer).crop(box).save(target, optimize=True)
        return box

    ys, xs = np.where(nudaeng)
    box = (xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3)
    save(nudaeng, NUDAENG, box)
    feet = nudaeng[ys.max() - 14:ys.max() + 1]
    feet_x = np.where(feet.any(axis=0))[0]
    print(NUDAENG.name, 'box', box, 'size', (box[2] - box[0], box[3] - box[1]),
          'feet x', (feet_x.min() + feet_x.max()) / 2 - box[0],
          'feet y', ys.max() - box[1])

    ys, _ = np.where(decor)
    box = (0, ys.min() - 2, inner.shape[1], inner.shape[0])
    save(decor, DECOR, box)
    print(DECOR.name, 'box', box, 'size', (box[2] - box[0], box[3] - box[1]))
    print('backdrop', backdrop)


if __name__ == '__main__':
    main()
