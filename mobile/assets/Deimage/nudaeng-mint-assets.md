# Nudaeng mint scene layers

Generated with the built-in `image_gen` tool from `Nudaeng dưới tán hoa bạc hà.png`. Original preserved. These are AI-redrawn layers; they are not pixel-exact extractions.

## Files

- `nudaeng-mint-background.png`: empty mint canopy and pavement, with dog, umbrella, petals and character shadow removed.
- `nudaeng-mint-petal.png`: one cream petal on actual transparent alpha.
- `nudaeng-umbrella-frame-01.png`: isolated Nudaeng and umbrella, eyes open. Also the standalone static character layer.
- `nudaeng-umbrella-frame-02.png`: eyes half closed.
- `nudaeng-umbrella-frame-03.png`: eyes closed.
- `nudaeng-umbrella-frame-04.png`: eyes open again, byte-for-byte copy of frame 01 to return to the initial pose.

Suggested one-shot timing: 01 = 800 ms, 02 = 100 ms, 03 = 120 ms, 04 = 780 ms; then hold frame 04. Use frame 01 for reduced motion. These are four separate PNG frames, not an animated GIF. All are already covered by the existing `assets/Deimage/` declaration in pubspec.yaml.

Native dimensions: background 940×1673; petal 1254×1254; frames 01/04 1083×1453; frames 02/03 1083×1452. When integrating, render all character frames into the same fixed 1083:1453 display rectangle so the one-pixel export difference does not alter layout. Generated frames have small drawing differences outside the eyes, so they are suitable as initial animation artwork rather than a pixel-locked sprite sequence.

Validation: all PNGs decode with valid checksums; the petal and all character frames contain actual alpha transparency. Flutter analyze reported no issues; all 12 targeted onboarding/artwork tests passed. These tests cover the existing UI, not playback of the new frames.

This delivery supplies assets and the storage dependency only. The current onboarding screen still uses the original single-layer image. Animation playback and persistence behavior are not wired into the app in this change. `shared_preferences: ^2.5.6` was added for small local preferences such as onboarding completion; see https://pub.dev/packages/shared_preferences. The resolved dependency set in pubspec.lock requires Dart >=3.12.0 and Flutter >=3.44.0.

## Final generation prompts

### Background

```text
Use case: precise-object-edit. Edit target: the supplied Nudaeng mint canopy illustration. Produce ONLY the clean empty background layer for the same mobile scene, portrait 940:1674 aspect ratio. Remove the golden dog Nudaeng completely, its entire umbrella including shaft handle and hanging ornament, its cast shadow, and ALL individual floating or fallen cream flower petals (including petals formerly over the umbrella). Inpaint the exposed regions naturally with the existing pale ivory/mint sky and diagonal mint paved ground. Preserve the exact composition, framing, soft watercolor paper texture, original mint tree canopy shapes and colors in the upper half, diagonal ground lines and pastel atmosphere. No new objects, no characters, no umbrella, no petals, no text, no watermark. Full opaque background, keep portrait format.
```

### Petal

```text
Use case: background-extraction. Reference: supplied illustration of Nudaeng under a mint canopy. Create one single isolated cream flower PETAL as a transparent PNG asset. Match the small floating petals in the reference: asymmetric rounded teardrop, warm pale ivory fill, softly textured taupe hand-drawn outline, simple flat watercolor style. One petal only, centered, with generous transparent padding. Genuine alpha transparency outside the petal; no white rectangle, no baked checkerboard, no ground, no shadow, no leaves or stem, no dog, no umbrella, no text. Square canvas.
```

### Frame 01

```text
Use case: background-extraction. Edit target: supplied Nudaeng under mint canopy illustration. Create a separate transparent PNG layer of ONLY the golden dog Nudaeng holding the entire open transparent umbrella, including its pink curved handle, grey shaft, black outlined canopy, and the little golden hanging ornament at left. Preserve character identity exactly: tall soft golden body, floppy ears, black simple eyes, charcoal muzzle patch, little smile, heavy organic black hand-drawn contour and soft watercolor shading. Initial animation pose: head tilted gently looking upward as in source. Keep source composition and proportions: umbrella extends to upper left of dog, curved handle right. Reconstruct the small cropped lower feet so the character is complete, add margin all around. Portrait canvas, isolated subject fills it without clipping. Remove every floating petal, mint foliage, sky, paving, cast ground shadow, and blue ground spot. Genuine transparent alpha background, no white or checkerboard backing. Umbrella panels must be translucent with very light mint highlights and opaque outlines/ribs; no embedded scenery. No text, no new objects.
```

### Frame 02

```text
Use case: precise-object-edit. Edit target: supplied transparent Nudaeng umbrella PNG. Make exactly one extremely localized edit: change BOTH black oval eyes to HALF-CLOSED eyes, slim black oval eyelids about half their current height. Keep every other part of this image unchanged. This is the middle frame of a gentle blink, NOT a new drawing. Preserve exact original image dimensions 1083x1453 and all original pixel positions, especially umbrella tip, edges, ornament, body, paws, feet and pink handle. Keep head tilt and facial expression; don't redraw or move muzzle or ears. Preserve transparent alpha background and all shading and line thickness. Single PNG frame, no additional objects or background.
```

### Frame 03

```text
Use case: precise-object-edit. Edit target: this isolated transparent PNG of Nudaeng holding an umbrella. Output animation frame 03, gentle blink fully closed. Change ONLY the two eyes: replace each black oval eye with one thin relaxed curved black eyelid stroke, eyes entirely closed. Keep the head tilted exactly as before and keep muzzle and smiling mouth unchanged. Preserve all other pixels and positions as closely as possible: the complete umbrella, ornament, curved handle, body, limbs, feet, outline, watercolor texture, colors and shading. Keep input canvas size 1083 by 1453 pixels, same subject scale and placement, no reframing or cropping. Genuine transparent alpha background. No shadow, no scenery, no petals, no text. Single standalone PNG, not a sheet.
```

Frame 04 uses frame 01 directly; no separate generation prompt.
