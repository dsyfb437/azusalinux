#!/usr/bin/env python3
"""Record the exact source and local deb payload used to build an ISO."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


source, debs, output = map(Path, sys.argv[1:])
packages = []
for path in sorted(debs.glob("azusa-*.deb")):
    fields = subprocess.check_output(
        ["dpkg-deb", "--field", str(path), "Package", "Version", "Architecture"], text=True
    )
    values = dict(line.split(": ", 1) for line in fields.splitlines())
    packages.append(dict(name=values["Package"], version=values["Version"],
                         architecture=values["Architecture"], sha256=digest(path)))
output.write_text(json.dumps(dict(source_revision=os.environ.get("SOURCE_REVISION", "unknown"),
                                 base_iso_sha256=digest(source), packages=packages),
                             indent=2) + "\n")
