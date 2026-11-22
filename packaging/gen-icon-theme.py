#!/usr/bin/env python3
"""生成 Azusa-Papirus 图标主题：只覆盖文件夹图标，其余继承 Papirus-Dark。

Papirus 自带 folder-violet.svg 这类变体，所以不需要复制 SVG——
用相对软链指过去即可，主题包只有几十 KB。
"""
from __future__ import annotations
import pathlib, sys

SIZES = ("22x22", "24x24", "32x32", "48x48", "64x64")
ROOT = pathlib.Path(__file__).resolve().parent.parent
NAMES = (ROOT / "packaging/violet-icons.txt").read_text().split()
OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build/icons"
THEME = OUT / "Azusa-Papirus"

lines = [
    "[Icon Theme]",
    "Name=Azusa-Papirus",
    "Comment=Azusa folder colours on top of Papirus-Dark",
    "Inherits=Papirus-Dark,Papirus,Adwaita,hicolor",
    "Directories=" + ",".join(f"{s}/places" for s in SIZES),
    "",
]
count = 0
for size in SIZES:
    places = THEME / size / "places"
    places.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        # Papirus 的命名是前缀式：folder-violet-documents.svg，不是后缀式
        if name in ("folder", "user"):
            violet = f"{name}-violet"
        elif name.startswith("folder-"):
            violet = "folder-violet-" + name[len("folder-"):]
        elif name.startswith("user-"):
            violet = "user-violet-" + name[len("user-"):]
        else:
            violet = f"{name}-violet"
        target = f"../../../Papirus-Dark/{size}/places/{violet}.svg"
        link = places / f"{name}.svg"
        if link.exists() or link.is_symlink():
            link.unlink()
        link.symlink_to(target)
        count += 1
    lines += [f"[{size}/places]", f"Size={size[0:2]}", "Context=Places", "Type=Fixed", ""]

(THEME / "index.theme").write_text("\n".join(lines))
print(f"  生成 {count} 个软链 → {THEME}")
