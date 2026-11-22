# AzusaLinux

一个基于 Ubuntu 26.04 的个人桌面发行版。

保留 Ubuntu 的整个生态（apt、PPA、deb、Flatpak 全都能用），换掉默认的身份、配色、
字体、图标、壁纸和终端体验。

![AzusaLinux](branding/mascot/azusa-v1.png)

## 下载

最新镜像见 [Releases](https://github.com/dsyfb437/azusalinux/releases)。

因为 GitHub 单个附件上限 2GB，6.1G 的镜像分成 4 卷发布：

```bash
cat azusalinux-0.1-amd64.iso.part-* > azusalinux-0.1-amd64.iso
sha256sum -c SHA256SUMS
```

## 安装

1. 新建虚拟机：**4G 内存、20G 磁盘、固件类型选 BIOS**（UEFI 也能启动，但安装流程只在 BIOS 下验证过）
2. 挂载 ISO 启动
3. 安装是全自动的（Ubuntu autoinstall）：自动分区、建用户、装系统
4. 装完后登录：用户 `azusa`，密码 `azusa`

> 安装过程会联网下载软件包，请确保虚拟机可以访问网络。

也可以用物理机/U 盘安装。装完是一个标准的 Ubuntu 桌面，只是默认值换成了 Azusa 的。

## 系统里有什么

| 层 | 内容 |
|---|---|
| 身份 | `/etc/os-release`、`lsb-release`、登录横幅都是 AzusaLinux |
| 桌面 | GNOME（`ubuntu-desktop-minimal` 基线） |
| 配色 | 紫色强调色 `#70577f`、深色模式默认开启 |
| 字体 | 界面 Inter 11，等宽 JetBrains Mono 11 |
| 图标 | `Azusa-Papirus`：Papirus-Dark + 紫色文件夹 |
| 壁纸 | 萌系吉祥物，明暗两套，6 种分辨率 |
| 终端 | Ptyxis 配色（可手动应用），kitty / foot 配置随包提供 |
| 命令行 | `azusa-fetch`：终端里显示吉祥物和系统信息 |

配色不是随手挑的：从 8 张参考立绘里采样 48.75 万像素统计出来的，
紫色只占 3% 但它是识别色。详见 [docs/color.md](docs/color.md)。

## 也可以只装在现有 Ubuntu 上

不想重装系统的话，把包装到现有 Ubuntu 26.04 上：

```bash
sudo apt install ./azusa-desktop_*.deb ./azusa-*.deb
```

这只会影响**新用户**的默认值，不会改你当前的设置。要对当前用户生效：

```bash
azusa-apply --all --apply        # 终端、字体、强调色、壁纸、图标
sudo azusa-apply --system --apply # GRUB 配色、文件夹颜色
```

卸载：`sudo apt purge azusa-desktop azusa-settings azusa-artwork azusa-tools azusa-icons`

## 已知限制

- **安装过程未在本机完整跑完**：宿主机内存不足会卡死，只在 VMware 里验证过装机成功
- 安装器界面是英文（subiquity 的界面语言不受 autoinstall 的 locale 影响）
- 首次登录会走 GNOME 初始设置，壁纸/强调色可能要重新登录一次才完全生效
- 终端配色（Ptyxis）需要手动跑一次 `azusa-apply --terminal`
- 不含专有显卡驱动的自动配置

## 系统要求

- x86_64
- 4G 内存（安装时）、2G 内存（使用）
- 20G 磁盘
- 安装时需要网络

## 开发

- 项目结构与设计取舍：[docs/development.md](docs/development.md)
- ISO 怎么打出来的：[docs/iso.md](docs/iso.md)
- 配色来源：[docs/color.md](docs/color.md)

## 许可

代码与吉祥物图片均为 MIT。底层的 Ubuntu 组件遵循各自的许可证。

吉祥物是 AI 生成的原创角色，不是任何既有作品的衍生，来源见
[branding/mascot/SOURCES.md](branding/mascot/SOURCES.md)。
