#!/usr/bin/env bash
# Destructive package-lifecycle test: disposable Ubuntu VM only.
set -euo pipefail
if [ "${AZUSA_TEST_VM:-}" != 1 ] || [ "$(id -u)" -ne 0 ]; then
    echo 'Run as root with AZUSA_TEST_VM=1 in a disposable Ubuntu VM.' >&2
    exit 2
fi
debs="$(realpath "${1:?Pass the directory containing the release debs}")"
paths=(/usr/lib/os-release /etc/lsb-release /etc/issue /etc/issue.net)
state="$(mktemp -d)"
trap 'rm -f "$state/vendor-hashes"; rmdir "$state"' EXIT

assert_identity() {
    sh -ec '. /etc/os-release; test "$ID" = azusalinux; test "$VERSION_ID" = 0.1.1; test "$UBUNTU_CODENAME" = resolute'
    for path in "${paths[@]}"; do
        test "$(dpkg-divert --listpackage "$path")" = azusa-release
        test -L "$path"
        test -r "$path"
    done
    grep -q '^DISTRIB_ID=AzusaLinux$' /etc/lsb-release
    grep -q '^AzusaLinux 0.1.1' /etc/issue
}

sh -ec '. /etc/os-release; test "$ID" = ubuntu'
export DEBIAN_FRONTEND=noninteractive
apt-get install -y "$debs"/azusa-*.deb
assert_identity
echo 'PASS install/upgrade to 0.1.1'

apt-get install --reinstall -y base-files
assert_identity
echo 'PASS base-files reinstall preserves all four identity paths'
for path in "${paths[@]}"; do
    printf '%s %s\n' "$(sha256sum "$path.ubuntu" | cut -d' ' -f1)" "$path" >> "$state/vendor-hashes"
done

apt-get install --reinstall -y "$debs"/azusa-*.deb
assert_identity
echo 'PASS repeated package installation is idempotent'

apt-get remove -y azusa-desktop azusa-release
while read -r expected path; do
    test -z "$(dpkg-divert --listpackage "$path")"
    test "$(sha256sum "$path" | cut -d' ' -f1)" = "$expected"
done < "$state/vendor-hashes"
sh -ec '. /etc/os-release; test "$ID" = ubuntu'
echo 'PASS remove restores original vendor files byte for byte'
apt-get purge -y azusa-release

apt-get install -y "$debs"/azusa-*.deb
assert_identity
apt-get check
echo 'PASS reinstall after purge and dependency consistency'
