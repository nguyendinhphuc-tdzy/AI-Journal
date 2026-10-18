#!/usr/bin/env python3
"""Cut Nudaeng and the yarn out of "Nudaeng OB11.jpg" (OB11).

The source is a flat yellow illustration with a copyright line in the
corner. Output, without touching the source: `ob11-nudaeng-yarn.png`,
Nudaeng in the half-knitted jumper with the loose thread and the ball of
yarn, soft alpha, cropped tight. The app draws its own background, so the
yellow goes.

Requires Pillow, NumPy and SciPy.
Usage: python mobile/tool/build_ob11_layer.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

TOOL = Path(__file__).resolve().parent
SOURCE = TOOL / 'artwork_sources' / 'Nudaeng OB11.jpg'
TARGET = TOOL.parent / 'assets' / 'Deimage' / 'ob11-nudaeng-yarn.png'
STRUCTURE = np.ones((3, 3), dtype=bool)
BACKDROP_TOLERANCE = 26
# Parts smaller than this are JPEG specks or letters of the copyright line.
MIN_PART = 400


def main():
    rgb = np.asarray(Image.open(SOURCE).convert('RGB')).astype(np.int16)
    backdrop = np.median(rgb[10:120, 10:-10].reshape(-1, 3), axis=0)
    candidate = np.abs(rgb - backdrop).max(axis=2) < BACKDROP_TOLERANCE
    seeds = np.zeros(candidate.shape, dtype=bool)
    seeds[[0, -1], :] = candidate[[0, -1], :]
    seeds[:, [0, -1]] = candidate[:, [0, -1]]
    outside = ndimage.binary_propagation(
        seeds, structure=STRUCTURE, mask=candidate)

    labels, count = ndimage.label(~outside, structure=STRUCTURE)
    areas = np.bincount(labels.ravel(), minlength=count + 1)
    areas[0] = 0
    main_part = areas.argmax()
    ys, xs = np.where(labels == main_part)
    # Keep the figure and anything near it (thread, yarn); drop the
    # copyright line in the far corner.
    near = (ys.min() - 40, ys.max() + 40, xs.min() - 60, xs.max() + 260)
    keep = []
    for i in range(1, count + 1):
        if areas[i] < MIN_PART and i != main_part:
            continue
        py, px = np.where(labels == i)
        if (py.min() >= near[0] and py.max() <= near[1]
                and px.min() >= near[2] and px.max() <= near[3]):
            keep.append(i)
    subject = np.isin(labels, keep)

    # Unmatte the black outlines against the yellow: pixel = a·black +
    # (1 − a)·backdrop, so a = 1 − brightness / backdrop brightness.
    edge = subject & ndimage.binary_dilation(~subject, structure=STRUCTURE)
    brightness = rgb.mean(axis=2)
    alpha = np.where(subject, 255.0, 0.0)
    soft = edge & (brightness < backdrop.mean())
    alpha[soft] = np.clip(1 - brightness[soft] / backdrop.mean(), 0, 1) * 255
    rgba = np.dstack([rgb, alpha]).astype(np.uint8)
    rgba[soft, :3] = 0
    rgba[rgba[:, :, 3] == 0, :3] = 0

    ys, xs = np.where(subject)
    box = (xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3)
    Image.fromarray(rgba).crop(box).save(TARGET, optimize=True)
    print(TARGET.name, 'box', box, 'size', (box[2] - box[0], box[3] - box[1]),
          'parts', [int(areas[i]) for i in keep], 'backdrop', backdrop)


if __name__ == '__main__':
    main()
