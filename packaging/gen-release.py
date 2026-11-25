#!/usr/bin/env python3
"""Generate package-owned release metadata from the Debian package version."""
from pathlib import Path
import re
import sys

out = Path(sys.argv[1])
version = sys.argv[2]
if not re.fullmatch(r"[0-9][0-9A-Za-z.+~:-]*", version):
    raise SystemExit("Invalid release version")
out.mkdir(parents=True, exist_ok=True)
(out / "os-release").write_text(f'''PRETTY_NAME="AzusaLinux {version}"
NAME="AzusaLinux"
VERSION_ID="{version}"
VERSION="{version}"
VERSION_CODENAME=azusa
ID=azusalinux
LOGO=azusalinux-logo
ID_LIKE="ubuntu debian"
UBUNTU_CODENAME=resolute
HOME_URL="https://azusaaa.com"
SUPPORT_URL="https://github.com/dsyfb437/azusalinux/issues"
BUG_REPORT_URL="https://github.com/dsyfb437/azusalinux/issues"
''')
(out / "lsb-release").write_text(f'''DISTRIB_ID=AzusaLinux
DISTRIB_RELEASE={version}
DISTRIB_CODENAME=azusa
DISTRIB_DESCRIPTION="AzusaLinux {version}"
''')
(out / "issue").write_text(f"AzusaLinux {version} \\n \\l\n")
(out / "issue.net").write_text(f"AzusaLinux {version}\n")
