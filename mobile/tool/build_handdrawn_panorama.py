# Usage (Python with OpenCV and NumPy):
#   python tool/build_handdrawn_panorama.py \
#     assets/images/nudaeng-vietnam-panorama-v2.png \
#     assets/images/nudaeng-vietnam-panorama-v3.jpg
"""Repaint the Home street panorama as a hand-drawn picture.

The street, its shops and every edge stay where they are (the snow overlay
and the loop seam are drawn for this layout); only the rendering changes:

- colours flattened into soft gouache patches, slightly muted toward the
  app's mint, never darker than ink on paper;
- pigment pooling at the patch edges, as in watercolour;
- brush strokes following the shapes: long horizontal washes in the sky,
  short strokes elsewhere, along each patch's main direction;
- broken, wobbly ink lines like Nudaeng's outline;
- paper grain and fibres over all of it;
- the top rows fade into the flat sky colour Home fills above the panorama
  (`HomeSceneHero.sky`, #AFDED8), so the two meet without a line.

Random textures use a fixed seed: the output is the same on every run.
"""
import sys

import cv2
import numpy as np

src, out = sys.argv[1], sys.argv[2]
rng = np.random.default_rng(7)

image = cv2.imread(src, cv2.IMREAD_COLOR)
h, w = image.shape[:2]
SKY = np.array([0xD8, 0xDE, 0xAF], np.float32)  # #AFDED8 as BGR


def noise(scale, blur):
    """Smooth noise in about −1…1, features about [scale] px wide."""
    small = rng.standard_normal((h // scale + 2, w // scale + 2)).astype(np.float32)
    if blur:
        small = cv2.GaussianBlur(small, (0, 0), blur)
    big = cv2.resize(small, (w, h), interpolation=cv2.INTER_CUBIC)
    return big / (np.abs(big).max() + 1e-6)


def streaks(length, angle, blur=0):
    """Grain smeared along [angle] degrees: one brush's bristle marks."""
    grain = rng.standard_normal((h, w)).astype(np.float32)
    if blur:
        grain = cv2.GaussianBlur(grain, (0, 0), blur)
    kernel = np.zeros((length, length), np.float32)
    kernel[length // 2, :] = 1
    rot = cv2.getRotationMatrix2D((length / 2 - .5, length / 2 - .5), angle, 1)
    kernel = cv2.warpAffine(kernel, rot, (length, length))
    kernel /= kernel.sum()
    marks = cv2.filter2D(grain, -1, kernel)
    return marks / (np.abs(marks).max() + 1e-6)


# 1. Wobble: everything shifts a pixel or two, as if traced by hand.
dx = noise(40, 1) * 1.6
dy = noise(40, 1) * 1.6
gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
wobbled = cv2.remap(image, gx + dx, gy + dy, cv2.INTER_LINEAR,
                    borderMode=cv2.BORDER_REFLECT)

# 2. Gouache patches: flat areas of colour, edges kept.
flat = cv2.pyrMeanShiftFiltering(wobbled, sp=9, sr=30)
flat = cv2.edgePreservingFilter(flat, flags=cv2.RECURS_FILTER,
                                sigma_s=30, sigma_r=.25)

# 3. Palette: a little less vivid, nudged to mint, shadows lifted to ink.
lab = cv2.cvtColor(flat, cv2.COLOR_BGR2LAB).astype(np.float32)
lab[..., 0] = 26 + lab[..., 0] * .88
lab[..., 1] = 128 + (lab[..., 1] - 128) * .82 - 2.5
lab[..., 2] = 128 + (lab[..., 2] - 128) * .84 - 1.5
paint = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8),
                     cv2.COLOR_LAB2BGR).astype(np.float32)

# 4. Pigment pools where one patch meets the next.
grey = cv2.cvtColor(flat, cv2.COLOR_BGR2GRAY)
pool = cv2.morphologyEx(grey, cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8))
pool = cv2.GaussianBlur(pool.astype(np.float32), (0, 0), 1.2) / 255
paint *= (1 - np.clip(pool * 1.6, 0, .16))[..., None]

