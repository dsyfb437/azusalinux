#!/usr/bin/env python3
"""把 palette.json 渲染成一张 PNG 色卡（开发用，不属于发行版运行时）。

需要 Pillow：
    python3 tools/render-swatch.py [输出路径]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
PALETTE = ROOT / "branding" / "palette.json"


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def load_font(size: int) -> ImageFont.ImageFont:
    for path in (
        "/usr/share/fonts/truetype/inter/Inter-Regular.ttf",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dist" / "palette.png"
    pal = json.loads(PALETTE.read_text())

    W, H = 1180, 760
    img = Image.new("RGB", (W, H), hex_to_rgb(pal["dark"]["bg"]))
    d = ImageDraw.Draw(img)
    f_title = load_font(30)
    f_head = load_font(22)
    f_body = load_font(16)
    f_mono = load_font(15)

    d.text((40, 32), f"{pal['name']} 色板", font=f_title, fill=hex_to_rgb(pal["dark"]["text"]))
    d.text((40, 70), "由 8 张角色立绘统计得出", font=f_body,
           fill=hex_to_rgb(pal["dark"]["muted"]))

    x0 = 40
    col_w = 540
    y = 120

    for idx, name in enumerate(("light", "dark")):
        theme = pal[name]
        x = x0 + idx * (col_w + 40)
        card = Image.new("RGB", (col_w, 470), hex_to_rgb(theme["bg"]))
        cd = ImageDraw.Draw(card)
        cd.rounded_rectangle([0, 0, col_w - 1, 469], 14, fill=hex_to_rgb(theme["bg"]),
                             outline=hex_to_rgb(theme["border"]), width=2)
        cd.text((26, 24), "浅色" if name == "light" else "暗色", font=f_head,
                fill=hex_to_rgb(theme["text"]))

        yy = 66
        for key, value in theme.items():
            cd.rounded_rectangle([26, yy, 96, yy + 26], 6, fill=hex_to_rgb(value))
            cd.text((112, yy + 3), f"{key:<12}", font=f_mono, fill=hex_to_rgb(theme["muted"]))
            cd.text((250, yy + 3), value, font=f_mono, fill=hex_to_rgb(theme["text"]))
            yy += 30

        img.paste(card, (x, y))

    # 终端示意
    term = Image.new("RGB", (1100, 175), hex_to_rgb(pal["dark"]["bg"]))
    td = ImageDraw.Draw(term)
    td.rounded_rectangle([0, 0, 1099, 174], 14, fill=hex_to_rgb(pal["dark"]["bg"]),
                         outline=hex_to_rgb(pal["dark"]["border"]), width=2)
    td.text((28, 18), "azusa@azusalinux  ~", font=f_mono, fill=hex_to_rgb(pal["dark"]["muted"]))
    td.text((28, 46), "$ neofetch --off", font=f_mono, fill=hex_to_rgb(pal["dark"]["text"]))
    td.text((28, 74), "OS: AzusaLinux 0.1 (resolute) x86_64", font=f_mono,
            fill=hex_to_rgb(pal["dark"]["accent"]))
    td.text((28, 100), "DE: Plasma 6 · Theme: Azusa-Dark", font=f_mono,
            fill=hex_to_rgb(pal["dark"]["primary"]))
    td.text((28, 126), "INTEL UHD · 32768MiB", font=f_mono, fill=hex_to_rgb(pal["dark"]["pink"]))
    img.paste(term, (40, 620 - 20))

    out.parent.mkdir(exist_ok=True)
    img.save(out)
    print(f"已写出 {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
