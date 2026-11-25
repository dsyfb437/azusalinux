#!/usr/bin/env python3
"""Build the Azusa desktop themes from the violet SVG masters."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "branding/icons"
BASE = "Azusa-Papirus"
# Midtone, light accent, corresponding Papirus folder colour.
PALETTES = {
    "purple": ("#9676c1", "#b8a4d6", "violet"),
    "blue": ("#557fbe", "#99bde3", "blue"),
    "teal": ("#418e91", "#91c9c6", "teal"),
    "green": ("#5b8969", "#a8cda6", "green"),
    "yellow": ("#b5953f", "#e8d18a", "yellow"),
    "orange": ("#bd8051", "#e3b38c", "orange"),
    "red": ("#ba686c", "#dea5a4", "red"),
    "pink": ("#b96d99", "#e3abcd", "pink"),
    "slate": ("#718797", "#b1c3cc", "bluegrey"),
    "brown": ("#9c765d", "#cdb198", "brown"),
}
CONTEXTS = {"apps": "Applications", "places": "Places", "devices": "Devices", "actions": "Actions"}
ALIASES = {
    "actions/view-app-grid-ubuntu-symbolic": "view-app-grid-symbolic.svg",
    "devices/drive-removable-media-floppy": "media-floppy.svg",
    "places/user-home-open": "user-home.svg",
}
SIZES = (22, 24, 32, 48, 64)


def link(path, target):
    path.unlink(missing_ok=True)
    path.symlink_to(target)


def build(output, color):
    mid, light, folder_color = PALETTES[color]
    theme = output / (BASE if color == "purple" else f"{BASE}-{color}")
    sections = {}
    for level, source in (("16x16", ART / "compact"), ("scalable", ART)):
        for context, title in CONTEXTS.items():
            sources = sorted((source / context).glob("*.svg"))
            if not sources:
                continue
            directory = f"{level}/{context}"
            dest = theme / directory
            dest.mkdir(parents=True, exist_ok=True)
            for icon in sources:
                svg = icon.read_text().replace("#9676c1", mid).replace("#b8a4d6", light)
                (dest / icon.name).write_text(svg)
            for alias, original in ALIASES.items():
                if level == "scalable" and alias.startswith(context + "/"):
                    link(theme / level / (alias + ".svg"), original)
            if level == "16x16":
                sections[directory] = ("Size=16", "Type=Fixed", f"Context={title}")
                for size in (22, 24):
                    small = f"{size}x{size}/{context}"
                    (theme / small).mkdir(parents=True, exist_ok=True)
                    for icon in sources:
                        link(theme / small / icon.name, f"../../{directory}/{icon.name}")
                    sections[small] = (f"Size={size}", "Type=Fixed", f"Context={title}")
            else:
                sections[directory] = ("Size=64", "MinSize=25", "MaxSize=512",
                                       "Type=Scalable", f"Context={title}")
    names = (ROOT / "packaging/violet-icons.txt").read_text().split()
    for size in SIZES:
        directory = f"{size}x{size}/places"
        dest = theme / directory
        dest.mkdir(parents=True, exist_ok=True)
        for name in names:
            if name in ("user-home", "user-home-open"):
                # Exact-size folder links would otherwise win over the new desktop home.
                link(dest / (name + ".svg"), "../../scalable/places/user-home.svg")
                continue
            prefix, sep, rest = name.partition("-")
            target = prefix + "-" + folder_color + sep + rest
            link(dest / (name + ".svg"), f"../../../Papirus-Dark/{directory}/{target}.svg")
        sections[directory] = (f"Size={size}", "Type=Fixed", "Context=Places")
    index = ["[Icon Theme]", f"Name={theme.name}", "Comment=AzusaLinux system icons",
             "Inherits=Papirus-Dark,Papirus,Adwaita,hicolor", "Directories=" + ",".join(sections)]
    for directory, fields in sections.items():
        index.extend(("", f"[{directory}]", *fields))
    (theme / "index.theme").write_text("\n".join(index) + "\n")


if __name__ == "__main__":
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build/icons"
    for accent in PALETTES:
        build(output, accent)
