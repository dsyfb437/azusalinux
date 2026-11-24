#!/usr/bin/env bash
# Build a signed archive in a new directory. The caller controls publication.
set -euo pipefail
export LC_ALL=C

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 OUTPUT SIGNING_FINGERPRINT DEB_DIRECTORY [DEB_DIRECTORY ...]" >&2
    exit 2
fi

output="$(realpath -m -- "$1")"
fingerprint="$2"
shift 2
[[ "$fingerprint" =~ ^[0-9A-Fa-f]{40}$ ]] || {
    echo 'Specify the full OpenPGP fingerprint.' >&2
    exit 2
}
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Refuse to overwrite a previous archive even after a failed invocation.
mkdir -- "$output"
pool="$output/pool/main/a/azusalinux"
index="$output/dists/resolute/main/binary-amd64"
mkdir -p -- "$pool" "$index"
for deb_directory in "$@"; do
    bash "$script_dir/../iso-remaster/check-debs.sh" "$deb_directory"
    for deb in "$deb_directory"/azusa-*.deb; do
        package="$(dpkg-deb -f "$deb" Package)"
        case "$package" in
            azusa-tools|azusa-artwork|azusa-settings|azusa-desktop|azusa-icons|azusa-release) ;;
            *) echo "Unexpected package: $package" >&2; exit 1 ;;
        esac
        version="$(dpkg-deb -f "$deb" Version)"
        arch="$(dpkg-deb -f "$deb" Architecture)"
        destination="$pool/${package}_${version}_${arch}.deb"
        if [ -e "$destination" ]; then
            cmp -- "$deb" "$destination"
        else
            install -m 0644 -- "$deb" "$destination"
        fi
    done
done

cd -- "$output"
apt-ftparchive packages pool > "$index/Packages"
gzip -n -c "$index/Packages" > "$index/Packages.gz"
for file in Packages Packages.gz; do
    for algorithm in SHA256 SHA512; do
        if [ "$algorithm" = SHA256 ]; then
            digest="$(sha256sum "$index/$file")"
        else
            digest="$(sha512sum "$index/$file")"
        fi
        mkdir -p -- "$index/by-hash/$algorithm"
        ln -- "$index/$file" "$index/by-hash/$algorithm/${digest%% *}"
    done
done

release_dir=dists/resolute
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=AzusaLinux \
    -o APT::FTPArchive::Release::Label=AzusaLinux \
    -o APT::FTPArchive::Release::Suite=resolute \
    -o APT::FTPArchive::Release::Codename=resolute \
    -o APT::FTPArchive::Release::Architectures=amd64 \
    -o APT::FTPArchive::Release::Components=main \
    -o APT::FTPArchive::Release::Acquire-By-Hash=yes \
    release "$release_dir" > Release
mv -- Release "$release_dir/Release"
sign() {
    if [[ "${AZUSA_SIGNING_PASSPHRASE_STDIN:-0}" = 1 ]]; then
        gpg --batch --pinentry-mode loopback --passphrase-fd 3 \
            --local-user "$fingerprint" "$@" 3<<<"$passphrase"
    else
        gpg --batch --local-user "$fingerprint" "$@"
    fi
}
if [[ "${AZUSA_SIGNING_PASSPHRASE_STDIN:-0}" = 1 ]]; then
    IFS= read -r passphrase
fi
sign --clearsign --output "$release_dir/InRelease" "$release_dir/Release"
sign --armor --detach-sign --output "$release_dir/Release.gpg" "$release_dir/Release"
unset -v passphrase
gpg --batch --export-options export-minimal --armor --export "$fingerprint" \
    > azusalinux-archive-keyring.asc
touch .nojekyll
