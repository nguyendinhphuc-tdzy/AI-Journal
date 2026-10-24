#!/usr/bin/env python3
"""Build the Album (A01) artwork layers, without touching the sources.

- `album-peek-frame-01…08.png`: "Chó hoạt hình quay đầu đáng yêu.gif"
  (8 × 200 ms) with its flat grey backdrop removed, one shared crop so the
  head never jumps between frames. The body is cut flat at the bottom in the
  source: the app hides that edge behind the new album's cover.
- `album-bg-nudaeng.png`: the floating Nudaeng of "Background 2.png" without
  the slate frame and the cyan square; the app paints the sky itself in
  theme colours.
- `album-empty-nudaeng.png`: first frame of "Chú chó ôm sách đầy yêu
  thương-transparent.gif", cropped, for the empty library.
- `album-key-frame-01…04.png`: A04's Nudaeng putting the key away, from
  the 1254 px originals in `tool/artwork_sources/album-key/` (see
  `assets/Deimage/album-key-assets.md`), scaled to 384 px for a 96 dp slot.
- `album-start-frame-01…05.png`: " Nudaeng long lanh.gif" (A05 hero),
  kept whole (Nudaeng and the big face behind it share one beige, so they are
  not cut apart): the app frames it as a photo. 240 px source, upscaled to
  480 px so it is not blurrier than it must be at 168 dp.
- `album-write-frame-01…06.png`: ND09 for the memory editor (A06): the
  supplied "Nudaeng writing" pose, unchanged, cropped to Nudaeng and the
  open notebook, with a few ink strokes appearing on the left page up to the
  pen tip. Only the strokes are added; nothing of Nudaeng is redrawn.
- `album-saved-frame-01…09.png`: ND11 for the memory detail (A08), the 9
  frames (9 × 180 ms ≈ 1.6 s) of "Chú chó ôm sách đầy yêu
  thương-transparent.gif" (Nudaeng hugging a book) on one shared crop.
- `album-theme-<id>.png`: the album theme poses (A02), from
  `tool/artwork_sources/album-themes/<id>.jpg`, white backdrop and the
  copyright line removed, at most 360 px.

Requires Pillow, NumPy and SciPy.
Usage: python mobile/tool/build_album_layers.py
"""
from pathlib import Path
import glob
import unicodedata

import numpy as np
from PIL import Image, ImageSequence
from scipy import ndimage

ASSETS = Path(__file__).resolve().parents[1] / 'assets'
THEMES = Path(__file__).resolve().parent / 'artwork_sources' / 'album-themes'
KEYS = Path(__file__).resolve().parent / 'artwork_sources' / 'album-key'
OUT = ASSETS / 'Deimage'
STRUCTURE = np.ones((3, 3), dtype=bool)


def find(suffix):
    """Asset path by its NFC name (macOS may store names decomposed)."""
    for path in glob.glob(str(ASSETS / '**' / '*'), recursive=True):
        if unicodedata.normalize('NFC', path).endswith(suffix):
            return Path(path)
    raise FileNotFoundError(suffix)


def cut(rgb, backdrop_mask):
    """Soft alpha for line art: everything reachable from the border through
    [backdrop_mask] is backdrop; outline pixels on the edge are unmatted
    (pixel = a·ink + (1 − a)·backdrop)."""
    seeds = np.zeros(backdrop_mask.shape, dtype=bool)
    seeds[[0, -1], :] = backdrop_mask[[0, -1], :]
    seeds[:, [0, -1]] = backdrop_mask[:, [0, -1]]
    outside = ndimage.binary_propagation(
        seeds, structure=STRUCTURE, mask=backdrop_mask)
    subject = ~outside
    backdrop = np.median(rgb[outside], axis=0).mean() if outside.any() else 255
    edge = subject & ndimage.binary_dilation(outside, structure=STRUCTURE)
    brightness = rgb.mean(axis=2)
    alpha = np.where(subject, 255.0, 0.0)
    soft = edge & (brightness < backdrop)
    alpha[soft] = np.clip(1 - brightness[soft] / backdrop, 0, 1) * 255
    rgba = np.dstack([rgb, alpha]).astype(np.uint8)
    rgba[soft, :3] = 0
    rgba[rgba[:, :, 3] == 0, :3] = 0
    return rgba


def bbox(alpha, pad=2):
    ys, xs = np.where(alpha > 0)
    return (max(xs.min() - pad, 0), max(ys.min() - pad, 0),
            min(xs.max() + pad + 1, alpha.shape[1]),
            min(ys.max() + pad + 1, alpha.shape[0]))


def peek_frames():
    gif = Image.open(find('Chó hoạt hình quay đầu đáng yêu.gif'))
    layers = []
    for frame in ImageSequence.Iterator(gif):
        rgb = np.asarray(frame.convert('RGB')).astype(np.int16)
        # Light, neutral grey backdrop; the fur is warm, so never matches.
        neutral = (rgb.min(axis=2) >= 170) & (np.ptp(rgb, axis=2) <= 18)
        layers.append(cut(rgb, neutral))
    union = np.zeros(layers[0].shape[:2], dtype=np.uint8)
    for layer in layers:
        union = np.maximum(union, layer[:, :, 3])
    box = bbox(union)
    for i, layer in enumerate(layers, 1):
        target = OUT / f'album-peek-frame-{i:02d}.png'
        Image.fromarray(layer).crop(box).save(target, optimize=True)
    print('peek frames', len(layers), 'box', box,
          'size', (box[2] - box[0], box[3] - box[1]))