# 5. Brush strokes along the shapes; long washes where there is no shape.
sobel_x = cv2.Sobel(grey.astype(np.float32), cv2.CV_32F, 1, 0, ksize=5)
sobel_y = cv2.Sobel(grey.astype(np.float32), cv2.CV_32F, 0, 1, ksize=5)
jxx = cv2.GaussianBlur(sobel_x * sobel_x, (0, 0), 9)
jyy = cv2.GaussianBlur(sobel_y * sobel_y, (0, 0), 9)
energy = jxx + jyy
# Vertical edges (strong x gradient) get vertical strokes.
vertical = np.clip(jxx / (energy + 1e-3) - .5, 0, .5) * 2
shaped = np.clip(energy / (np.percentile(energy, 70) + 1e-3), 0, 1)
across = streaks(13, 0)
down = streaks(11, 90)
# Broad, slightly slanted strokes of a wide wet brush.
wash = streaks(45, -7, 2.2) * .5 + streaks(35, 5, 2.2) * .5
strokes = shaped * (vertical * down + (1 - vertical) * across) + (1 - shaped) * wash
paint *= (1 + strokes * np.where(shaped > .5, .09, .07))[..., None]

# Watercolour washes: uneven pigment, each pool with a darker rim where
# it dried (strongest on flat areas: sky, road, walls).
pools = noise(90, 1.2) * .6 + noise(35, 1) * .4
rims = np.zeros((h, w), np.float32)
for level in (-.35, -.1, .15, .4):
    edge = cv2.morphologyEx((pools > level).astype(np.uint8),
                            cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8))
    rims += cv2.GaussianBlur(edge.astype(np.float32), (0, 0), 1.4)
flatness = 1 - shaped * .6
paint *= (1 + (pools * .05 - np.clip(rims, 0, 1) * .045) * flatness)[..., None]

# 6. Ink: broken, slightly wobbly lines, dark teal like Nudaeng's outline.
soft = cv2.GaussianBlur(cv2.cvtColor(wobbled, cv2.COLOR_BGR2GRAY)
                        .astype(np.float32), (0, 0), 1.1)
dog = soft - cv2.GaussianBlur(soft, (0, 0), 2.2)
ink = np.clip((-dog - 2.2) / 4.5, 0, 1)
# Bolder strokes around the big shapes too.
broad = cv2.GaussianBlur(soft, (0, 0), 2.4) - cv2.GaussianBlur(soft, (0, 0), 5)
ink = np.maximum(ink, np.clip((-broad - 4) / 7, 0, 1) * .8)
ink *= np.clip(noise(18, 1) * 1.5 + .9, 0, 1)  # gaps, as a pen lifts
ink = cv2.GaussianBlur(ink, (0, 0), .55)
INK = np.array([0x4C, 0x52, 0x34], np.float32)  # #34524C
paint = paint * (1 - ink[..., None] * .78) + INK * (ink[..., None] * .78)

# 7. Paper: a light cream wash, grain, blotches and fibres.
PAPER = np.array([0xE6, 0xF1, 0xF4], np.float32)  # #F4F1E6
paint = paint * .9 + PAPER * .1
grain = cv2.GaussianBlur(rng.standard_normal((h, w)).astype(np.float32), (0, 0), .7)
grain /= np.abs(grain).max()
blotch = noise(70, 1.5)
fibres = np.zeros((h, w), np.float32)
for _ in range(180):
    x, y = rng.uniform(0, w), rng.uniform(0, h)
    angle, length = rng.uniform(0, np.pi), rng.uniform(8, 34)
    bend = rng.uniform(-6, 6)
    points = []
    for t in np.linspace(-.5, .5, 9):
        px = x + np.cos(angle) * length * t - np.sin(angle) * bend * (t * t)
        py = y + np.sin(angle) * length * t + np.cos(angle) * bend * (t * t)
        points.append((px, py))
    cv2.polylines(fibres, [np.int32(points)], False, 1.0, 1, cv2.LINE_AA)
fibres = cv2.GaussianBlur(fibres, (0, 0), .6)
paper = 1 + grain * .065 + blotch * .03 - fibres * .028
paint *= paper[..., None]

# 8. The top fades into Home's flat sky.
fade_rows = int(h * .16)
t = np.clip(np.arange(h, dtype=np.float32) / fade_rows, 0, 1)
t = t * t * (3 - 2 * t)
paint = SKY * (1 - t[:, None, None]) + paint * t[:, None, None]

cv2.imwrite(out, np.clip(paint, 0, 255).astype(np.uint8),
            [cv2.IMWRITE_JPEG_QUALITY, 90])
print(out, w, h)
