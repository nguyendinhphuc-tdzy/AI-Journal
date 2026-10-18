# OB02 independent idle layers

## Cockroach: extracted directly from the original GIF

The three `ob02-cockroach-idle-01…03.png` files replace the earlier AI redraws. They are built from frame 12 of `NudaenggifDe/Chú chó đuổi bắt gián hoạt hình.gif`, using the same background removal and character mask as the existing run frames. The user explicitly chose direct image processing to preserve the GIF artwork.

| File | Content | Canvas |
| --- | --- | --- |
| `ob02-cockroach-idle-01.png` | Original cockroach, neutral antennae | 306×319 |
| `ob02-cockroach-idle-02.png` | Same cockroach, tips sway left | 306×319 |
| `ob02-cockroach-idle-03.png` | Same cockroach, tips sway right | 306×319 |

Frame 01 is pixel-identical to `nudaeng-cockroach-rest-cockroach.png`. All pixels from y=249 downward, including the body, face, wings, feet and antenna roots, are identical across the three sprites. Only the original antenna strokes above this boundary are displaced, by at most 2 source pixels. Interpolation uses premultiplied alpha to avoid edge halos. No part of the character is redrawn.

Rebuild from the repository root in an environment with Pillow, NumPy and SciPy:

```sh
python mobile/tool/build_cockroach_idle_frames.py
```

The script only writes these three idle PNGs and verifies neutral/source equality, unchanged body pixels, transparency and successful PNG round trips. The GIF, run frames and dog sprites are preserved.

`NudaengCockroachIdle` now renders these assets in the full run-frame rectangle `(0, 0, 306, 319)` with `BoxFit.fill`; the old 1254-pixel sprite placement is removed. The existing 260 ms reveal and idle timing are retained. Antennae move left → centre → right → centre after a 1.2–2 s pause, then every 2–4 s. Reduced motion holds the neutral pose. The existing `assets/Deimage/` declaration covers all files. Hot restart the app after replacing assets at the same paths to clear cached images.

Validation: generator pixel/alpha checks passed; all 50 onboarding tests passed; analyzer reported no issues for the changed widget and test. A magnified three-pose comparison was inspected. The small source GIF limits resolution; enlarging these sprites will reveal the original pixels.

## Nudaeng: existing optional AI poses

These separate files are unchanged by the cockroach correction:

- `ob02-nudaeng-idle-open.png`: eyes open, holding blue slipper.
- `ob02-nudaeng-idle-blink.png`: eyes closed.
- `ob02-nudaeng-idle-tilt.png`: head tilted toward lower image-right.

These three dog assets are 1254×1254 transparent AI redraws originally made with built-in `image_gen`. They may differ from the GIF. The current idle widget uses `nudaeng-cockroach-rest-dog.png`, extracted from the GIF, instead of these optional dog poses.

## Generation prompts for the unchanged dog assets

### Nudaeng eyes open

```text
Use case: background-extraction. Edit target: supplied transparent rest scene with Nudaeng and small cockroach. Create ONLY Nudaeng as an isolated full-body transparent PNG sprite, completely remove cockroach. Preserve the exact golden dog identity and source rest pose: upright front-facing plump golden body, short legs, long floppy ears, two small horizontal black oval open eyes, small black triangular nose, grey-brown muzzle patch and subtle curved smile. Left side of image: dog hand holding blue/slate slipper pointing horizontally right, other arm at side. Preserve hand-drawn dark outlines and muted warm yellow watercolor/paper texture. No umbrella or any other prop. Reproduce the same pose, proportions, slipper and expression faithfully, with complete feet and ears. Neutral eyes-open idle frame, square canvas, dog centered with 12% transparent margin around silhouette, full-body visible, no clipping. Real alpha transparency outside character and slipper; no ground shadow, no scenery, no insect, no text, no white backing or checkerboard.
```

### Nudaeng blink

```text
Use case: precise-object-edit. Edit target: supplied transparent PNG of Nudaeng standing holding blue slipper. Create the eyes-closed idle blink frame. Change ONLY both black oval eyes into two short soft curved black strokes for gently closed eyelids. Keep all other pixels and positions as closely as possible: exact head silhouette and ears, front-facing posture, nose, grey muzzle patch and smile, golden body, arms, blue slipper, feet, watercolor texture, outlines, colors. Do not move or resize any body part, do not recenter or crop. Preserve exact 1254x1254 canvas and existing transparent margins, genuine alpha transparency. No insect, no umbrella, no shadow, no ground, no text, no background. Single standalone PNG.
```

### Nudaeng head tilt

```text
Use case: precise-object-edit. Edit target: supplied full-body transparent Nudaeng holding blue slipper. Create an alternate idle pose with ONLY a small head tilt, about 7 degrees clockwise toward image RIGHT, and open eyes gazing slightly downward to the lower-right where a tiny cockroach will be composited later. Do NOT include any cockroach in this image. Preserve exact standing body, arm, slipper, feet positions and proportions, as well as golden color, soft watercolor paper texture, line weight and grey muzzle smile. Only head/ears/face may change to make the modest curious head tilt; body and feet stay stationary. Keep the same character identity and calm friendly expression, no eyebrows or new features. Same 1254x1254 canvas, same scale and transparent margins; do not zoom or recenter. Genuine alpha transparency outside dog and slipper, no scene, no shadow, no text, no umbrella. Single transparent PNG idle sprite.
```
