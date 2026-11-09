# Map marker assets

Generated with built-in imagegen; animation packaged mechanically with ImageIO (Swift), preserving PNG alpha. UI is not integrated.

- pin-frame.png: empty teal/ivory marker, transparent central aperture. Place existing mood artwork behind the frame and clip it to the circular aperture. Actual pointed tip is approximately normalized (0.50, 0.934), not canvas bottom. Anchor this point to the geographic coordinate; do not bounce the whole frame.
- nudaeng-blink-wave.apng: single-play 1.8-second APNG, 10 timed playback frames, transparent. Trigger on marker selection or save confirmation, not continuously on every marker.
- nudaeng-blink-wave-sheet.png: 3 columns x 2 rows, left-to-right row-major, six source poses.
- nudaeng-frame-01.png through 06.png: separate transparent frames; frame 01 is the reduced-motion/static fallback. Sprite art has slight pose/outline differences between frames; preview on device before final integration.
- package-animation.swift: reproducible frame extraction and APNG packaging. Run with a writable Swift module cache if sandboxed.

Playback source indices (1-based): 1,2,1,3,4,5,4,5,3,6.
Durations seconds: .35,.10,.15,.10,.13,.13,.13,.13,.10,.48.

## Image prompts

### Pin
Asset type: reusable empty map marker frame overlay. One single upright map pin, straight-on flat 2D, circular upper ring with a short centered downward pointed coordinate tip integrated into ring bottom. Muted deep teal outer outline #2D737D, thick ivory inner ring, absolutely transparent circular central aperture to place a separate dog mascot behind it. Large circular aperture, no central dot. Square canvas; pin extent x=20%-80%, y=10%-90%, point precisely at x=50%,y=90%. Smooth friendly slightly hand drawn contour, clean readable at 48px. No mascot, no text, no shadows, no background, true alpha inside aperture AND outside pin. Isolated single object.

### Sprite sheet
Use case: identity-preserve animation sprite sheet. Use reference dog identity and style: golden tan Nudaeng, floppy ears, grey muzzle, black nose, uneven black outline and subtle paper grain. Create EXACTLY SIX frames in a perfectly regular 3-column by 2-row grid, no visible grid lines, all cells equal square size. Transparent alpha background. Reading left to right top then bottom: 1 neutral gentle closed smile, oval eyes open, both paws low; 2 SAME pose eyes fully closed for blink; 3 eyes open, viewer-right paw raised halfway; 4 eyes open viewer-right paw raised beside head tilted outward waving; 5 eyes open same raised paw tilted inward waving; 6 exactly return to first idle pose, eyes open, both paws low. Only eyelids and viewer-right arm move; crown, ears, head position, body outline, feet and scale MUST remain stationary between frames. Each cell contains one entire dog and generous 15 percent clear padding on all sides. Dog occupies same location and 70 percent cell height in every frame. No props, glasses, labels, numbers, text, panel borders, background color, watermark, shadows or ground. Make clean reusable modest friendly movement not exaggerated. Six drawings total, not five or seven. Output landscape 3:2 sheet.

### Background cleanup
Edit target: supplied SIX frame sprite sheet. Change ONLY the background: remove ALL brown/gold haze, glow and shadow outside the black dog silhouettes, make every pixel outside each character truly alpha=0 transparent. Keep all six characters, expressions, grid layout, exact positions, proportions and hand drawn style unchanged. No halo, no background shading or colored backplate. Retain crisp antialiased silhouette edges only. Output same 3 columns x2 rows landscape sheet with genuine transparent background.

