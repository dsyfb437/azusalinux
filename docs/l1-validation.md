# L1 验证记录：AzusaLinux 0.1.1

日期：2026-11-24（Asia/Shanghai）。本次同一镜像的 BIOS、UEFI 全新安装、
禁用光驱后的冷启动及 GNOME 密码登录均通过。安装后升级、再次启动复验也通过，
L1 在下述 VMware 测试范围内完成。

## 镜像与源码

- 文件：`azusalinux-0.1.1-amd64.iso`，6,485,573,632 字节。
- SHA256：`69132f27a2d86410992c079882c6ef56526e27757c5e3b8c8b730c5e086e2f31`。
- 构建源码：`2006d84e14d5abe91912f16cf396d4450529d0b2`，通过 git archive 导出，六个 deb 均为 0.1.1 / all。
- 输入为此前的本地修复镜像，SHA256：`4b8e6b97ed4f64c2643bfcbf1329bdf2db418792ca57633beea644cfe39f5897`。
- `BUILD-MANIFEST.json`（ISO 内为 `/azusa-build.json`）记录输入链、源码和每个包的 SHA256。
- 挂载最终完整 ISO 执行 `md5sum --quiet -c md5sum.txt`，退出码 0。
- 四个发布分卷重新拼接后 SHA256 与完整 ISO 一致；Windows `Merge-ISO.ps1` 也已实际合并并校验通过。

后续提交仅整理文档和下载合并助手，不改变本次镜像内的运行时源码。历史中间镜像的
独立记录见 [本地 0.1 修复镜像](l1-validation-0.1-local.md)，不能混用于本次版本。

## 安装修复

原始 v0.1.0 漏装 azusa-icons，安装末尾 APT 返回 100；其“完整安装已验证”结论撤回。
0.1.1 在目标系统内展开全部 Azusa deb，一次安装六个包。构建前拒绝缺包、重复包、
混合版本、损坏包和错误架构；重复重打包会删除过时注入文件，并重建校验清单。

新增 azusa-release，以包管理的链接和 dpkg-divert 保护四个身份文件。安装器不再使用
旧 azusa-setup 直接覆盖文件。移除身份包会恢复 Ubuntu 原件。

## 同一镜像的完整安装验收

环境：Windows 宿主机、VMware Workstation、各自独立空白 40 GB 虚拟磁盘、
2 vCPU、4 GB RAM、NAT。UEFI 测试关闭 Secure Boot。两台 VM 的光驱在正常关机后
离线设置为 present=FALSE，然后从虚拟硬盘冷启动，不只是在运行时弹出 ISO。

| 项目 | BIOS | UEFI |
|---|---|---|
| 从 ISO 启动并自动分区安装 | 通过 | 通过 |
| 安装器及五条 late-commands 全部 SUCCESS | 通过 | 通过 |
| 安装后自动重启、硬盘启动 | 通过 | 通过 |
| 正常关机、禁用光驱后冷启动 | 通过 | 通过 |
| 根分区为硬盘 ext4/LVM，块设备无光驱 | 通过 | 通过 |
| 实际固件类型 | 无 /sys/firmware/efi | 存在 EFI、/boot/efi 为 vfat |
| 默认账号 azusa / azusa 串口及图形密码登录 | 通过 | 通过 |
| GNOME Wayland 会话 active | 通过 | 通过 |
| 六个 Azusa 包均为 0.1.1、install ok installed | 通过 | 通过 |
| 系统身份 VERSION_ID=0.1.1、ID=azusalinux | 通过 | 通过 |
| GRUB 系统菜单为 AzusaLinux GNU/Linux | 通过 | 通过 |
| tests/verify-installed.sh | 22 PASS，0 FAIL | 22 PASS，0 FAIL |
| 系统级失败服务 | 0 | 0 |

安装器完成时间（原始日志 UTC）：UEFI 07:16:33，BIOS 07:17:58；对应北京时间
15:16:33、15:17:58。首次硬盘启动内核均为 7.0.0-44-generic。

22 项检查覆盖身份、主机名、六个包、图形目标、强调色、深色模式、字体设置与实际
fontconfig 解析、图标主题、两套壁纸、图标链接，以及三个工具的真实执行。
额外在 UEFI 桌面的 GTK4 输入框中用 Super+Space 切换默认输入源，再按键输入
nihao 并选词，实际得到“你好”；有截图与输入框内容文件佐证，未使用剪贴板注入中文。

## 升级与构建回归

- 九项 Linux 回归测试通过，包含真实 xorriso 小型 BIOS 引导 ISO 往返、旧文件删除和校验清单验证。
- 六包 dpkg-buildpackage 构建和 GitHub Actions 构建/测试通过。
- 在可丢弃的 Ubuntu 基线虚拟机中，身份包安装/升级、base-files 重装保护、重复安装、
  移除恢复四个厂商原件的字节内容、purge 后重新安装及 apt check 均通过。
- 安装后的 UEFI 执行 apt-get update 与常规 upgrade：112 个包升级，0 个保留、0 个移除。
- 再重装 base-files，四个身份文件 SHA256 全部保持一致，apt check 通过，dpkg --audit 无输出。
- 升级后再次重启并完成串口/图形密码登录，22 项检查再次全部通过，系统级失败服务仍为 0。
- 实际打开 Ptyxis 后执行 azusa-apply --terminal --apply 成功，调色板已写入并选中 azusa。

## 证据与边界

本机证据目录：`D:\azusalinux-0.1.1-tests\evidence`；保留两套安装器 info/debug 日志、
串口记录、22 项检查、无光驱冷启动证明、升级日志和桌面/中文输入截图。
发布附件包含镜像分卷、SHA256SUMS、六包压缩包、构建清单、合并助手与验证记录。

验收机启用了串口 getty，额外安装 python3-evdev，并运行临时 GTK 输入测试程序以自动
验证图形交互；这些是测试配置，未加入 ISO。Live 会话在安装后重启时曾等待约 90 秒
结束用户会话，随后自行完成重启，未通过强制复位跳过安装。

未覆盖实体机、Secure Boot 开启、专有显卡、多显示器、实际声音输出等硬件测试。
仍保留 Ubuntu 安装器、登录界面及首次设置中的部分上游标识；首次设置不是 Azusa 专属界面。
UEFI 的 NVRAM 启动项和 EFI 文件路径保留上游 Ubuntu 命名，GRUB 系统菜单显示 AzusaLinux。
Ptyxis 调色板仍需 `azusa-apply --terminal --apply` 手动选择，未声明自动选择已完成。

0.1.1 定位为经过上述虚拟机测试的 L1 测试版，不以此代表所有硬件环境兼容。
