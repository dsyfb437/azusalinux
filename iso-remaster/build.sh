#!/usr/bin/env bash
# build.sh — 把 Azusa 的 deb 塞进官方 Ubuntu ISO，做成可自动安装的镜像
#
#   ./build.sh extract   # 解包官方 ISO
#   ./build.sh prepare   # 注入 nocloud 配置和 deb
#   ./build.sh pack      # 重新打包
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC_ISO="${SRC_ISO:-$ROOT/../build/ubuntu-26.04.1-desktop-amd64.iso}"
WORK="$HERE/work"
ISO_ROOT="$WORK/iso-root"
DEBS="${DEBS:-/tmp/azusa-debs}"
OUT="${OUT:-$ROOT/../build/azusalinux-0.1.1-amd64.iso}"
ACTION="${1:-all}"

if [ ! -f "$SRC_ISO" ]; then
    echo "Source ISO does not exist: $SRC_ISO" >&2
    exit 1
fi
if [ "$(realpath -m "$OUT")" = "$(realpath "$SRC_ISO")" ]; then
    echo "OUT must not overwrite SRC_ISO" >&2
    exit 1
fi

case "$ACTION" in
extract)
    rm -rf "$ISO_ROOT"; mkdir -p "$ISO_ROOT"
    xorriso -osirrox on -indev "$SRC_ISO" -extract / "$ISO_ROOT" 2>&1 | tail -2
    chmod -R u+w "$ISO_ROOT"
    echo "解包完成"
    ;;
prepare)
    bash "$HERE/check-debs.sh" "$DEBS"
    test -f "$ISO_ROOT/boot/grub/grub.cfg"
    mkdir -p "$ISO_ROOT/nocloud" "$ISO_ROOT/azusa-debs"
    cp "$HERE/nocloud/user-data" "$ISO_ROOT/nocloud/user-data"
    cp "$HERE/nocloud/meta-data" "$ISO_ROOT/nocloud/meta-data"
    rm -f "$ISO_ROOT/nocloud/azusa-setup"
    # Re-running prepare must not retain packages from an older build.
    if [ "$(realpath "$DEBS")" != "$(realpath "$ISO_ROOT/azusa-debs")" ]; then
        find "$ISO_ROOT/azusa-debs" -maxdepth 1 -type f -name 'azusa-*.deb' -delete
        cp "$DEBS"/azusa-*.deb "$ISO_ROOT/azusa-debs/"
    fi
    # 给所有启动项的 cmdline 加 autoinstall
    python3 - "$ISO_ROOT" <<'PY'
import pathlib, sys, re
root = pathlib.Path(sys.argv[1])
params = "autoinstall 'ds=nocloud;s=/cdrom/nocloud/' console=ttyS0,115200n8"
changed = []
for cfg in list(root.glob("boot/grub/grub.cfg")) + list(root.glob("isolinux/*.cfg")):
    text = cfg.read_text(errors="replace")
    out = []
    for line in text.splitlines():
        stripped = line.lstrip()
        if re.match(r"(?:linux|linuxefi|append)\s", stripped) and "---" in line and "autoinstall" not in line:
            line = line.replace("---", params + " ---", 1)
        out.append(line)
    cfg.write_text("\n".join(out) + "\n")
    changed.append(cfg.name)
print("  已注入 autoinstall 到:", ", ".join(changed) or "(没找到启动配置)")
PY
    echo "注入完成：$(ls "$ISO_ROOT/azusa-debs" | wc -l) 个 deb"
    ;;
pack)
    bash "$HERE/check-debs.sh" "$ISO_ROOT/azusa-debs"
    python3 "$HERE/write-build-manifest.py" "$SRC_ISO" "$ISO_ROOT/azusa-debs" "$ISO_ROOT/azusa-build.json"
    mkdir -p "$(dirname "$OUT")"
    # 用 -indev/-outdev + -boot_image replay：在原镜像上替换文件，
    # 引导结构由 xorriso 原样复制，不重建 El Torito。
    # grub.cfg is modified too: the original checksum manifest is no longer valid.
    # xorriso rewrites boot-info tables/catalogs while packing, so exclude those
    # generated boot files just as the upstream Ubuntu manifest does.
    (
        cd "$ISO_ROOT"
        find . -type f ! -path './md5sum.txt' ! -path './boot.catalog' \
            ! -path './boot/grub/i386-pc/eltorito.img' \
            ! -path './isolinux/isolinux.bin' -print0 \
            | LC_ALL=C sort -z | xargs -0 md5sum > md5sum.txt
    )
    cp "$ISO_ROOT/boot/grub/grub.cfg" "$WORK/grub-patched.cfg"
    boot_maps=()
    for cfg in "$ISO_ROOT"/isolinux/*.cfg; do
        [ -f "$cfg" ] || continue
        boot_maps+=(-map "$cfg" "/isolinux/$(basename "$cfg")")
    done
    rm -f "$OUT"
    xorriso -indev "$SRC_ISO" -outdev "$OUT" \
        -map "$WORK/grub-patched.cfg" /boot/grub/grub.cfg \
        "${boot_maps[@]}" \
        -update_r "$ISO_ROOT/nocloud" /nocloud \
        -update_r "$ISO_ROOT/azusa-debs" /azusa-debs \
        -map "$ISO_ROOT/md5sum.txt" /md5sum.txt \
        -map "$ISO_ROOT/azusa-build.json" /azusa-build.json \
        -boot_image any replay -commit 2>&1 | tail -2
    ls -lh "$OUT"
    ;;
all) bash "$HERE/check-debs.sh" "$DEBS"; bash "$0" extract; bash "$0" prepare; bash "$0" pack ;;
*) echo "Usage: $0 {extract|prepare|pack|all}" >&2; exit 2 ;;
esac
