"""Создаёт иконки iOS и Android из assets/icon/app_icon.png. Требуется Pillow."""

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/icon/app_icon.png"
IOS_ICONS = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID_RES = ROOT / "android/app/src/main/res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def adaptive_icon(source: Image.Image, size: int) -> Image.Image:
    # Android показывает центральные 72 dp слоя размером 108 dp.
    # Продлеваем край фона, чтобы при движении иконки не появлялась рамка.
    content_size = size * 2 // 3
    content = source.resize((content_size, content_size), Image.Resampling.LANCZOS)
    inset = (size - content_size) // 2
    icon = Image.new("RGB", (size, size))
    icon.paste(content, (inset, inset))

    for box, target, dimensions in [
        ((0, 0, content_size, 1), (inset, 0), (content_size, inset)),
        ((0, content_size - 1, content_size, content_size), (inset, size - inset), (content_size, inset)),
        ((0, 0, 1, content_size), (0, inset), (inset, content_size)),
        ((content_size - 1, 0, content_size, content_size), (size - inset, inset), (inset, content_size)),
    ]:
        icon.paste(content.crop(box).resize(dimensions, Image.Resampling.NEAREST), target)

    for source_point, target_box in [
        ((0, 0), (0, 0, inset, inset)),
        ((content_size - 1, 0), (size - inset, 0, size, inset)),
        ((0, content_size - 1), (0, size - inset, inset, size)),
        ((content_size - 1, content_size - 1), (size - inset, size - inset, size, size)),
    ]:
        icon.paste(content.getpixel(source_point), target_box)
    return icon


def main() -> None:
    with Image.open(SOURCE) as original:
        if original.width != original.height:
            raise ValueError("Исходная иконка должна быть квадратной")
        # Убираем канал прозрачности, в том числе для иконки App Store.
        source = Image.new("RGB", original.size, "black")
        if "A" in original.getbands():
            source.paste(original.convert("RGB"), mask=original.getchannel("A"))
        else:
            source.paste(original.convert("RGB"))

    catalog = json.loads((IOS_ICONS / "Contents.json").read_text())
    sizes = {
        item["filename"]: round(float(item["size"].split("x")[0]) * float(item["scale"][:-1]))
        for item in catalog["images"]
    }
    for filename, size in sizes.items():
        source.resize((size, size), Image.Resampling.LANCZOS).save(IOS_ICONS / filename)

    for density, scale in DENSITIES.items():
        destination = ANDROID_RES / f"mipmap-{density}"
        destination.mkdir(parents=True, exist_ok=True)
        size = round(48 * scale)
        source.resize((size, size), Image.Resampling.LANCZOS).save(destination / "ic_launcher.png")
        adaptive_icon(source, round(108 * scale)).save(destination / "ic_launcher_foreground.png")

    print(f"Созданы {len(sizes)} иконок iOS и {len(DENSITIES) * 2} иконок Android")


if __name__ == "__main__":
    main()
