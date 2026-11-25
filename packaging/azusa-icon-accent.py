#!/usr/bin/python3
"""Follow the desktop accent while an Azusa icon theme is selected."""
from pathlib import Path
from gi.repository import Gio, GLib

BASE = "Azusa-Papirus"
settings = Gio.Settings.new("org.gnome.desktop.interface")


def update(*_):
    current = settings.get_string("icon-theme")
    if current not in THEMES:
        return
    color = settings.get_string("accent-color")
    target = BASE if color == "purple" else f"{BASE}-{color}"
    if current != target and (Path("/usr/share/icons") / target / "index.theme").is_file():
        settings.set_string("icon-theme", target)


if settings.props.settings_schema.has_key("accent-color"):
    _, colors = settings.props.settings_schema.get_key("accent-color").get_range().unpack()
    THEMES = {BASE, *(f"{BASE}-{color}" for color in colors if color != "purple")}
    settings.connect("changed::accent-color", update)
    settings.connect("changed::icon-theme", update)
    update()
    GLib.MainLoop().run()
