"""Génère les images sources des icônes d'application, à partir du logo Kadjane.

Transpose `lib/design_system/widgets/k_logo.dart` : dégradé vert en diagonale,
K blanc, point or. Trois variantes, parce que les plateformes n'attendent pas
la même chose :

* `app_icon.png`            — carré à coins arrondis, transparent autour.
                              Icône Android historique.
* `app_icon_ios.png`        — carré plein, **sans** transparence ni coins
                              arrondis : iOS applique son propre masque et
                              rejette les icônes comportant un canal alpha.
* `app_icon_foreground.png` — monogramme seul, centré, largement margé.
                              Avant-plan de l'icône adaptative Android, dont
                              le lanceur rogne le tiers extérieur.

Le tracé se fait à 4096 px puis est réduit : `ImageDraw` ne lisse pas les bords.

Nécessite Pillow, absent du projet. Le plus simple est de passer par le
conteneur backend, qui embarque déjà Python :

    docker cp tool/generate_app_icon.py kadjane-backend:/tmp/
    docker exec kadjane-backend pip install --quiet Pillow
    docker exec kadjane-backend python /tmp/generate_app_icon.py /app/icons
    # puis récupérer les fichiers depuis backend/icons/

Régénérer les icônes de toutes tailles ensuite :

    dart run flutter_launcher_icons
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

# Repère de référence : celui du viewBox SVG du favicon (64x64).
UNIT = 64
SCALE = 64
SIZE = UNIT * SCALE
OUTPUT = 1024

PRIMARY = (0x0E, 0x6B, 0x54)
GREEN_900 = (0x06, 0x3C, 0x30)
GOLD = (0xE0, 0xA3, 0x3E)
WHITE = (255, 255, 255)


def u(value: float, scale: int = SCALE) -> float:
    return value * scale


def diagonal_gradient(size: int) -> Image.Image:
    """Dégradé linéaire du coin haut-gauche au coin bas-droit.

    Dessiné petit puis agrandi : l'interpolation bilinéaire suffit à obtenir un
    dégradé lisse, pour un coût dérisoire.
    """
    small = Image.new("RGB", (size, size))
    pixels = small.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            pixels[x, y] = tuple(
                round(a + (b - a) * t) for a, b in zip(PRIMARY, GREEN_900)
            )
    return small


def rounded_line(draw, start, end, width: float) -> None:
    """Segment à extrémités arrondies.

    `ImageDraw.line` coupe les bouts à angle droit : on ajoute un disque à
    chaque extrémité pour retrouver le `stroke-linecap="round"` du SVG.
    """
    draw.line([start, end], fill=WHITE, width=round(width))
    radius = width / 2
    for point in (start, end):
        draw.ellipse(
            [point[0] - radius, point[1] - radius,
             point[0] + radius, point[1] + radius],
            fill=WHITE,
        )


def draw_monogram(draw, scale: int = SCALE, offset: float = 0.0) -> None:
    """K blanc et point or, dans le repère 64x64."""
    def p(x: float, y: float) -> tuple[float, float]:
        return (u(x, scale) + offset, u(y, scale) + offset)

    rounded_line(draw, p(23.5, 20), p(23.5, 44), u(6.5, scale))
    rounded_line(draw, p(27, 32), p(41, 20), u(6, scale))
    rounded_line(draw, p(27, 32), p(41, 44), u(6, scale))

    cx, cy = p(48.6, 47.4)
    r = u(3.9, scale)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD)


def build_rounded() -> Image.Image:
    background = diagonal_gradient(64).resize((SIZE, SIZE), Image.BILINEAR)

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, SIZE - 1, SIZE - 1], radius=u(19.2), fill=255
    )

    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    icon.paste(background, (0, 0), mask)
    draw_monogram(ImageDraw.Draw(icon))
    return icon.resize((OUTPUT, OUTPUT), Image.LANCZOS)


def build_square() -> Image.Image:
    icon = Image.new("RGB", (SIZE, SIZE))
    icon.paste(diagonal_gradient(64).resize((SIZE, SIZE), Image.BILINEAR), (0, 0))
    draw_monogram(ImageDraw.Draw(icon))
    return icon.resize((OUTPUT, OUTPUT), Image.LANCZOS)


# Part de la largeur occupée par le monogramme dans l'avant-plan adaptatif.
#
# `flutter_launcher_icons` applique par-dessus un retrait de 16 % de chaque
# côté : le motif final couvre donc 0,80 × 0,68 ≈ 54 % du canevas. C'est
# confortablement à l'intérieur de la zone sûre — un cercle de 66 % — quelle
# que soit la forme appliquée par le lanceur, tout en restant lisible.
FOREGROUND_RATIO = 0.80


def build_foreground() -> Image.Image:
    """Monogramme seul, centré sur un canevas transparent.

    Le motif est **recadré sur son contenu** avant d'être remis à l'échelle :
    déduire un facteur du repère 64x64 donnerait une taille fausse, le
    monogramme n'occupant qu'une partie de ce repère.
    """
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_monogram(ImageDraw.Draw(canvas))

    mark = canvas.crop(canvas.split()[3].getbbox())
    target = round(OUTPUT * FOREGROUND_RATIO)
    ratio = target / max(mark.size)
    mark = mark.resize(
        (round(mark.width * ratio), round(mark.height * ratio)), Image.LANCZOS
    )

    foreground = Image.new("RGBA", (OUTPUT, OUTPUT), (0, 0, 0, 0))
    foreground.alpha_composite(
        mark, ((OUTPUT - mark.width) // 2, (OUTPUT - mark.height) // 2)
    )
    return foreground


# Icône de la barre d'état Android, par densité (dp -> px).
NOTIFICATION_SIZES = {
    "mdpi": 24,
    "hdpi": 36,
    "xhdpi": 48,
    "xxhdpi": 72,
    "xxxhdpi": 96,
}


def build_notification(size: int) -> Image.Image:
    """Monogramme blanc sur fond transparent.

    Android n'affiche qu'un masque alpha pour l'icône de la barre d'état : une
    image en couleurs y apparaîtrait comme un carré blanc plein. Seule la forme
    compte, d'où le point or lui aussi rendu en blanc.
    """
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rounded_line(draw, (u(23.5), u(20)), (u(23.5), u(44)), u(6.5))
    rounded_line(draw, (u(27), u(32)), (u(41), u(20)), u(6))
    rounded_line(draw, (u(27), u(32)), (u(41), u(44)), u(6))
    cx, cy, r = u(48.6), u(47.4), u(3.9)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE)

    mark = canvas.crop(canvas.split()[3].getbbox())
    # 85 % du cadre : Android ajoute lui-même une marge autour.
    target = round(size * 0.85)
    ratio = target / max(mark.size)
    mark = mark.resize(
        (max(1, round(mark.width * ratio)), max(1, round(mark.height * ratio))),
        Image.LANCZOS,
    )
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.alpha_composite(
        mark, ((size - mark.width) // 2, (size - mark.height) // 2)
    )
    return icon


def main() -> int:
    target = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    target.mkdir(parents=True, exist_ok=True)

    for name, image in (
        ("app_icon.png", build_rounded()),
        ("app_icon_ios.png", build_square()),
        ("app_icon_foreground.png", build_foreground()),
    ):
        image.save(target / name)
        print("écrit :", target / name)

    # Icônes de notification, à copier dans android/app/src/main/res/drawable-*
    for density, size in NOTIFICATION_SIZES.items():
        folder = target / f"drawable-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        build_notification(size).save(folder / "ic_notification.png")
        print("écrit :", folder / "ic_notification.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
