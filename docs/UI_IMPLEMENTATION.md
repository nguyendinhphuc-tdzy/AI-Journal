# UI Implementation Notes

## Design tokens

Current visual direction:

| Token | Value | Use |
|---|---|---|
| Primary | `#5C9697` | CTA, selected tab, active state |
| Primary Dark | `#3F8996` | pressed/highlight |
| Primary Action | `#2E6E78` | fill of primary buttons with a light label (5.1:1 on Surface, WCAG AA); Primary/Primary Dark are below 4.5:1 with white text |
| Primary Light | `#DCEBE7` | selected chip/card background |
| Background | `#EEF4F1` | app background |
| Surface | `#FAFBF8` | cards, editor, modal |
| Text Primary | `#1F201C` | primary text |
| Text Secondary | `#6F7467` | metadata/hints |
| Warm Accent | `#796F5B` | mascot/warm accents |
| Positive | `#566F46` | positive/growth states |
| Border | `#D8DEDA` | dividers/cards |
| Soft Accent | `#A9C8BE` | tags/subtle decoration |

Approximate visual balance: 60% neutral, 30% teal/mint, 10% accent.

## Shape

- Small component radius: 12
- Input radius: 16
- Card radius: 20
- Large modal radius: 28
- Button radius: 28–32

## Motion

- Typical UI transition: 250–500 ms
- Tab transition: ~200–300 ms
- Mascot loop: ~1–3 s, subtle
- Button press: scale to ~0.98 and return

## Mascot state model

Use a single state-driven component instead of hard-coding assets across screens:

```text
idle
thinking
writing
happy
sleeping
walking
study
album
map
```

This starter deliberately uses a placeholder mascot. Replace it only with artwork the team owns or has permission to use.
