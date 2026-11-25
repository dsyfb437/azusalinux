"""Pair the distribution icon with its name for boot and login screens."""

import sys

from PIL import Image, ImageDraw, ImageFont


def main():
    source, destination = sys.argv[1:]
    with Image.open(source) as image:
        icon = image.convert("RGBA")
    icon.thumbnail((56, 56), Image.Resampling.LANCZOS)
    font = ImageFont.truetype(
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 35
    )
    name = "AzusaLinux"
    logo = Image.new("RGBA", (icon.width + 14 + round(font.getlength(name)) + 2, 64))
    logo.alpha_composite(icon, (0, (64 - icon.height) // 2))
    ImageDraw.Draw(logo).text(
        (icon.width + 14, 32), name, font=font, fill="#ECE8F6", anchor="lm"
    )
    logo.save(destination)


if __name__ == "__main__":
    main()
