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
OUT="${OUT:-$ROOT/../build/azusalinux-0.1-amd64.iso}"
ACTION="${1:-all}"

case "$ACTION" in
extract)
    rm -rf "$ISO_ROOT"; mkdir -p "$ISO_ROOT"
    xorriso -osirrox on -indev "$SRC_ISO" -extract / "$ISO_ROOT" 2>&1 | tail -2
    chmod -R u+w "$ISO_ROOT"
    xorriso -indev "$SRC_ISO" -report_el_torito as_mkisofs > "$WORK/eltorito.opts" 2>/dev/null
    echo "解包完成，启动参数存到 work/eltorito.opts"
    ;;
prepare)
    mkdir -p "$ISO_ROOT/nocloud" "$ISO_ROOT/azusa-debs"
    cp "$HERE/nocloud/user-data" "$ISO_ROOT/nocloud/user-data"
    cp "$HERE/nocloud/meta-data" "$ISO_ROOT/nocloud/meta-data"
    cp "$DEBS"/azusa-*.deb "$ISO_ROOT/azusa-debs/"
    # 给所有启动项的 cmdline 加 autoinstall
    python3 - "$ISO_ROOT" <<'PY'
import pathlib, sys, re
root = pathlib.Path(sys.argv[1])
params = "autoinstall ds=nocloud;s=/cdrom/nocloud/"
changed = []
for cfg in list(root.glob("boot/grub/grub.cfg")) + list(root.glob("isolinux/*.cfg")):
    text = cfg.read_text(errors="replace")
    if "autoinstall" in text:
        continue
    out = []
    for line in text.splitlines():
        stripped = line.lstrip()
        if (stripped.startswith("linux") or stripped.startswith("append") or stripped.startswith("linuxefi")) and "---" in line:
            line = line.replace("---", params + " ---", 1)
        out.append(line)
    cfg.write_text("\n".join(out) + "\n")
    changed.append(cfg.name)
print("  已注入 autoinstall 到:", ", ".join(changed) or "(没找到启动配置)")
PY
    echo "注入完成：$(ls "$ISO_ROOT/azusa-debs" | wc -l) 个 deb"
    ;;
pack)
    mkdir -p "$(dirname "$OUT")"
    # eltorito.opts 是带引号的 shell 片段，必须 eval 才不丢引号
    # 原 ISO 的 -e 参数写死了 EFI 分区的起始 LBA；重打包后位置会变，
    # 死偏移会指向错误数据（UEFI 启动报 "can't find command grub_platform"）。
    # 改成让 xorriso 解析实际位置。
    OPTS="$(tr '\n' ' ' < "$WORK/eltorito.opts" | sed -E "s/-e '--interval:appended_partition_2_start_[0-9]+s_size_[0-9]+d:all::'/-e '--interval:appended_partition_2:all::'/")"
    eval "xorriso -as mkisofs $OPTS -V AZUSALINUX -o '$OUT' '$ISO_ROOT'" 2>&1 | tail -3
    ls -lh "$OUT"
    ;;
all) "$0" extract; "$0" prepare; "$0" pack ;;
esac
