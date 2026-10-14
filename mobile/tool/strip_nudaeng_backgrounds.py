#!/usr/bin/env python3
"""Build transparent siblings of the supplied Nudaeng art, without redrawing.

Requires Pillow, NumPy and SciPy. Original files are never overwritten.
Usage: python mobile/tool/strip_nudaeng_backgrounds.py
"""
from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageSequence
from scipy import ndimage

ASSETS = Path(__file__).resolve().parents[1] / 'assets'
STRUCTURE = np.ones((3, 3), dtype=bool)


def cutout(frame):
    rgba = np.array(frame.convert('RGBA'))
    rgb = rgba[:, :, :3].astype(np.int16)
    light_neutral = (rgb.min(axis=2) >= 175) & (np.ptp(rgb, axis=2) <= 24)
    candidate = light_neutral | (rgba[:, :, 3] == 0)
    seeds = np.zeros(candidate.shape, dtype=bool)
    seeds[[0, -1], :] = candidate[[0, -1], :]
    seeds[:, [0, -1]] = candidate[:, [0, -1]]
    outside = ndimage.binary_propagation(seeds, structure=STRUCTURE, mask=candidate)
    subject = ~outside & (rgba[:, :, 3] > 0)

    # Detached slogans, sparkles, side tables and other background decorations
    # are not part of the character. Keep the main connected silhouette.
    labels, count = ndimage.label(subject, structure=STRUCTURE)
    if not count:
        raise ValueError('No foreground found')
    areas = np.bincount(labels.ravel())
    areas[0] = 0
    subject = labels == areas.argmax()
    rgba[:, :, 3] = np.where(subject, rgba[:, :, 3], 0)

    # Unmatte the neutral anti-aliased outline bordering the removed backdrop.
    # Interior whites (glasses, paper, sign) remain opaque and unchanged.
    border = subject & ndimage.binary_dilation(~subject, structure=STRUCTURE)
    edge = border & (np.ptp(rgb, axis=2) <= 24) & (rgb.min(axis=2) > 35)
    backdrop = np.median(rgb[outside], axis=0).mean() if outside.any() else 255
    alpha = np.clip(1 - rgb.mean(axis=2) / max(backdrop, 1), 0, 1)
    rgba[edge, :3] = 0
    rgba[edge, 3] = np.round(alpha[edge] * 255).astype(np.uint8)
    rgba[rgba[:, :, 3] == 0, :3] = 0
    return Image.fromarray(rgba)


def save_gif(frames, target, durations, loop):
    # Reserve palette slot 255 for transparency; retain full-frame disposal so
    # moving outlines cannot leave a trail on transparent parts of later frames.
    palette_frames = []
    for frame in frames:
        alpha = np.asarray(frame.getchannel('A'))
        rgb = frame.convert('RGB')
        paletted = rgb.quantize(colors=255, method=Image.Quantize.MEDIANCUT,
                                dither=Image.Dither.NONE)
        pixels = np.array(paletted)
        pixels[alpha < 128] = 255
        result = Image.fromarray(pixels).convert('P')
        palette = paletted.getpalette()[:765]
        result.putpalette(palette + [0] * (768 - len(palette)))
        result.info['transparency'] = 255
        palette_frames.append(result)
    options = {} if loop is None else {'loop': loop}
    palette_frames[0].save(target, save_all=True,
        append_images=palette_frames[1:], duration=durations,
        transparency=255, disposal=2, optimize=False, background=255, **options)


def process(source):
    with Image.open(source) as original:
        loop = original.info.get('loop', 0)
        durations, frames = [], []
        for frame in ImageSequence.Iterator(original):
            durations.append(frame.info.get('duration', 100))
            frames.append(cutout(frame))
    # All animation frames share one crop: no position or scale jitter.
    bounds = [frame.getbbox() for frame in frames]
    left = max(0, min(b[0] for b in bounds) - 2)
    top = max(0, min(b[1] for b in bounds) - 2)
    right = min(frames[0].width, max(b[2] for b in bounds) + 2)
    bottom = min(frames[0].height, max(b[3] for b in bounds) + 2)
    frames = [frame.crop((left, top, right, bottom)) for frame in frames]
    animated = source.suffix.lower() == '.gif'
    target = source.with_name(source.stem + '-transparent' + ('.gif' if animated else '.png'))
    if animated:
        save_gif(frames, target, durations, loop)
    else:
        frames[0].save(target)
    with Image.open(target) as output:
        if output.n_frames != len(frames):
            raise AssertionError(f'Frame count changed: {source.name}')
        if animated:
            actual = [f.info.get('duration', 100) for f in ImageSequence.Iterator(output)]
            assert actual == durations, (source.name, actual, durations)
        for frame in ImageSequence.Iterator(output):
            alpha = np.asarray(frame.convert('RGBA'))[:, :, 3]
            assert (alpha == 0).any(), f'No transparency: {target.name}'
            assert (alpha == 255).any(), f'Empty character: {target.name}'
    return {'source': str(source.relative_to(ASSETS)),
            'output': str(target.relative_to(ASSETS)),
            'frames': len(frames), 'duration_ms': sum(durations) if animated else None,
            'crop': [left, top, right, bottom], 'size': list(frames[0].size)}


if __name__ == '__main__':
    sources = sorted([*ASSETS.glob('Deimage/*.jpg'), *ASSETS.glob('NudaenggifDe/*.gif')])
    report = [process(source) for source in sources if '-transparent' not in source.stem]
    print(json.dumps(report, ensure_ascii=False, indent=2))
