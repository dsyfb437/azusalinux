#!/usr/bin/python3
"""Expose themed launchers for the Ubuntu desktop's three system Snaps."""
from pathlib import Path
import os
import tempfile

SOURCE = Path("/var/lib/snapd/desktop/applications")
OUTPUT = Path("/run/azusa-icons")
LAUNCHERS = {
    "snap-store_snap-store": "azusa-app-center",
    "firmware-updater_firmware-updater": "azusa-firmware",
    "desktop-security-center_desktop-security-center": "azusa-security",
}


def refresh(source, output):
    output.mkdir(mode=0o755, parents=True, exist_ok=True)
    for name, icon in LAUNCHERS.items():
        entry = name + ".desktop"
        desktop = output / entry
        original = output / (icon + ".png")
        try:
            lines = (source / entry).read_text().splitlines(keepends=True)
        except FileNotFoundError:
            lines = []
        section = ""
        target = None
        for i, line in enumerate(lines):
            if line.startswith("["):
                section = line.strip()
            elif section == "[Desktop Entry]" and line.startswith("Icon="):
                target = Path(line[5:].strip())
                if target.is_absolute():
                    lines[i] = f"Icon={icon}\n"
                break
        if target is None or not target.is_absolute():
            desktop.unlink(missing_ok=True)
            original.unlink(missing_ok=True)
            continue
        if not original.is_symlink() or original.readlink() != target:
            pending = original.with_suffix(".new")
            pending.unlink(missing_ok=True)
            pending.symlink_to(target)
            pending.replace(original)
        data = "".join(lines)
        if desktop.exists() and desktop.read_text() == data:
            continue
        with tempfile.NamedTemporaryFile(mode="w", dir=output, delete=False) as tmp:
            tmp.write(data)
            os.fchmod(tmp.fileno(), 0o644)
        Path(tmp.name).replace(desktop)


if __name__ == "__main__":
    refresh(SOURCE, OUTPUT)
