# 安装 AzusaLinux 0.1.3 RC1

## 准备虚拟机

| 项目 | VMware Workstation 验证配置 |
| --- | --- |
| 架构 | x86_64（amd64） |
| CPU 和内存 | 2 核、4.5 GiB |
| 磁盘 | 40 GiB 空白虚拟盘 |
| 固件 | BIOS 或 UEFI。UEFI 验收时关闭 Secure Boot |

## 下载并校验

从 [0.1.3 RC1 发布页](https://github.com/dsyfb437/azusalinux/releases/tag/v0.1.3-rc1) 下载全部四个 `azusalinux-0.1.3-rc1-amd64.iso.part-00` 至 `.part-03` 分卷和 `SHA256SUMS`，放入同一目录。在该目录运行以下命令。

### Windows PowerShell

```powershell
cmd /c copy /b azusalinux-0.1.3-rc1-amd64.iso.part-00+azusalinux-0.1.3-rc1-amd64.iso.part-01+azusalinux-0.1.3-rc1-amd64.iso.part-02+azusalinux-0.1.3-rc1-amd64.iso.part-03 azusalinux-0.1.3-rc1-amd64.iso
Get-FileHash .\azusalinux-0.1.3-rc1-amd64.iso -Algorithm SHA256
```

完整 ISO 应为 6,816,071,680 字节，SHA-256 为 `87a01e1e32abb516f57d81e4725ad39454b1e66e6f1996b4fd5b3efb35c4548b`。

### Linux

```bash
cat azusalinux-0.1.3-rc1-amd64.iso.part-{00,01,02,03} > azusalinux-0.1.3-rc1-amd64.iso
sha256sum -c SHA256SUMS
```

所有校验项均显示通过后再启动安装。

## 安装系统

1. 挂载合并后的 ISO 并启动虚拟机，选择 **Try or install AzusaLinux**。
2. 进入 Live 桌面后，在 **AzusaLinux Installer** 选择语言、时区和键盘布局。
3. 在分区页选择空白虚拟盘和 **抹除磁盘**。**确认安装后，该磁盘上的数据会被清除。**
4. 创建自己的账户、密码和主机名。在摘要页核对目标盘，再点击 **安装**。
5. 看到 **安装成功** 后关机，断开虚拟光驱，再从硬盘启动。使用刚创建的账户登录。

## 首次使用

按提示完成 GNOME 初始设置。在 **设置 → 外观 → 强调色** 中选择颜色。确认启用中文输入源后，可以用 Super+Space 切换输入法。

若要使用 Azusa 的 Ptyxis 终端配色，运行 `azusa-apply --terminal --apply`，再重新打开终端。RC1 自带签名软件源，更新方法见[软件更新](updates.md)。

RC1 的验收范围是 VMware 虚拟机。反馈时请附上镜像版本、固件类型、失败步骤与截图或日志。[提交问题](https://github.com/dsyfb437/azusalinux/issues)
