# Album key animation assets

Created using the built-in `image_gen` tool, with `nudaeng-cockroach-rest-dog.png` as the character reference. The slipper was replaced by a brass key and a sage-green crossbody pouch. These are AI-generated poses, not pixel-exact transformations of the source.

The four originals are 1254×1254 RGBA PNGs with real alpha transparency and a common square canvas, kept unchanged in `tool/artwork_sources/album-key/`. The app ships 384×384 copies (`tool/build_album_layers.py`), enough for the 96 dp slot at 4× density (about 3 MB less in the app).

| Asset | Pose | Time after confirmed auth success |
| --- | --- | --- |
| `album-key-frame-01.png` | Holds key above the pouch; static waiting pose | 0–150 ms |
| `album-key-frame-02.png` | Lowers key to pouch opening | 150–400 ms |
| `album-key-frame-03.png` | Key goes behind the pouch rim | 400–750 ms |
| `album-key-frame-04.png` | Key fully hidden; hand withdrawn | 750–1000 ms, then holds |

## Flutter behavior

`lib/features/album/presentation/nudaeng_album_key.dart` supplies `NudaengAlbumKey`:

```dart
SizedBox.square(
  dimension: 240,
  child: NudaengAlbumKey(
    authSucceeded: authResult == AlbumAuthResult.success,
    onCompleted: onKeyPutAway,
  ),
)
```

The caller supplies the actual authentication result. While false, frame 01 stays still indefinitely, including during authentication, cancellation or failure. True starts exactly one 1-second sequence with no loop. Rebuilding with true does not replay it. At the end, frame 04 holds and `onCompleted` fires once. False cancels and resets the sequence for a new attempt. Disposal suppresses completion. Reduced motion shows the final pose immediately on success and calls completion after that frame, without a 1-second delay.

This widget is presentation only. A04 (`album_unlock_screen.dart`) now connects it to device authentication: confirmed success sets `authSucceeded`, and completion proceeds only while the foreground auth session remains valid. The animation callback alone is not authentication. `AlbumAccessGuard` retains the pending destination and hides private content until access is granted.

All poses stay mounted to allow image decoding during the waiting state. Review the motion on-device at the intended size: generated frames have minor differences in texture/outline outside the moving hand. The sequence intentionally uses discrete drawn poses rather than a looping GIF.

## Final prompts

### 01 — waiting

```text
Use case: identity-preserve. Reference image: the supplied golden cartoon dog Nudaeng, front facing, rounded golden body, floppy ears, tiny black oval eyes, small grey muzzle patch and subtle friendly smile, thin organic black outlines, soft muted yellow paper texture. Create a transparent PNG animation base pose for the Album unlock screen. Keep this exact Nudaeng character design, proportions and gentle expression. Remove the blue slipper completely. Add a small simple muted sage-green crossbody cloth pouch sitting on the dog's IMAGE-RIGHT hip, with a clearly visible open top and a narrow strap from image-left shoulder. Dog's paw on IMAGE-RIGHT holds a single small brass key upright by its ring at chest height, immediately above the pouch; the teeth point downward toward the opening, with clear space between key and pouch. Other paw relaxed at side. Waiting pose, still and calm. Full body and feet visible; centered square canvas with generous consistent transparent margins, subject 78% of image height. This is frame 01 of putting key into pouch: key visibly held up, not in pocket yet. No text, no locks floating, no other props, no shadow, no backdrop. Genuine alpha transparency outside subject, not white or checkerboard. Flat cozy hand-drawn style matching reference, no redesign, no glasses.
```

### 02 — lower the key

```text
Use case: precise-object-edit. Edit target: supplied transparent Nudaeng holding brass key over sage pouch, animation frame 01. Produce frame 02: move ONLY the IMAGE-RIGHT forearm/paw and the key slightly DOWN toward the pouch. Paw still holds the key by its ring; key remains vertical, its lowest tooth now just touching the pouch opening. This is a small intermediate lowering movement. Preserve ALL other details and positions exactly: head, face, ears, torso, left arm, legs, feet, shoulder strap, pouch body and opening, watercolor texture and outlines. Keep canvas 1254x1254, same scale, margins and bottom alignment; no camera movement, no reframing. Do not add another key or arm. Actual transparent alpha background. No text, no ground/shadow, no extra objects. Single standalone full-body PNG frame.
```

### 03 — insert the key

```text
Use case: precise-object-edit. Edit target: supplied Nudaeng holding key at opening of sage-green crossbody pouch (frame 02). Create frame 03 of placing key INSIDE the pouch. Change ONLY image-right forearm, paw, and key: lower the paw until fingers sit just inside the pouch opening, with the front rim of the pouch occluding the fingers; almost all the key is inside and hidden, at most the very top of the key ring visible under paw. Important: the key must disappear BEHIND the front of the pouch, not be painted on the outside. Keep the pouch itself, its opening, strap, body, head, expression, left arm, feet and all other shapes unchanged. Keep exact canvas 1254x1254, scale and position from reference. Preserve transparent alpha, hand-drawn outline, original golden and sage colors and soft texture. No text, no new objects, no ground or shadow. One standalone full-body PNG animation frame.
```

### 04 — empty hand

```text
Use case: precise-object-edit. Edit target: supplied transparent Nudaeng with paw inserting key into sage-green crossbody pouch. Produce FINAL frame 04 after key has been fully put away. The key is now entirely inside the pouch and MUST NOT be visible anywhere. Withdraw the IMAGE-RIGHT paw slightly upward from the pouch, empty fingers relaxed resting just above/beside its top rim. Keep small open pouch unchanged, now dark inside with no key showing. Change only this paw/forearm area and remove the remaining visible key ring. Preserve head, face, ears, torso, left arm, legs, feet, strap, pouch silhouette, warm golden colors, sage fabric and hand-drawn texture. Keep same 1254x1254 square canvas, full-body scale, placement and transparent margins. True alpha transparency, no backdrop, no text, no additional props, no shadow. One standalone PNG, calm final resting pose with key safely put away.
```
