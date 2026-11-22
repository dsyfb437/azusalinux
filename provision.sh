#!/usr/bin/env bash
# provision.sh — 把一台干净的 Ubuntu 变成 AzusaLinux
#
# 这是 ISO 的替代方案：不打包镜像，而是在装好的系统上跑一条命令。
# 对自用场景，这比 ISO 更实用——重装系统后一条命令就回来。
#
#   curl -fsSL https://raw.githubusercontent.com/dsyfb437/azusalinux/master/provision.sh | bash
#   # 或者已经 clone 了：
#   ./provision.sh
#
# 幂等：重复跑不会出问题，已完成的步骤会跳过。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(fonts-inter fonts-jetbrains-mono fastfetch papirus-icon-theme git curl)

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

if [ "$(id -u)" -eq 0 ]; then
    bad "不要用 root 直接跑：用户级设置（gsettings）需要普通用户会话"
    exit 1
fi

if [ ! -f "$ROOT/azusa-setup" ]; then
    bad "请在仓库根目录运行（找不到 azusa-setup）"
    exit 1
fi

if [ ! -d /run/user/"$(id -u)" ] || [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    bad "没有 DBus 会话。这个脚本要在图形桌面的终端里跑，不能 SSH。"
    exit 1
fi

su_do() { sudo "$@"; }

say "1/6 安装依赖"
missing=()
for p in "${PACKAGES[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || missing+=("$p")
done
if [ ${#missing[@]} -eq 0 ]; then
    ok "依赖齐全"
else
    ok "安装: ${missing[*]}"
    su_do apt-get update -qq
    su_do DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
fi

say "2/6 生成壁纸"
if [ -f dist/wallpapers/mascot-dark-2880x1800.jpg ]; then
    ok "已存在，跳过"
else
    python3 bin/azusa-mascot
fi

say "3/6 用户级配置（终端 / 字体 / 强调色 / 壁纸 / 图标主题）"
python3 bin/azusa-apply --all --apply

say "4/6 系统级配置（GRUB / 文件夹染色）"
su_do ./bin/azusa-apply --system --apply

say "5/6 系统身份"
su_do ./azusa-setup --apply

say "6/6 工具装进 PATH"
su_do ./install.sh

say "验收"
./bin/azusa-verify || {
    bad "有检查项失败，见上面的红色条目"
    exit 1
}

printf '\n\033[32m完成。\033[0m 重新登录后效果最完整（/etc/issue、字体）。\n\n'
