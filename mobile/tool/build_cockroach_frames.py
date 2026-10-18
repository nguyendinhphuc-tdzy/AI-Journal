#!/usr/bin/env python3
"""Cut "Chú chó đuổi bắt gián hoạt hình.gif" into transparent PNG frames.

The source has a textured mid-grey backdrop and the cockroach is a separate
shape from Nudaeng, so `strip_nudaeng_backgrounds.py` (light backdrop, largest
shape only) does not fit. GIF transparency is 1-bit, so the output is a PNG
sequence with soft alpha, played by `FrameSequence` in the app.

Requires Pillow, NumPy and SciPy. The source GIF is never overwritten.
Usage: python mobile/tool/build_cockroach_frames.py
"""
from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageSequence
from scipy import ndimage

ASSETS = Path(__file__).resolve().parents[1] / 'assets'
SOURCE = ASSETS / 'NudaenggifDe' / 'Chú chó đuổi bắt gián hoạt hình.gif'
TARGET = ASSETS / 'Deimage' / 'nudaeng-cockroach-frame-{:02d}.png'
# The last frame split into Nudaeng and the cockroach, motion marks removed:
# the idle starts from exactly what the run ends on, then the twitching
# cockroach sprite (`ob02-cockroach-idle-*.png`) fades in over it.
REST_DOG = ASSETS / 'Deimage' / 'nudaeng-cockroach-rest-dog.png'
REST_COCKROACH = ASSETS / 'Deimage' / 'nudaeng-cockroach-rest-cockroach.png'
STRUCTURE = np.ones((3, 3), dtype=bool)

# Backdrop: neutral grey within this distance of its median value.
NEUTRAL_SPREAD = 22
BACKDROP_TOLERANCE = 30
# Detached shapes smaller than this are paper-texture specks, not art. The
# cockroach's motion marks are larger and are kept.
MIN_SHAPE = 24


def cutout(frame):
    rgba = np.array(frame.convert('RGBA'))
    rgb = rgba[:, :, :3].astype(np.int16)
    value = rgb.mean(axis=2)
    neutral = np.ptp(rgb, axis=2) <= NEUTRAL_SPREAD
    border = np.zeros(neutral.shape, dtype=bool)
    border[[0, -1], :] = border[:, [0, -1]] = True
    backdrop = float(np.median(value[border & neutral]))
    candidate = neutral & (np.abs(value - backdrop) <= BACKDROP_TOLERANCE)
    outside = ndimage.binary_propagation(
        border & candidate, structure=STRUCTURE, mask=candidate)

    subject = ~outside
    labels, count = ndimage.label(subject, structure=STRUCTURE)
    areas = np.bincount(labels.ravel(), minlength=count + 1)
    areas[0] = 0
    subject = areas[labels] >= MIN_SHAPE

    # Unmatte the anti-aliased black outline against the grey backdrop:
    # pixel = a * black + (1 - a) * backdrop.
    edge = subject & ndimage.binary_dilation(~subject, structure=STRUCTURE)
    soft = edge & neutral & (value < backdrop)
    alpha = np.where(subject, 255, 0).astype(np.float64)
    alpha[soft] = np.clip(1 - value[soft] / backdrop, 0, 1) * 255
    rgba[soft, :3] = 0
    rgba[:, :, 3] = np.round(alpha).astype(np.uint8)
    rgba[rgba[:, :, 3] == 0, :3] = 0
    return Image.fromarray(rgba), backdrop


def shape(frame, rank):
    """Only the [rank]-th largest shape (0 = largest) of [frame]."""
    rgba = np.array(frame)
    labels, count = ndimage.label(rgba[:, :, 3] > 0, structure=STRUCTURE)
    areas = np.bincount(labels.ravel(), minlength=count + 1)
    areas[0] = 0
    rgba[labels != np.argsort(areas)[::-1][rank]] = 0
    return Image.fromarray(rgba)


def main():
    with Image.open(SOURCE) as gif:
        durations, frames, backdrops = [], [], []
        for frame in ImageSequence.Iterator(gif):
            durations.append(frame.info.get('duration', 100))
            image, backdrop = cutout(frame)
            frames.append(image)
            backdrops.append(backdrop)
    # One shared crop for all frames: no position or scale jitter.
    boxes = [frame.getbbox() for frame in frames]
    crop = (max(0, min(b[0] for b in boxes) - 2),
            max(0, min(b[1] for b in boxes) - 2),
            min(frames[0].width, max(b[2] for b in boxes) + 2),
            min(frames[0].height, max(b[3] for b in boxes) + 2))
    outputs = []
    for index, frame in enumerate(frames, start=1):
        target = Path(str(TARGET).format(index))
        frame.crop(crop).save(target, optimize=True)
        outputs.append(target.name)
    last = frames[-1].crop(crop)
    shape(last, 0).save(REST_DOG, optimize=True)
    shape(last, 1).save(REST_COCKROACH, optimize=True)
    outputs += [REST_DOG.name, REST_COCKROACH.name]
    for name in outputs:
        alpha = np.asarray(Image.open(TARGET.parent / name))[:, :, 3]
        assert (alpha == 0).any() and (alpha == 255).any(), name
    print(json.dumps({
        'source': str(SOURCE.relative_to(ASSETS)),
        'frames': outputs,
        'durations_ms': durations,
        'crop': crop,
        'size': [crop[2] - crop[0], crop[3] - crop[1]],
        'backdrop_value': [round(b) for b in backdrops],
    }, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
