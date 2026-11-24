"""Render the boot and login wordmark from the installer mascot."""

import sys

from PIL import Image, ImageDraw, ImageFont


def main():
    source, destination = sys.argv[1:]
    with Image.open(source) as image:
        mascot = image.convert("RGBA")
    mascot.thumbnail((56, 56), Image.Resampling.LANCZOS)
    font = ImageFont.truetype(
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 35
    )
    name = "AzusaLinux"
    logo = Image.new("RGBA", (mascot.width + 14 + round(font.getlength(name)) + 2, 64))
    logo.alpha_composite(mascot, (0, (64 - mascot.height) // 2))
    ImageDraw.Draw(logo).text(
        (mascot.width + 14, 32), name, font=font, fill="#ECE8F6", anchor="lm"
    )
    logo.save(destination)


if __name__ == "__main__":
    main()
