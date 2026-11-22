#!/usr/bin/env bash
# build.sh — 用 live-build 构建 AzusaLinux ISO
#
#   ./iso/build.sh config    # 生成配置（快，几秒）
#   ./iso/build.sh build     # 开始构建（慢，首次要下载 ~1G）
#
# 注意 --security false：live-build 默认给 Debian 系加油 security.debian.org，
# 但发行版是 Ubuntu，那个源对 resolute 会 404，导致构建在 apt update 阶段失败。
#   ./iso/build.sh clean     # 清理
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="$HERE/work"
ACTION="${1:-build}"

case "$ACTION" in
  clean)
    # 必须清空 work 下所有东西，包括 .build 阶段标记——只删 chroot 会留下
    # "bootstrap 已完成" 的假象，导致后续步骤对着不存在的目录操作。
    # 唯一的例外是 cache/（已下载的 deb 包），留着能省时间。
    if [ -d "$WORK/cache" ]; then
        mv "$WORK/cache" "$WORK.cache.keep"
    fi
    rm -rf "$WORK"
    mkdir -p "$WORK"
    if [ -d "$WORK.cache.keep" ]; then
        mv "$WORK.cache.keep" "$WORK/cache"
    fi
    echo "已清空 work（保留 cache）"
    exit 0
    ;;
esac

mkdir -p "$WORK"
cd "$WORK"

if true; then   # 总是重跑：否则改了参数但 auto/config 已存在时不会生效
    lb config noauto \
        --mode ubuntu \
        --distribution resolute \
        --architectures amd64 \
        --binary-images iso-hybrid \
        --archive-areas "main restricted universe multiverse" \
        --mirror-bootstrap https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ \
        --mirror-chroot   https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ \
        --mirror-binary   https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ \
        --apt-indices false \
        --debian-installer false \
        --memtest none \
        --security false \
        --bootappend-live "boot=live components hostname=azusalinux username=azusa locales=zh_CN.UTF-8" \
        --iso-application "AzusaLinux" \
        --iso-publisher "azusa https://azusaaa.com" \
        --iso-volume "AZUSALINUX"
    echo "配置已生成：$WORK/config"
fi

# 每次构建前同步资源：品牌文件 + 构建期 hook
rm -rf config/includes.chroot/usr/share/azusalinux
mkdir -p config/includes.chroot/share
rm -rf config/includes.chroot/share/azusalinux
ln -sfn /usr/share/azusalinux config/includes.chroot/share/azusalinux
mkdir -p config/includes.chroot/usr/share/azusalinux
cp -a "$ROOT/branding" config/includes.chroot/usr/share/azusalinux/
cp -a "$ROOT/vendor" config/includes.chroot/usr/share/azusalinux/
cp -a "$ROOT/dist/wallpapers" config/includes.chroot/usr/share/azusalinux/
cp -a "$ROOT/bin" config/includes.chroot/usr/share/azusalinux/
cp "$ROOT/azusa-setup" config/includes.chroot/usr/share/azusalinux/
mkdir -p config/package-lists
cp "$HERE/packages.list.chroot" config/package-lists/azusa.list.chroot
mkdir -p config/hooks/normal
cp "$HERE/hooks/010-branding.hook.chroot" config/hooks/normal/
chmod +x config/hooks/normal/*.hook.chroot

if [ "$ACTION" = "config" ]; then
    echo "配置完成，未构建"
    exit 0
fi

lb build 2>&1 | tee "$HERE/build.log"
