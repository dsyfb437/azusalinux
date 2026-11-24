# AzusaLinux

AzusaLinux 是基于 Ubuntu 26.04 的个人桌面发行版，提供 GNOME 桌面与统一的紫色视觉风格。

![AzusaLinux 桌面](docs/images/desktop.png)

## 特色

- 紫色强调色、深色模式与 Azusa 吉祥物壁纸。
- Inter 界面字体、JetBrains Mono 等宽字体。
- 基于 Papirus 的图标主题与紫色文件夹。
- 中文界面与拼音输入支持。
- 使用 APT 和 deb 软件包管理，兼容 Ubuntu 软件源。

## 下载与安装

[下载 v0.1.1 测试版](https://github.com/dsyfb437/azusalinux/releases/tag/v0.1.1) · [安装指南](docs/installation.md)

镜像分为四个文件，需全部下载、合并并校验后使用。Windows 用户可使用发布页中的合并助手。

当前建议在空白虚拟机中安装：x86_64、2 核 CPU、4 GB 内存、40 GB 磁盘，安装时需要联网。
支持 BIOS 和 UEFI；UEFI 测试时关闭 Secure Boot。

**安装会自动分区。请勿连接需要保留数据的磁盘。**
默认用户和密码均为 `azusa`，登录后请修改密码。

## 版本状态

v0.1.1 为测试版，已通过 VMware 中的 BIOS、UEFI 安装及启动验证。
实体机兼容性尚未验证，部分界面保留 Ubuntu 标识。
Ptyxis 终端配色需要手动应用，详见[安装指南](docs/installation.md#首次使用)。

## 文档

[文档目录](docs/README.md) · [构建指南](docs/iso.md) · [验证报告](docs/l1-validation.md) · [问题反馈](https://github.com/dsyfb437/azusalinux/issues)

## 许可

本项目代码与原创吉祥物使用 MIT 许可；Ubuntu 和其他上游组件遵循各自的许可证。
吉祥物来源见[素材说明](branding/mascot/SOURCES.md)。
