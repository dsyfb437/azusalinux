# 在 Ubuntu 上安装桌面软件包

适用于已有的 Ubuntu 26.04 系统。此方式安装 Azusa 的身份、桌面设置和资源，
不需要重新安装操作系统。Release 主要提供安装镜像；deb 包从源码构建。

## 构建

在 Linux 中获取源码并安装构建依赖：

```bash
sudo apt-get update
sudo apt-get install -y build-essential debhelper dpkg-dev python3-pil
git clone https://github.com/dsyfb437/azusalinux.git
cd azusalinux
dpkg-buildpackage -b -us -uc
```

生成的 deb 位于源码目录的上一级。六个包应为同一版本：

| 包 | 内容 |
|---|---|
| azusa-desktop | 桌面元包 |
| azusa-release | 系统身份与登录横幅 |
| azusa-tools | 命令行与配置工具 |
| azusa-artwork | 壁纸 |
| azusa-settings | GNOME 默认设置和终端资源 |
| azusa-icons | 系统与桌面图标、Papirus 文件夹和 GNOME 强调色联动 |

## 安装与应用

在源码目录运行：

```bash
sudo apt install ../azusa-*.deb
```

`azusa-release` 会更改系统身份并保留 Ubuntu 原始文件。桌面默认值对新用户生效；
已有用户可在桌面会话中应用设置：

```bash
azusa-apply --all --apply
```

工具在修改已有用户配置前创建备份。Ptyxis 配色需要先打开终端，让默认配置档生成。

## 卸载

```bash
sudo apt purge azusa-desktop azusa-settings azusa-artwork azusa-tools azusa-icons azusa-release
```

移除 `azusa-release` 会恢复 Ubuntu 身份文件。已通过 `azusa-apply` 写入的用户配置
不由 APT 卸载自动撤销；修改前的备份位于 `~/.local/state/azusalinux/backup`。
