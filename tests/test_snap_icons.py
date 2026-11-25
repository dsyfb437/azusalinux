import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest


MODULE = Path(__file__).resolve().parents[1] / "packaging/azusa-snap-icons.py"
spec = importlib.util.spec_from_file_location("azusa_snap_icons", MODULE)
icons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(icons)


class SnapLauncherTests(unittest.TestCase):
    def test_export_refresh_and_removal_preserve_snap_metadata(self):
        with TemporaryDirectory() as tmp:
            source = Path(tmp) / "snap"
            source.mkdir()
            output = Path(tmp) / "runtime"
            entry = "snap-store_snap-store.desktop"
            upstream = source / entry
            overlay = output / entry
            fallback = output / "azusa-app-center.png"
            content = ("[Desktop Entry]\nName=App Center\nName[zh_CN]=应用中心\n"
                       "Icon=/snap/example/current/old.png\nExec=/snap/bin/example %U\n"
                       "X-SnapInstanceName=example\nActions=Updates;\n"
                       "[Desktop Action Updates]\nIcon=action-icon\nExec=/snap/bin/example --updates\n")
            (source / "firefox_firefox.desktop").write_text(content)
            for image in ("old", "new"):
                current = content.replace("old.png", image + ".png")
                upstream.write_text(current)
                icons.refresh(source, output)
                self.assertEqual(upstream.read_text(), current)
                self.assertEqual(overlay.read_text(), current.replace(
                    f"/snap/example/current/{image}.png", "azusa-app-center"))
                self.assertEqual(str(fallback.readlink()), f"/snap/example/current/{image}.png")
                self.assertFalse((output / "firefox_firefox.desktop").exists())
                inode = overlay.stat().st_ino
                icons.refresh(source, output)
                self.assertEqual(overlay.stat().st_ino, inode)

            upstream.write_text(content.replace("/snap/example/current/old.png", "upstream-themed-icon"))
            icons.refresh(source, output)
            self.assertFalse(overlay.exists())
            self.assertFalse(fallback.is_symlink())
            upstream.write_text(content)
            icons.refresh(source, output)
            upstream.unlink()
            icons.refresh(source, output)
            self.assertFalse(overlay.exists())
            self.assertFalse(fallback.is_symlink())
