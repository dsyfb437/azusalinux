"""Regression tests for the package set and target-shell expansion used by the ISO."""
import os
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]
PACKAGES = ("azusa-tools", "azusa-artwork", "azusa-settings", "azusa-desktop", "azusa-icons", "azusa-release")


class IsoPackagesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="azusa-iso-test-")
        self.addCleanup(self.tmp.cleanup)
        self.work = Path(self.tmp.name)
        self.debs = self.work / "debs"
        self.debs.mkdir()
        for package in PACKAGES:
            tree = self.work / package
            (tree / "DEBIAN").mkdir(parents=True)
            (tree / "DEBIAN/control").write_text(
                f"Package: {package}\nVersion: 0.2.0\nArchitecture: all\n"
                "Maintainer: Test <test@example.invalid>\nDescription: regression fixture\n"
            )
            subprocess.run(
                ["dpkg-deb", "--build", "--root-owner-group", str(tree),
                 str(self.debs / f"{package}_0.2.0_all.deb")],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )

    def check_packages(self):
        return subprocess.run(
            ["bash", str(ROOT / "iso-remaster/check-debs.sh"), str(self.debs)],
            text=True, capture_output=True,
        )

    def test_complete_package_set(self):
        result = self.check_packages()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_icons_is_rejected_before_build(self):
        (self.debs / "azusa-icons_0.2.0_all.deb").unlink()
        result = self.check_packages()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing required package: azusa-icons", result.stderr)

    def test_duplicate_package_is_rejected(self):
        shutil.copyfile(self.debs / "azusa-icons_0.2.0_all.deb",
                        self.debs / "azusa-icons_duplicate.deb")
        result = self.check_packages()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Duplicate package azusa-icons", result.stderr)

    def test_mixed_versions_are_rejected(self):
        control = self.work / "azusa-release/DEBIAN/control"
        control.write_text(control.read_text().replace("Version: 0.2.0", "Version: 0.2.1"))
        subprocess.run(["dpkg-deb", "--build", "--root-owner-group", str(control.parent.parent),
                        str(self.debs / "azusa-release_0.2.0_all.deb")],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        result = self.check_packages()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Mixed package versions", result.stderr)

    def test_corrupt_deb_is_rejected(self):
        (self.debs / "azusa-icons_0.2.0_all.deb").write_text("not a deb")
        self.assertNotEqual(self.check_packages().returncode, 0)

    def test_wrong_architecture_is_rejected(self):
        control = self.work / "azusa-icons/DEBIAN/control"
        control.write_text(control.read_text().replace("Architecture: all", "Architecture: arm64"))
        subprocess.run(
            ["dpkg-deb", "--build", "--root-owner-group", str(control.parent.parent),
             str(self.debs / "azusa-icons_0.2.0_all.deb")],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        result = self.check_packages()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unsupported architecture arm64", result.stderr)

    def test_prepare_removes_stale_packages_and_patches_each_boot_entry(self):
        profile = self.work / "repo/iso-remaster"
        shutil.copytree(ROOT / "iso-remaster", profile,
                        ignore=shutil.ignore_patterns("work"))
        shutil.copyfile(ROOT / "azusa-setup", profile.parent / "azusa-setup")
        iso_root = profile / "work/iso-root"
        grub = iso_root / "boot/grub/grub.cfg"
        grub.parent.mkdir(parents=True)
        grub.write_text(
            "linux /casper/vmlinuz autoinstall 'ds=nocloud;s=/cdrom/nocloud/' ---\n"
            "linux /casper/vmlinuz nomodeset ---\n"
        )
        stale = iso_root / "azusa-debs/azusa-icons_old.deb"
        stale.parent.mkdir()
        stale.write_text("stale")
        source = self.work / "source.iso"
        source.touch()
        env = dict(os.environ, SRC_ISO=str(source), DEBS=str(self.debs),
                   OUT=str(self.work / "output.iso"))
        command = ["bash", str(profile / "build.sh"), "prepare"]
        subprocess.run(command, env=env, check=True, capture_output=True)
        self.assertFalse(stale.exists())
        self.assertEqual(len(list((iso_root / "azusa-debs").glob("*.deb"))), len(PACKAGES))
        self.assertFalse((iso_root / "nocloud/azusa-setup").exists())
        expected = grub.read_text()
        self.assertEqual(expected.count("autoinstall"), 2)
        self.assertEqual(expected.count("'ds=nocloud;s=/cdrom/nocloud/'"), 2)
        subprocess.run(command, env=env, check=True, capture_output=True)
        self.assertEqual(grub.read_text(), expected)
        env["DEBS"] = str(iso_root / "azusa-debs")
        subprocess.run(command, env=env, check=True, capture_output=True)
        self.assertEqual(len(list((iso_root / "azusa-debs").glob("*.deb"))), len(PACKAGES))

    def test_seed_expands_every_package_inside_target_shell(self):
        seed = yaml.safe_load((ROOT / "iso-remaster/nocloud/user-data").read_text())
        install = next(cmd for cmd in seed["autoinstall"]["late-commands"]
                       if "apt-get install" in cmd)
        args = shlex.split(install)
        self.assertEqual(args[:5], ["curtin", "in-target", "--", "sh", "-ec"])
        capture = self.work / "arguments"
        fake_bin = self.work / "bin"
        fake_bin.mkdir()
        apt = fake_bin / "apt-get"
        apt.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$CAPTURE"\n')
        apt.chmod(0o755)
        script = args[5].replace("/root/azusa-debs", str(self.debs))
        env = dict(os.environ, PATH=str(fake_bin) + os.pathsep + os.environ["PATH"],
                   CAPTURE=str(capture))
        subprocess.run(["sh", "-ec", script], env=env, check=True)
        received = capture.read_text().splitlines()
        self.assertEqual(received[:2], ["install", "-y"])
        self.assertEqual(set(received[2:]), {str(p) for p in self.debs.glob("*.deb")})
        self.assertEqual(len(received[2:]), len(PACKAGES))

    @unittest.skipUnless(shutil.which("xorriso"), "xorriso is needed for ISO round trip")
    def test_iso_round_trip_preserves_boot_catalog_and_valid_checksums(self):
        profile = self.work / "iso-repo/iso-remaster"
        shutil.copytree(ROOT / "iso-remaster", profile,
                        ignore=shutil.ignore_patterns("work"))
        shutil.copyfile(ROOT / "azusa-setup", profile.parent / "azusa-setup")
        tree = self.work / "base-tree"
        grub = tree / "boot/grub"
        (grub / "i386-pc").mkdir(parents=True)
        (grub / "grub.cfg").write_text("linux /casper/vmlinuz ---\n")
        # A small El Torito fixture exercises xorriso's boot-info-table rewrite.
        (grub / "i386-pc/eltorito.img").write_bytes(bytes(32768))
        (tree / "azusa-debs").mkdir()
        (tree / "azusa-debs/azusa-old_0.0.9_all.deb").write_text("obsolete")
        (tree / "nocloud").mkdir()
        (tree / "nocloud/azusa-setup").write_text("obsolete identity script")
        source = self.work / "base.iso"
        subprocess.run(
            ["xorriso", "-as", "mkisofs", "-R", "-b", "boot/grub/i386-pc/eltorito.img",
             "-no-emul-boot", "-boot-load-size", "4", "-boot-info-table",
             "-o", str(source), str(tree)],
            check=True, capture_output=True,
        )
        output = self.work / "fixed.iso"
        env = dict(os.environ, SRC_ISO=str(source), DEBS=str(self.debs), OUT=str(output))
        built = subprocess.run(["bash", str(profile / "build.sh"), "all"],
                               env=env, text=True, capture_output=True)
        self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
        unpacked = self.work / "unpacked"
        subprocess.run(["xorriso", "-osirrox", "on", "-indev", str(output),
                        "-extract", "/", str(unpacked)], check=True, capture_output=True)
        verified = subprocess.run(["md5sum", "-c", "md5sum.txt"], cwd=unpacked,
                                  text=True, capture_output=True)
        self.assertEqual(verified.returncode, 0, verified.stdout + verified.stderr)
        self.assertEqual((unpacked / "nocloud/user-data").read_bytes(),
                         (ROOT / "iso-remaster/nocloud/user-data").read_bytes())
        self.assertFalse((unpacked / "nocloud/azusa-setup").exists())
        manifest = json.loads((unpacked / "azusa-build.json").read_text())
        self.assertEqual({p["name"] for p in manifest["packages"]}, set(PACKAGES))
        self.assertEqual({p["version"] for p in manifest["packages"]}, {"0.2.0"})
        self.assertEqual(len(list((unpacked / "azusa-debs").glob("*.deb"))), len(PACKAGES))
        report = subprocess.run(["xorriso", "-indev", str(output),
                                 "-report_el_torito", "plain"],
                                text=True, capture_output=True, check=True)
        self.assertIn("BIOS", report.stdout + report.stderr)


if __name__ == "__main__":
    unittest.main()
