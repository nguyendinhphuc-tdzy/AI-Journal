# ND05 source and reproduction

Created on 2026-10-13 with the built-in imagegen tool using the imagegen skill.
The user explicitly requested a new GIF for the missing ND05 action. All other
screen artwork continues to use the supplied filenames.

- Identity reference: `mobile/assets/Deimage/Study-transparent.png`.
- Generated source: `nd05-check-notebook-sheet.png` (4 columns × 3 rows).
- Build: `/tmp/nudaeng-cutout-env/bin/python mobile/tool/build_nd05_gif.py`
  from the repository root, or another Python environment with Pillow, NumPy,
  and SciPy installed.
- Runtime output: `mobile/assets/NudaenggifDe/ND05-check-notebook-transparent.gif`.
- 12 frames × 100 ms; 320 × 400; transparent in every frame; no loop extension.
- Encoding crops cells and aligns feet to one baseline without rescaling each
  frame. The supplied source artwork is never overwritten. The runtime widget
  returns to the supplied S05 idle pose after this single animation.

## Full generation prompt

Use case: illustration-story. Create a transparent PNG animation SPRITE SHEET
for a mobile app, featuring the SAME Nudaeng dog as reference: pale golden
floppy-eared dog, tiny black eyes, black button nose, gray-brown muzzle, simple
black hand-drawn outlines, warm flat colors. Reference is identity/style only.
New action: dog holds an open small notebook, draws one green checkmark in the
notebook with a pencil, then makes one small gentle approving nod. EXACTLY 12
sequential frames arranged 4 columns by 3 rows in a square sheet, each cell
equal-sized. Reading order left to right, top to bottom. Consistent full-body dog
centered in each cell at identical size, aligned feet and notebook; generous
transparent margins per cell, no outlines or separators between cells. Frames
1-2 ready with pencil above blank notebook; frames 3-5 draw short then long
checkmark stroke; frames 6-7 hold completed checkmark; frames 8-10 head nods down
slightly while body and notebook stay still; frames 11-12 head returns neutral
with gentle smile. Designed for a single subtle 1.2 second animation, no looping
celebration. Genuine transparent background, no text/letters/numbers, no desk,
no shadows, no confetti, no zoom, no extra characters. Preserve same character
identity and illustration style across all twelve frames. Keep every frame's
artwork entirely inside its cell.
