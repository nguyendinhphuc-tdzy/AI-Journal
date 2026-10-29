# Nudaeng profession artwork v1

Seven AI-edited transparent PNG character masters: security, student, guide,
restaurant server, office worker, nurse and repair worker. Original JPGs remain unchanged.

Created with the built-in image_gen tool using one source image per profession.
Watermark removal was requested by the user, who stated they have permission.

Prompt set (substitute the profession name for each source):

> Use case: background-extraction. Edit the supplied Nudaeng profession illustration.
> Remove white exterior background and copyright/watermark lettering; reconstruct
> underlying clothing cleanly. Preserve identity, outfit, props, pose, face, warm
> tan fur and black outline. Keep white clothing opaque. Center the bust on a square
> transparent canvas with consistent scale and margins; preserve all props. No
> shadow, tile, text or additional decoration. Actual transparent alpha background.

These are AI-edited character assets, not native launcher icon exports. AI output
introduces slight color/line differences from the originals. The restaurant-server and nurse
versions received a second edit to clean their lower clothing edges:

> Fix only the ragged bottom cut edge; remove white speckles below clothing and
> finish the lower torso with one smooth black outline. Preserve character, outfit,
> props, colors, proportions and square canvas. Actual transparent background.

All seven PNGs are 1254 × 1254 pixels with alpha (verified using sips).

Repair-worker prompt additions: preserve the beige hat, green plaid open shirt,
brown cuffs, hands and both repair tools; reconstruct the watermark-covered hand,
keep all tools within the square with transparent margins, and finish the lower
torso with a clean black outline. Created with the built-in image_gen tool.
Scale/margins are visually similar but have not been normalized pixel-exactly.

The profile icon picker and native home-screen icon switching are not wired to
these files. Platform-specific opaque backgrounds, adaptive-icon safe areas and
size exports remain integration work.

## Naming

The restaurant-server art was first named after a real restaurant brand. File
names and in-app labels use the generic "Phục vụ nhà hàng" instead: no third-party
brand name without permission (company rule). Rights to use these images as the
app's launcher icons were confirmed by the product owner on 30/10/2026.

## Where they are used

`tool/app_icons/export.py` builds, from these masters:
- `assets/images/app-icon-<id>.png` (256 px, transparent): the picker in Hồ sơ;
- Android launcher icons per profession (`res/mipmap-*/ic_launcher_<id>.png`,
  adaptive `mipmap-anydpi-v26/ic_launcher_<id>.xml` with a tinted background).
These masters are not bundled in the app (this folder is not listed in pubspec).
