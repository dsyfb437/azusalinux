import configparser
import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest


MODULE = Path(__file__).resolve().parents[1] / "packaging/gen-icon-theme.py"
spec = importlib.util.spec_from_file_location("azusa_icon_theme", MODULE)
icons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(icons)


class IconThemeTests(unittest.TestCase):
    def test_compact_glyphs_have_exact_gtk_lookup_sizes(self):
        with TemporaryDirectory() as tmp:
            icons.build(Path(tmp), "teal")
            theme = Path(tmp) / "Azusa-Papirus-teal"
            index = configparser.ConfigParser()
            index.read(theme / "index.theme")
            for size in (16, 22, 24):
                section = f"{size}x{size}/apps"
                self.assertIn(section, index["Icon Theme"]["Directories"].split(","))
                self.assertEqual(index[section]["Type"], "Fixed")
                self.assertEqual(index.getint(section, "Size"), size)
                for svg in (icons.ART / "compact/apps").glob("*.svg"):
                    master = theme / "16x16/apps" / svg.name
                    self.assertEqual((theme / section / svg.name).resolve(), master)
                    self.assertNotEqual(master.read_bytes(), (theme / "scalable/apps" / svg.name).read_bytes())
            self.assertIn("#418e91", (theme / "16x16/apps/org.gnome.Settings.svg").read_text())
            self.assertEqual((theme / "48x48/places/user-home.svg").resolve(),
                             theme / "scalable/places/user-home.svg")
