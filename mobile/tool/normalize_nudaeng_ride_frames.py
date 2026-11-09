# Usage (Python with Pillow and NumPy):
#   python tool/normalize_nudaeng_ride_frames.py <aligned-dir> <out-dir>
#   python tool/normalize_nudaeng_ride_frames.py <dir> --verify  (sizes only)
"""One Nudaeng size for every pose, on one scooter.

The draft poses were drawn at different scales: aligned on the wheels, the
scooter matches but Nudaeng grows and shrinks (up to 15%, the push poses
smallest; see `face_scale`). Each frame is split into two layers by colour:

- Scooter: teal deck and stem, grey tyres near the ground, light blue-grey
  hubs and grips, and the outlines right next to them. One clean scooter is
  built from frame 1, its parts hidden by Nudaeng filled from the other
  frames (all aligned on the wheels).
- Nudaeng: everything else (body, outlines, eyes, nose, mouth), and the
  outlines it shares with the scooter where they touch. It is scaled to
  the frames' median size, then placed so the hands keep the frame's grip
  position and the standing foot keeps its height on the deck.

Run on the output of `align_nudaeng_side_frames.py`; then export with
`export_nudaeng_ride_frames.py`.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

src = Path(sys.argv[1])
VERIFY = '--verify' in sys.argv
if not VERIFY:
    dst = Path(sys.argv[2])
    dst.mkdir(parents=True, exist_ok=True)
REF = 9  # the face every pose is matched against
GROW = 5  # px of outline around the body that belongs to Nudaeng


def colour(px, lo, hi):
    return np.all((px[..., :3] >= lo) & (px[..., :3] <= hi), axis=-1)


def grow(mask, r):
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r:
                continue
            out |= np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
    return out


def distance(mask, limit):
    """Px to the nearest `mask` pixel, up to `limit` (beyond: limit + 1)."""
    out = np.full(mask.shape, limit + 1)
    for r in range(limit, -1, -1):
        out[grow(mask, r)] = r
    return out


def layers(px):
    opaque = px[..., 3] > 8
    beige = colour(px, (205, 165, 95), (255, 235, 185)) & opaque
    teal = colour(px, (95, 190, 175), (170, 250, 240)) & opaque
    hub = colour(px, (170, 185, 205), (220, 235, 252)) & opaque
    grey = colour(px, (40, 40, 40), (130, 130, 140)) & opaque & (
        np.abs(px[..., 0] - px[..., 2]) < 25)
    # Tyres: the greys within a wheel's radius of a hub near the ground, not
    # the grey edges of Nudaeng's legs just above them.
    floor = np.nonzero(grey)[0].max()
    hy, hx = np.nonzero(hub)
    low = hy > floor - 60
    hy, hx = hy[low], hx[low]
    xs = np.unique(hx)
    split = xs[np.argmax(np.diff(xs))] + 1
    rows, cols = np.indices(px.shape[:2])
    wheels = np.zeros(px.shape[:2], bool)
    for side in (hx < split, hx >= split):
        cy, cx = hy[side].mean(), hx[side].mean()
        wheels |= np.hypot(rows - cy, cols - cx) < floor - cy + 3
    tyre = grey & wheels
    scooter_colour = teal | hub | tyre
    # The scooter is its colours and the outlines right next to them; the
    # rest (nose, eyes, far outlines) is Nudaeng. Where both are near (hands
    # on the stem, feet on the deck), the outline goes with Nudaeng.
    # An outline between the two goes with the nearer colour, or the deck's
    # edge under a raised leg would scale and lift with Nudaeng.
    near_scooter = grow(scooter_colour, 6)
    dog = opaque & (~near_scooter
                    | (distance(beige, GROW + 1) <= distance(scooter_colour, 7))
                    & ~scooter_colour)
    scooter = opaque & ~dog
    # Solid scooter pixels another frame may lend: no faint edges.
    donor = scooter & (px[..., 3] > 200) & grow(scooter_colour, 3)
    return dog, scooter, beige, donor


def eye(px, beige):
    """The eye: the dark spot with body colour all around it."""
    top = np.nonzero(beige)[0].min()
    dark = (px[..., :3].max(-1) < 70) & (px[..., 3] > 128)
    spots = []
    for y, x in zip(*np.nonzero(dark[top + 10:top + 90])):
        y += top + 10
        if (beige[y, x - 8:x].any() and beige[y, x + 1:x + 9].any()
                and beige[y - 8:y, x].any() and beige[y + 1:y + 9, x].any()):
            spots.append((y, x))
    return np.mean(spots, axis=0)


def face(px):
    """Body colour and dark lines (outline, eye, nose, mouth)."""
    opaque = px[..., 3] > 128
    return (colour(px, (205, 165, 95), (255, 235, 185)) & opaque,
            (px[..., :3].max(-1) < 90) & opaque)


def face_scale(frame, ref):
    """How much `frame` must grow to match `ref`'s face: forehead, eye, snout
    and mouth, which every pose draws alike. The ears swing between poses
    and the body bends, so neither can measure the size."""
    rpx = ref.astype(int)
    rb, rd = face(rpx)
    ey, ex = np.round(eye(rpx, rb)).astype(int)
    y0, x0 = ey - 55, ex - 40
    rb, rd = rb[y0:ey + 30, x0:ex + 100], rd[y0:ey + 30, x0:ex + 100]
    px = frame.astype(int)
    cy, cx = eye(px, face(px)[0])

    def match(k):
        size = round(frame.shape[1] * k), round(frame.shape[0] * k)
        b, d = face(np.array(Image.fromarray(frame).resize(size, Image.LANCZOS))
                    .astype(int))
        best = 0
        for ty in range(-10, 11):
            for tx in range(-10, 11):
                top, left = round(cy * k) + ty - (ey - y0), round(cx * k) + tx - (ex - x0)
                if top < 0 or left < 0:
                    continue
                bb = b[top:top + rb.shape[0], left:left + rb.shape[1]]
                dd = d[top:top + rb.shape[0], left:left + rb.shape[1]]
                if bb.shape != rb.shape:
                    continue
                best = max(best, (bb & rb).sum() / (bb | rb).sum()
                           + (dd & rd).sum() / (dd | rd).sum())
        return best

    k = max(np.arange(.8, 1.3, .02), key=match)
    return float(max(np.arange(k - .02, k + .021, .005), key=match))


def anchors(beige, px):
    """Hands: the body's rightmost point at grip height. Foot: the lowest
    body point in the front half, the standing foot on the deck."""
    hub = colour(px, (170, 185, 205), (220, 235, 252)) & (px[..., 3] > 8)
    ys, xs = np.nonzero(hub)
    grip_y = ys.min()  # the grips are the highest hub-coloured part
    bys, bxs = np.nonzero(beige)
    near = np.abs(bys - grip_y) < 40
    hand_x = bxs[near].max()
    mid = (bxs.min() + bxs.max()) / 2
    foot_y = bys[bxs > mid].max()
    return float(hand_x), float(foot_y)


frames = [np.array(Image.open(src / f'nudaeng-side-draft-{i:02d}.png')
                   .convert('RGBA')) for i in range(1, 13)]
split = [layers(f.astype(int)) for f in frames]
# Scales against one reference face, then to the frames' median size.
scales = [face_scale(f, frames[REF - 1]) for f in frames]
median = float(np.median(scales))
scales = [k / median for k in scales]
if VERIFY:
    for i, k in enumerate(scales, 1):
        print(f'{i:2d} size off by {k:.3f}')
    sys.exit()

# The clean scooter: frame 1's, and only where frame 1's Nudaeng hides it,
# solid scooter pixels from the other frames (never where frame 1 is empty,
# or slightly offset outlines would double up).
ref_dog, ref_scooter = split[0][0], split[0][1]
scooter = np.zeros_like(frames[0])
scooter[ref_scooter] = frames[0][ref_scooter]
filled = ref_scooter.copy()
for frame, (_, _, _, donor) in zip(frames[1:], split[1:]):
    take = donor & ref_dog & ~filled
    scooter[take] = frame[take]
    filled |= take

h, w = frames[0].shape[:2]


def compose(layer, k, hand_x, foot_y):
    big = Image.fromarray(layer).resize((round(w * k), round(h * k)),
                                        Image.LANCZOS)
    # Hands stay at the grip, the standing foot at its height on the deck.
    dx = round(hand_x - hand_x * k)
    dy = round(foot_y - foot_y * k)
    # Crop the scaled layer where it would start outside the canvas.
    crop = big.crop((max(0, -dx), max(0, -dy), big.size[0], big.size[1]))
    out = Image.fromarray(scooter)
    out.alpha_composite(crop, (max(0, dx), max(0, dy)))
    return out


for i, (frame, (dog, _, beige, _)) in enumerate(zip(frames, split), 1):
    hand_x, foot_y = anchors(beige, frame.astype(int))
    layer = frame.copy()
    layer[~dog] = 0
    compose(layer, scales[i - 1], hand_x, foot_y).save(
        dst / f'nudaeng-side-draft-{i:02d}.png')
    print(f'{i:2d} scale {scales[i - 1]:.3f}')
