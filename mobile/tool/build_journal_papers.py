# Usage (Python with OpenCV and NumPy):
#   python tool/build_journal_papers.py ../output/imagegen/journal-paper-v1 assets/images
"""Export the journal's paper backgrounds from the imagegen PNGs.

- paper-ruled.png: its printed ruling and margin are removed, leaving the
  clean warm white sheet. The app draws the lines itself, on the text's own
  line height (a printed ruling only fits one screen and one text size).
  Each line or margin band is replaced by the paper right next to it, so
  the grain carries on.
- paper-do-ivory.png, paper-aged.png: unchanged.

All three are written as JPEG (the PNGs are about 2.5 MB each).
"""
import sys
from pathlib import Path

import cv2
import numpy as np

src, out = Path(sys.argv[1]), Path(sys.argv[2])


def patch_bands(image, bands, axis):
    """Cover each run of True in [bands] (rows or columns) with the paper
    just after it (or before, at the far end)."""
    size = len(bands)
    i = 0
    while i < size:
        if not bands[i]:
            i += 1
            continue
        end = i
        while end < size and bands[end]:
            end += 1
        n = end - i
        start = end + 3 if end + 3 + n <= size else i - 3 - n
        if axis == 0:
            image[i:end] = image[start:start + n]
        else:
            image[:, i:end] = image[:, start:start + n]
        i = end


def widen(marks, pad):
    bands = np.zeros(len(marks), bool)
    for i in np.where(marks)[0]:
        bands[max(0, i - pad):i + pad + 1] = True
    return bands


def smooth(profile):
    return cv2.GaussianBlur(profile.reshape(-1, 1), (1, 31), 8).ravel()


ruled = cv2.imread(str(src / 'paper-ruled.png'))
h, w = ruled.shape[:2]
# Ruling: rows darker than the paper around them (the margin left out).
grey = cv2.cvtColor(ruled, cv2.COLOR_BGR2GRAY).astype(np.float32)
rows = grey[:, 150:w - 50].mean(1)
patch_bands(ruled, widen(rows < smooth(rows) - 3, 2), axis=0)
# Margin: columns redder than the paper around them.
red = cv2.cvtColor(ruled, cv2.COLOR_BGR2LAB)[..., 1].astype(np.float32).mean(0)
patch_bands(ruled, widen(red > smooth(red) + 1.5, 2), axis=1)

papers = {
    'journal-paper-ruled.jpg': ruled,
    'journal-paper-do.jpg': cv2.imread(str(src / 'paper-do-ivory.png')),
    'journal-paper-aged.jpg': cv2.imread(str(src / 'paper-aged.png')),
}
for name, image in papers.items():
    cv2.imwrite(str(out / name), image, [cv2.IMWRITE_JPEG_QUALITY, 86])
    print(out / name, image.shape[1], image.shape[0])
