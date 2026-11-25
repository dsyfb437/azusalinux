# 软件更新

Azusa 软件源提供 AzusaLinux 自己维护的 Debian 软件包。Ubuntu 软件源继续提供基础系统更新。
适用于使用 Ubuntu 26.04（`resolute`）底座的 AzusaLinux amd64 系统。

## 接入软件源

通过 0.1.3 RC1 或 RC2 镜像安装的系统已配置 Azusa 签名软件源，可以直接进入「安装更新」。如果你从 0.1.1 安装且未接入过软件源，请执行下面的命令。它会核对完整公钥指纹，再为该软件源配置独立公钥。

```bash
(
    set -eu
    work="$(mktemp -d)"
    trap 'rm -f -- "$work/key.asc" "$work/azusalinux.sources"; rmdir -- "$work"' EXIT
    key="$work/key.asc"
    wget --quiet --output-document="$key" \
        https://azusaaa.com/azusalinux/azusalinux-archive-keyring.asc
    fingerprint="$(gpg --batch --show-keys --with-colons "$key" |
        awk -F: '$1 == "fpr" { print $10 }')"
    test "$fingerprint" = 32DF539D4579C82035D6ACFB7B9B18288ACC3AEB
    cat > "$work/azusalinux.sources" <<'EOF'
Types: deb
URIs: https://azusaaa.com/azusalinux/
Suites: resolute
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/azusalinux-archive-keyring.asc
EOF
    sudo install -D -m 0644 "$key" /etc/apt/keyrings/azusalinux-archive-keyring.asc
    sudo install -m 0644 "$work/azusalinux.sources" /etc/apt/sources.list.d/azusalinux.sources
)
```

## 安装更新

```bash
sudo apt update
sudo apt install azusa-desktop azusa-settings azusa-artwork azusa-tools azusa-icons azusa-release
azusa-fetch --version
```

RC1 和 RC2 的 Azusa 软件包版本均为 0.1.3，升级后应看到 `azusa-fetch 0.1.3`。重新登录 GNOME 后，可以在「设置 → 外观」中体验图标换色。

## 暂停 Azusa 更新

在 `/etc/apt/sources.list.d/azusalinux.sources` 中添加 `Enabled: no`，然后运行 `sudo apt update`。
重新启用时，将该行改为 `Enabled: yes`。
