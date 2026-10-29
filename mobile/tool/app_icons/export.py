"""Builds the profession app icons from the masters in
assets/images/app-icons/ (transparent 1254 px PNGs).

Writes:
- assets/images/app-icon-<id>.png: 256 px, transparent, for the picker in Hồ sơ;
- android/app/src/main/res/mipmap-<density>/ic_launcher_<id>.png: legacy
  launcher icons (Android 7), the art on a rounded tinted square;
- android/app/src/main/res/mipmap-<density>/ic_launcher_<id>_foreground.png and
  mipmap-anydpi-v26/ic_launcher_<id>.xml: adaptive icons (Android 8+), the art
  inside the 66 dp safe zone of the 108 dp canvas, on a tinted background;
- android/app/src/main/res/values/app_icon_colors.xml: those backgrounds.

Run from mobile/ (needs Pillow: `pip install pillow`):
    python tool/app_icons/export.py
The ids, tints and Vietnamese names must match lib/features/profile/data/app_icon.dart.
"""
from pathlib import Path

from PIL import Image, ImageDraw

MOBILE = Path(__file__).resolve().parents[2]
MASTERS = MOBILE / "assets/images/app-icons"
RES = MOBILE / "android/app/src/main/res"

# id, master file, background tint (soft, like the app's cards).
ICONS = [
    ("security", "nudaeng-security-v1.png", "#DCE6F0"),
    ("student", "nudaeng-student-v1.png", "#F1E4CE"),
    ("guide", "nudaeng-guide-v1.png", "#D6E9E4"),
    ("restaurant", "nudaeng-restaurant-server-v1.png", "#F3DEDB"),
    ("office", "nudaeng-office-v1.png", "#E4E5F1"),
    ("nurse", "nudaeng-nurse-v1.png", "#F4E1EA"),
    ("repair", "nudaeng-repair-worker-v1.png", "#E6E2D3"),
]

# Launcher sizes per density: legacy icon (48 dp) and adaptive layer (108 dp).
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def art(master: Path) -> Image.Image:
    """The character alone: transparent margins trimmed, on a square."""
    image = Image.open(master).convert("RGBA")
    image = image.crop(image.getchannel("A").getbbox())
    side = max(image.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    # Centred across, resting on the bottom (a bust ends at the edge).
    square.paste(image, ((side - image.width) // 2, side - image.height), image)
    return square


def placed(character: Image.Image, canvas: int, box: float, tint=None,
           radius: float = 0, bottom: float | None = None) -> Image.Image:
    """[character] in a square [box] of a [canvas] px square: centred, or
    with its lower edge at [bottom] (both fractions of the canvas)."""
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    if tint:
        mask = Image.new("L", (canvas, canvas), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, canvas - 1, canvas - 1), radius=round(canvas * radius),
            fill=255)
        out.paste(Image.new("RGBA", (canvas, canvas), tint), (0, 0), mask)
    size = round(canvas * box)
    resized = character.resize((size, size), Image.LANCZOS)
    offset = (canvas - size) // 2
    top = offset if bottom is None else round(canvas * bottom) - size
    out.alpha_composite(resized, (offset, top))
    return out


def main() -> None:
    colors = []
    for icon_id, master, tint in ICONS:
        character = art(MASTERS / master)
        placed(character, 256, 0.94).save(
            MOBILE / f"assets/images/app-icon-{icon_id}.png", optimize=True)
        for density, scale in DENSITIES.items():
            folder = RES / f"mipmap-{density}"
            # Legacy: the art fills most of a rounded tinted square.
            placed(character, round(48 * scale), 0.80, tint, 0.22).save(
                folder / f"ic_launcher_{icon_id}.png", optimize=True)
            # Adaptive foreground: the launcher shows the middle 72 dp of the
            # 108 dp layer, often as a circle. A bust standing on its lower
            # edge (cut by the mask, as a portrait), narrow enough that props
            # at its sides stay inside.
            placed(character, round(108 * scale), 54 / 108,
                   bottom=91 / 108).save(
                folder / f"ic_launcher_{icon_id}_foreground.png", optimize=True)
        (RES / "mipmap-anydpi-v26" / f"ic_launcher_{icon_id}.xml").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android='
            '"http://schemas.android.com/apk/res/android">\n'
            f'    <background android:drawable="@color/app_icon_{icon_id}" />\n'
            '    <foreground android:drawable='
            f'"@mipmap/ic_launcher_{icon_id}_foreground" />\n'
            '</adaptive-icon>\n')
        colors.append(f'    <color name="app_icon_{icon_id}">{tint}</color>')
    (RES / "values/app_icon_colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Backgrounds of the profession launcher icons "
        "(tool/app_icons/export.py). -->\n"
        "<resources>\n" + "\n".join(colors) + "\n</resources>\n")


if __name__ == "__main__":
    (RES / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    main()
