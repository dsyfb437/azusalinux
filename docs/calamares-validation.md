# Calamares 安装验收

2026-11-24 在 VMware Workstation 上用同一张 amd64 候选镜像完成以下验收。
镜像为 `azusalinux-calamares-rc2-amd64.iso`，大小 6,815,154,176 字节，
SHA256 为 `794e640915a2d72868cfe18f49ffdb5283a7ff9f7d2ff485aa06bf2b9ebbce4d`。
两台虚拟机均使用 2 个 vCPU 和 4.5 GiB 内存。UEFI 测试关闭了 Secure Boot。

| 验收项 | BIOS 双盘 | UEFI 单盘 |
| --- | --- | --- |
| 安装布局 | 第一块为 24 GiB 保护盘。选择第二块 35 GiB 空盘，创建 MBR 分区表和 ext4 根分区 | 在 35 GiB 空盘上创建 GPT、EFI 系统分区和 ext4 根分区 |
| 引导位置 | 摘要列出 `/dev/sdb`，实际执行 `grub-install --target=i386-pc --recheck --force /dev/sdb` | 固件启动项指向 ESP 上的 `\EFI\AzusaLinux\grubx64.efi`，同时存在回退文件 `\EFI\BOOT\BOOTX64.EFI` |
| 自定义账户与主机名 | `maple` / `azusa-bios-test` | `solstice` / `azusa-efi-test` |
| 安装后的语言与键盘 | `zh_CN.UTF-8`，中国布局 `cn` | `en_US.UTF-8`，英国布局 `gb` |
| 关机后从硬盘启动 | 断开光驱和第一块盘，仅保留原第二块盘。用 `maple` 的密码成功登录中文 GNOME 桌面 | 断开光驱，仅保留系统盘。用 `solstice` 的密码成功登录英文 GNOME 桌面 |

两套系统均保留所选的 `Asia/Shanghai` 时区。各自的 GRUB 内核参数和 fstab
都使用目标根分区的 UUID。六个 Azusa 软件包均为已安装的 0.1.2，
`azusa-fetch --version` 返回 0.1.2，Azusa APT 源的 `Signed-By` 指向已安装的公钥。
两套系统的首次登录向导均显示 AzusaLinux 0.1.2，登录前的 GDM 界面仍显示 Ubuntu 标识。

## BIOS 取消安装与保护盘校验

在图形摘要页取消安装并返回 Live 桌面后，重新读取两块虚拟盘及保护盘上的标记文件。
随后重新打开安装器，选择相同的第二块盘完成安装，再次读取保护盘和标记文件。

| 校验对象 | 安装前的 SHA256 | 取消后 | 完成安装后 |
| --- | --- | --- | --- |
| 第一块盘（整盘） | `dfe78da847103e8811608def8f5ef8322b3a77c916ce537a9e68ddd9bc994cbd` | 相同 | 相同 |
| 第一块盘的标记文件 | `739486019f2957ddd9a72acccdb9a0c9e3a8f125963d77612a6aa2c2153eb1fe` | 相同 | 相同 |
| 第二块盘（整盘） | `622e4f287f9840f147bc9e07594c3f01226338d6a609c58017c00d629434bc2d` | 相同 | 已安装系统 |

## 构建校验

最终 ISO 的文件校验清单全部通过。Live 层的分区模块与基于 Ubuntu Calamares
`3.3.14-0ubuntu25.26.04.1` 源码编译出的模块逐字节一致。
仓库已有的 9 项 ISO 重制回归测试全部通过。
