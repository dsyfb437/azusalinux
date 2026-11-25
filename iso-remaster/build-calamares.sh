#!/usr/bin/env bash
# Usage: sudo bash build-calamares.sh UBUNTU_ISO AZUSA_DEBS NEW_WORK_DIRECTORY
set -euo pipefail
if (( $# != 3 || EUID != 0 )); then
    echo "Usage: sudo bash $0 UBUNTU_ISO AZUSA_DEBS NEW_WORK_DIRECTORY" >&2
    exit 2
fi
if [[ ${AZUSA_PRIVATE_MOUNTS:-} != "$$" ]]; then
    exec unshare --mount --propagation private sh -c 'export AZUSA_PRIVATE_MOUNTS=$$; exec bash "$@"' sh "$0" "$@"
fi

here=$(cd "$(dirname "$0")" && pwd)
iso=$(realpath "$1")
debs=$(realpath "$2")
work=$(realpath -m "$3")
bash "$here/check-debs.sh" "$debs"
echo "601e30fbf5d97759367c632e2c33630665039b7e2158fd068403da3ccf1bda1f  $iso" | sha256sum -c -
mkdir "$work"
cd "$work"
mkdir upstream base standard live output
rsvg-convert -w 256 -h 256 "$here/../branding/logo/azusalinux-logo.svg" -o output/azusalinux-logo.png
mount -o loop,ro "$iso" upstream
mount -o loop,ro upstream/casper/minimal.squashfs base
mount -o loop,ro upstream/casper/minimal.standard.squashfs standard
mount -o loop,ro upstream/casper/minimal.standard.live.squashfs live

build_layer() {
    local name=$1 lowers=$2 image=$3
    local tree="$work/$name-tree" root="$work/$name-tree/root"
    mkdir -p "$tree"/{root,upper,work}
    mount -t overlay overlay -o "lowerdir=$lowers,upperdir=$tree/upper,workdir=$tree/work" "$root"
    mount -t tmpfs tmpfs "$root/run"
    mount -t proc proc "$root/proc"
    mount -t devpts devpts -o newinstance "$root/dev/pts"
    mkdir -p "$root/run/systemd/resolve" "$root/run/build"
    cp -L /etc/resolv.conf "$root/run/systemd/resolve/stub-resolv.conf"
    cp "$root/etc/apt/sources.list.d/ubuntu.sources" "$root/run/build/"
    if [[ -n ${UBUNTU_MIRROR:-} ]]; then
        sed -i "s|http://archive.ubuntu.com/ubuntu/|$UBUNTU_MIRROR|g" "$root/run/build/ubuntu.sources"
    fi
    test ! -e "$root/usr/sbin/policy-rc.d"
    printf '#!/bin/sh\nexit 101\n' > "$root/usr/sbin/policy-rc.d"
    chmod 755 "$root/usr/sbin/policy-rc.d"
    local apt=(chroot "$root" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get
        -o Dir::Etc::sourcelist=/run/build/ubuntu.sources -o Dir::Etc::sourceparts=-
        -o Dir::State::lists=/run/build/lists -o Dir::Cache::archives=/run/build/archives)
    mkdir -p "$root/run/build"/{lists,archives}/partial
    "${apt[@]}" update
    if [[ $name == target ]]; then
        local packages=(grub-efi-amd64-bin efibootmgr)
        local file
        for file in "$debs"/azusa-*.deb; do
            cp "$file" "$root/run/build/"
            packages+=("/run/build/${file##*/}")
        done
        "${apt[@]}" -y --no-install-recommends install "${packages[@]}"
        install -Dm644 "$here/nocloud/apt/azusalinux-archive-keyring.asc" \
            "$root/etc/apt/keyrings/azusalinux-archive-keyring.asc"
        install -m644 "$here/nocloud/apt/azusalinux.sources" "$root/etc/apt/sources.list.d/"
        rm -f "$root/etc/apt/sources.list.d/cdrom.sources"
        python3 "$here/branding/render-logo.py" "$work/output/azusalinux-logo.png" \
            "$work/output/azusa-logo.png"
        bash "$here/branding/install-target.sh" "$root" "$work/output/azusa-logo.png"
        test -s "$root/boot/vmlinuz"
        local kernel
        kernel=$(basename "$(readlink "$root/boot/vmlinuz")")
        kernel=${kernel#vmlinuz-}
        test -d "$root/usr/lib/modules/$kernel"
        chroot "$root" dracut --no-hostonly --force "/boot/initrd.img-$kernel" "$kernel"
        test -s "$root/boot/initrd.img"
    else
        "${apt[@]}" -y --no-install-recommends install calamares rsync squashfs-tools dosfstools e2fsprogs
        local version plugin
        version=$(chroot "$root" dpkg-query -W -f='${source:Version}' calamares)
        bash "$here/build-partition-module.sh" "$version" "$work/partition-build"
        plugin=libcalamares_viewmodule_partition.so
        install -m644 "$work/partition-build/obj/src/modules/partition/$plugin" \
            "$root/usr/lib/x86_64-linux-gnu/calamares/modules/partition/$plugin"
        local config="$here/calamares"
        install -d "$root/etc/calamares"
        cp -r "$config"/{branding,modules,settings.conf} "$root/etc/calamares/"
        install -m644 "$work/output/azusalinux-logo.png" "$root/etc/calamares/branding/azusa/azusa.png"
        install -Dm644 "$here/../branding/logo/azusalinux-logo.svg" "$root/usr/share/icons/hicolor/scalable/apps/azusalinux-logo.svg"
        install -m644 "$here/../branding/wallpapers/lake-dawn.jpg" \
            "$root/etc/calamares/branding/azusa/desktop.jpg"
        install -Dm755 "$config/azusa-install" "$root/usr/local/bin/azusa-install"
        install -Dm644 "$config/azusa-install.desktop" "$root/usr/share/applications/azusa-install.desktop"
        install -Dm644 "$config/azusa-install.desktop" "$root/etc/xdg/autostart/azusa-install.desktop"
        ln -sfn /dev/null "$root/etc/systemd/user/ubuntu-desktop-installer.service"
        rm -f "$root/etc/systemd/system/display-manager.service.d/wait-for-snapd-seeding.conf"
        rm -f "$root/var/lib/snapd/desktop/applications/ubuntu-desktop-bootstrap_ubuntu-desktop-bootstrap.desktop"
    fi
    rm "$root/usr/sbin/policy-rc.d"
    umount "$root/dev/pts" "$root/proc" "$root/run" "$root"
    mksquashfs "$tree/upper" "$image" -comp zstd -Xcompression-level 3 -noappend
}

build_layer target "$work/standard:$work/base" output/target.squashfs
live_image=minimal.standard.live.azusa.squashfs
build_layer installer "$work/live:$work/standard:$work/base" "output/$live_image"
for config in grub.cfg loopback.cfg; do
    sed -e 's/Try or Install Ubuntu/Try or install AzusaLinux/' \
        -e 's/Ubuntu (safe graphics)/AzusaLinux (safe graphics)/' \
        -e "s| ---| layerfs-path=$live_image ---|" "upstream/boot/grub/$config" > "output/$config"
done
grep -vE ' \./boot/grub/(grub|loopback)\.cfg$' upstream/md5sum.txt > output/md5sum.txt
map_file() {
    local digest
    read -r digest _ < <(md5sum "$1")
    printf '%s  .%s\n' "$digest" "$2" >> output/md5sum.txt
    mappings+=(-map "$1" "$2")
}
mappings=()
map_file output/grub.cfg /boot/grub/grub.cfg
map_file output/loopback.cfg /boot/grub/loopback.cfg
map_file output/target.squashfs /azusa/target.squashfs
map_file "output/$live_image" "/casper/$live_image"
xorriso -indev "$iso" -outdev "$work/azusalinux-calamares.iso" \
    "${mappings[@]}" -map output/md5sum.txt /md5sum.txt -boot_image any replay -commit
sha256sum azusalinux-calamares.iso > SHA256SUMS
