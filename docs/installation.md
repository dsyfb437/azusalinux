# 下载与安装

## 系统要求

| 项目 | 验证配置 |
|---|---|
| 架构 | x86_64（amd64） |
| CPU | 2 核 |
| 内存 | 4 GB |
| 磁盘 | 独立空白磁盘，40 GB |
| 固件 | BIOS 或 UEFI；UEFI 关闭 Secure Boot |
| 网络 | 安装期间需要联网 |

当前版本已在 VMware Workstation 中验证。实体机、Secure Boot 开启、专有显卡、
多显示器和实际声音输出尚未验证。

## 下载文件

前往 [v0.1.1 发布页](https://github.com/dsyfb437/azusalinux/releases/tag/v0.1.1)，下载：

| 文件 | 用途 |
|---|---|
| `azusalinux-0.1.1-amd64.iso.part-00` 至 `.part-03` | 同一 ISO 的四个分卷，必须全部下载 |
| `SHA256SUMS` | 完整 ISO 和四个分卷的 SHA256 |
| `Merge-ISO.ps1` | Windows 合并与校验助手，可选 |

GitHub 单个附件大小限制使镜像需要分卷。

## 合并与校验

将同一版本的四个分卷放在一个目录中。不要混用不同版本的文件。

### Windows

将 `Merge-ISO.ps1` 放在分卷所在目录，在该目录打开 PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Merge-ISO.ps1
```

脚本生成 `azusalinux-0.1.1-amd64.iso` 并校验完整镜像。已有同名 ISO 时会停止，
以免覆盖文件。

### Linux

```bash
cat azusalinux-0.1.1-amd64.iso.part-{00,01,02,03} > azusalinux-0.1.1-amd64.iso
sha256sum -c SHA256SUMS
```

所有校验项应显示 OK。完整镜像为 6,485,573,632 字节，SHA256：

```text
69132f27a2d86410992c079882c6ef56526e27757c5e3b8c8b730c5e086e2f31
```

## 安装步骤

**安装器会自动分区。仅连接准备安装系统的空白虚拟磁盘。**

1. 按上述配置创建虚拟机，网络使用 NAT 或其他可联网方式。
2. 将合并后的 ISO 挂载到虚拟光驱并启动。
3. 选择默认的安装启动项，等待自动安装和更新完成。安装器界面保留 Ubuntu 标识。
4. 安装完成后，取消挂载 ISO，从虚拟硬盘启动。
5. 使用 `azusa` / `azusa` 登录，然后运行 `passwd` 修改密码。

安装结束后的首次重启可能需要等待 Live 会话退出；不要在安装器仍工作时强制关闭虚拟机。

## 首次使用

按提示完成 GNOME 初始设置。默认桌面使用深色模式、紫色强调色、Azusa 壁纸和图标主题。
可通过 Super+Space 在英文键盘和拼音输入源之间切换。

需要使用 Azusa 的 Ptyxis 终端配色时，打开终端运行：

```bash
azusa-apply --terminal --apply
```

重新打开终端窗口以使用新配色。

## 问题反馈

提交 [Issue](https://github.com/dsyfb437/azusalinux/issues) 时，请附上镜像版本、
虚拟机或硬件配置、固件类型、失败步骤与相关日志。
版本测试详情见 [0.1.1 验证报告](l1-validation.md)。
