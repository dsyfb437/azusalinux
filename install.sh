#!/usr/bin/env bash
# install.sh — 把 azusa 工具装进 PATH
#
#   ./install.sh            # 装到 /usr/local（需要 sudo）
#   PREFIX=~/.local ./install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/usr/local}"

# 装到 /usr/local 必须有 root；早点说清楚，别让人看到 install 的报错才反应过来
if [ "$PREFIX" = "/usr/local" ] && [ "$(id -u)" -ne 0 ]; then
    echo "install.sh: 装到 /usr/local 需要 root" >&2
    echo "  sudo ./install.sh" >&2
    echo "或者装到用户目录（确保 ~/.local/bin 在 PATH）:" >&2
    echo "  PREFIX=\$HOME/.local ./install.sh" >&2
    exit 1
fi
SHARE="$PREFIX/share/azusalinux"

install -d "$PREFIX/bin" "$SHARE"
install -m 0755 "$ROOT"/bin/* "$PREFIX/bin/"
# 手滑写 azusafetch 也能用
ln -sf "$PREFIX/bin/azusa-fetch" "$PREFIX/bin/azusafetch"
rm -rf "$SHARE/branding"
cp -a "$ROOT/branding" "$SHARE/"

echo "已安装到 $PREFIX/bin:"
ls -1 "$PREFIX/bin" | grep '^azusa-' | sed 's/^/  /'
echo
echo "资源目录：$SHARE"
echo "打开新终端后可以直接运行 azusa-fetch"
