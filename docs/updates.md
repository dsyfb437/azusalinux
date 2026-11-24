# 软件更新

Azusa 软件源提供 AzusaLinux 自己维护的 Debian 软件包。Ubuntu 软件源继续提供基础系统更新。
适用于使用 Ubuntu 26.04（`resolute`）底座的 AzusaLinux amd64 系统。

## 接入软件源

在 AzusaLinux 0.1.1 上执行一次。命令会核对完整公钥指纹，再为 Azusa 软件源配置独立的公钥。

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
apt policy azusa-tools
sudo apt upgrade
azusa-fetch --version
```

首次更新将六个 Azusa 包从 0.1.1 升级到 0.1.2。升级后，上述最后一条命令输出 `azusa-fetch 0.1.2`。

## 暂停 Azusa 更新

在 `/etc/apt/sources.list.d/azusalinux.sources` 中添加 `Enabled: no`，然后运行 `sudo apt update`。
重新启用时，将该行改为 `Enabled: yes`。