def background_nudaeng():
    src = np.asarray(Image.open(find('Deimage/Background 2.png'))
                     .convert('RGB')).astype(np.int16)
    # Inside the slate frame: the cyan square.
    slate = np.abs(src - src[5, 5]).max(axis=2) < 12
    rows = np.where(~slate.all(axis=1))[0]
    cols = np.where(~slate.all(axis=0))[0]
    square = src[rows.min():rows.max() + 1, cols.min():cols.max() + 1]
    cyan = np.median(square[:40, :40].reshape(-1, 3), axis=0)
    backdrop = np.abs(square - cyan).max(axis=2) < 24
    rgba = cut(square, backdrop)
    box = bbox(rgba[:, :, 3], pad=4)
    target = OUT / 'album-bg-nudaeng.png'
    Image.fromarray(rgba).crop(box).save(target, optimize=True)
    print('background nudaeng box', box, 'size',
          (box[2] - box[0], box[3] - box[1]), 'cyan', cyan)


def empty_nudaeng():
    gif = Image.open(find('Chú chó ôm sách đầy yêu thương-transparent.gif'))
    frame = gif.convert('RGBA')
    rgba = np.asarray(frame)
    box = bbox(rgba[:, :, 3])
    target = OUT / 'album-empty-nudaeng.png'
    frame.crop(box).save(target, optimize=True)
    print('empty nudaeng box', box, 'size', (box[2] - box[0], box[3] - box[1]))


def theme_poses():
    for source in sorted(THEMES.glob('*.jpg')):
        rgb = np.asarray(Image.open(source).convert('RGB')).astype(np.int16)
        light = (rgb.min(axis=2) >= 205) & (np.ptp(rgb, axis=2) <= 28)
        rgba = cut(rgb, light)
        # Keep the figure and what belongs to it (a heart, a rose, a cup);
        # drop specks and the letters of the copyright line.
        labels, count = ndimage.label(rgba[:, :, 3] > 0, structure=STRUCTURE)
        areas = np.bincount(labels.ravel(), minlength=count + 1)
        areas[0] = 0
        keep = np.isin(labels, np.where(areas >= areas.max() * .02)[0])
        rgba[~keep] = 0
        image = Image.fromarray(rgba).crop(bbox(rgba[:, :, 3]))
        image.thumbnail((360, 360), Image.LANCZOS)
        target = OUT / f'album-theme-{source.stem}.png'
        image.save(target, optimize=True)
        print(target.name, image.size)


def key_frames():
    for source in sorted(KEYS.glob('album-key-frame-*.png')):
        image = Image.open(source).convert('RGBA')
        # Same square canvas for every frame, so the pose never shifts.
        image = image.resize((384, 384), Image.LANCZOS)
        image.save(OUT / source.name, optimize=True)
        print(source.name, image.size)


def start_frames():
    gif = Image.open(find('Nudaeng long lanh.gif'))
    for i, frame in enumerate(ImageSequence.Iterator(gif), 1):
        image = frame.convert('RGB').resize((480, 480), Image.LANCZOS)
        target = OUT / f'album-start-frame-{i:02d}.png'
        image.save(target, optimize=True)
        print(target.name, image.size)


def write_frames():
    from PIL import ImageDraw
    pose = Image.open(find('Nudaeng writing-transparent.png')).convert('RGBA')
    # Strokes on the notebook's left page, ending at the pen tip (252, 317),
    # following the page's slight slope; drawn at 4x for smooth edges.
    lines = [((196, 317), (248, 313)), ((200, 323), (240, 320))]
    # (line, share drawn) per frame: none, then line 1, then line 2.
    plan = [[], [(0, .35)], [(0, .75)], [(0, 1)], [(0, 1), (1, .5)],
            [(0, 1), (1, 1)]]
    scale = 4
    crop = (106, 14, 518, 372)
    for i, strokes in enumerate(plan, 1):
        big = pose.resize((pose.width * scale, pose.height * scale),
                          Image.LANCZOS)
        draw = ImageDraw.Draw(big)
        for index, share in strokes:
            (x0, y0), (x1, y1) = lines[index]
            steps = 40
            points = []
            for k in range(int(steps * share) + 1):
                t = k / steps
                x = x0 + (x1 - x0) * t
                # A small hand-written wave.
                y = y0 + (y1 - y0) * t + 1.1 * np.sin(t * 9 * np.pi)
                points.append((x * scale, y * scale))
            if len(points) > 1:
                draw.line(points, fill=(52, 52, 48, 255), width=int(2.6 * scale),
                          joint='curve')
        frame = big.resize(pose.size, Image.LANCZOS).crop(crop)
        frame.thumbnail((360, 360), Image.LANCZOS)
        target = OUT / f'album-write-frame-{i:02d}.png'
        frame.save(target, optimize=True)
        print(target.name, frame.size)


def saved_frames():
    gif = Image.open(find('Chú chó ôm sách đầy yêu thương-transparent.gif'))
    frames = [frame.convert('RGBA') for frame in ImageSequence.Iterator(gif)]
    union = np.zeros(np.asarray(frames[0]).shape[:2], dtype=np.uint8)
    for frame in frames:
        union = np.maximum(union, np.asarray(frame)[:, :, 3])
    box = bbox(union)
    for i, frame in enumerate(frames, 1):
        target = OUT / f'album-saved-frame-{i:02d}.png'
        frame.crop(box).save(target, optimize=True)
    print('saved frames', len(frames), 'box', box,
          'durations', [f.info.get('duration') for f in ImageSequence.Iterator(gif)])


if __name__ == '__main__':
    peek_frames()
    background_nudaeng()
    empty_nudaeng()
    theme_poses()
    key_frames()
    start_frames()
    write_frames()
    saved_frames()
