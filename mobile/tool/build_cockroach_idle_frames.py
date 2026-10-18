#!/usr/bin/env python3
"""Build three idle sprites from the GIF's own cockroach, without redrawing.

Requires the same Pillow, NumPy and SciPy environment as
build_cockroach_frames.py. Only the three ob02-cockroach-idle PNGs are written.
The full 306x319 run-frame canvas is retained for identical placement.
"""
import json

import numpy as np
from PIL import Image, ImageSequence
from scipy import ndimage

from build_cockroach_frames import ASSETS, SOURCE, cutout, shape

# In the shared run-frame crop, only antenna strokes occupy rows above 249.
# Wing outlines start below this boundary. Anchor the warp here so every
# body/face/wing/leg pixel stays unchanged, including the antenna roots.
ANTENNA_ANCHOR_Y = 249
ANTENNA_TOP_Y = 232
TIP_DISPLACEMENT = 2.0


def sway_antennae(source, direction):
    result = source.copy()
    height = ANTENNA_ANCHOR_Y
    layer = source[:height].astype(np.float64) / 255
    # Interpolate premultiplied RGBA so transparent edges do not acquire halos.
    layer[:, :, :3] *= layer[:, :, 3:4]
    yy, xx = np.mgrid[:height, :source.shape[1]].astype(np.float64)
    weight = np.clip((height - 1 - yy) / (height - 1 - ANTENNA_TOP_Y), 0, 1)
    sample_x = xx - direction * TIP_DISPLACEMENT * weight**2
    warped = np.stack([
        ndimage.map_coordinates(layer[:, :, c], [yy, sample_x],
                                order=1, mode='constant', cval=0)
        for c in range(4)
    ], axis=-1)
    alpha = warped[:, :, 3:4]
    np.divide(warped[:, :, :3], alpha, out=warped[:, :, :3], where=alpha > 0)
    result[:height] = np.round(np.clip(warped, 0, 1) * 255).astype(np.uint8)
    result[result[:, :, 3] == 0] = 0
    return result


def main():
    with Image.open(SOURCE) as gif:
        frames = [cutout(frame)[0] for frame in ImageSequence.Iterator(gif)]
    boxes = [frame.getbbox() for frame in frames]
    crop = (max(0, min(b[0] for b in boxes) - 2),
            max(0, min(b[1] for b in boxes) - 2),
            min(frames[0].width, max(b[2] for b in boxes) + 2),
            min(frames[0].height, max(b[3] for b in boxes) + 2))
    # The mask is intentionally tied to this supplied GIF, not arbitrary art.
    assert crop == (3, 55, 309, 374), 'Source changed; review antenna mask'
    original = np.array(shape(frames[-1].crop(crop), 1))
    rest = np.array(Image.open(ASSETS / 'Deimage' /
                              'nudaeng-cockroach-rest-cockroach.png'))
    assert np.array_equal(original, rest), 'Run/idle source layers differ'
    poses = [original, sway_antennae(original, -1), sway_antennae(original, 1)]
    outputs = []
    for index, pose in enumerate(poses, 1):
        assert np.array_equal(pose[ANTENNA_ANCHOR_Y:],
                              original[ANTENNA_ANCHOR_Y:])
        assert (pose[:, :, 3] == 0).any() and (pose[:, :, 3] == 255).any()
        if index > 1:
            assert not np.array_equal(pose[:ANTENNA_ANCHOR_Y],
                                      original[:ANTENNA_ANCHOR_Y])
        path = ASSETS / 'Deimage' / f'ob02-cockroach-idle-{index:02d}.png'
        Image.fromarray(pose).save(path, optimize=True)
        assert np.array_equal(np.array(Image.open(path)), pose)
        outputs.append(path.name)
    print(json.dumps({'files': outputs, 'size': [306, 319],
                      'source_frame': 12, 'crop': crop,
                      'unchanged_body_from_y': ANTENNA_ANCHOR_Y,
                      'max_antenna_displacement_px': TIP_DISPLACEMENT,
                      'validation': 'neutral matches GIF cutout; body unchanged'},
                     indent=2))


if __name__ == '__main__':
    main()
