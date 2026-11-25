#!/usr/bin/env bash
# Build against the Ubuntu source version corresponding to the Live binary.
set -euo pipefail
version=${1:?expected Calamares source version}
directory=${2:?expected new build directory}
here=$(cd "$(dirname "$0")" && pwd)
mkdir "$directory"
cd "$directory"
apt-get source --only-source "calamares=$version"
sources=(calamares-*/)
cd "${sources[0]}"
test "$(dpkg-parsechangelog -S Version)" = "$version"
patch --batch --forward --fuzz=0 -p1 < "$here/calamares-erase-disk.patch"
cmake -S . -B ../obj -DCMAKE_BUILD_TYPE=Release -DCMAKE_SKIP_RPATH=ON \
    -DCMAKE_INSTALL_PREFIX=/usr -DWITH_PYBIND11=OFF -DWITH_QT6=ON \
    -DBoost_PYTHON_VERSION=3.14 -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DBUILD_TESTING=OFF
cmake --build ../obj --target calamares_viewmodule_partition --parallel "${BUILD_JOBS:-2}"
