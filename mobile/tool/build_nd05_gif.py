#!/usr/bin/env python3
"""Encode the approved new ND05 sprite sheet as a transparent 1.2 second GIF.

The built-in imagegen tool created the sheet using Study.png as the character
reference. Original supplied artwork is not modified. Requires Pillow + NumPy.
"""
from pathlib import Path

from PIL import Image, ImageSequence
from strip_nudaeng_backgrounds import save_gif

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'artwork_sources/nd05-check-notebook-sheet.png'
TARGET = ROOT.parent / 'assets/NudaenggifDe/ND05-check-notebook-transparent.gif'


def main():
    sheet = Image.open(SOURCE).convert('RGBA')
    frames = []
    for index in range(12):
        col, row = index % 4, index // 4
        tile = sheet.crop((round(col * sheet.width / 4),
                           round(row * sheet.height / 3),
                           round((col + 1) * sheet.width / 4),
                           round((row + 1) * sheet.height / 3)))
        # Use the opaque silhouette for alignment, ignoring faint alpha fringes.
        bounds = tile.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
        subject = tile.crop(bounds)
        frame = Image.new('RGBA', (320, 400))
        # Keep the same pixel scale in all frames; register the feet to a baseline.
        frame.alpha_composite(subject, ((320 - subject.width) // 2, 380 - subject.height))
        frames.append(frame)
    # No loop extension: plays once in ordinary image viewers too.
    save_gif(frames, TARGET, [100] * 12, loop=None)
    with Image.open(TARGET) as gif:
        assert gif.n_frames == 12
        assert sum(f.info['duration'] for f in ImageSequence.Iterator(gif)) == 1200
        assert 'loop' not in gif.info
        for frame in ImageSequence.Iterator(gif):
            assert frame.convert('RGBA').getchannel('A').getextrema() == (0, 255)
    print(TARGET)


if __name__ == '__main__':
    main()
