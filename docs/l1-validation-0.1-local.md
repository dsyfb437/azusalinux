# 历史记录：本地 0.1 修复镜像

此记录针对旧的本地中间镜像；当前 0.1.1 的包数量、身份保护与验收结果以
[L1 验证记录](l1-validation.md) 为准。

日期：2026-11-24（Asia/Shanghai）。环境：Windows 宿主机、VMware Workstation、
BIOS、2 vCPU、4 GB 内存、40 GB 独立空白虚拟磁盘、NAT 网络。

## 原始 v0.1.0 镜像

SHA256：`2e71f303ce260931517bbf5a3a4757e3384ff69a6c64f79f120d3564e4b5ff17`。

实测可启动 Live 桌面，并完成分区、系统复制、用户创建、中文支持和系统更新。
安装末尾失败，APT 返回 100：

```text
azusa-settings : Depends: azusa-icons but it is not installable
```

五个 deb 都已复制到目标系统，但安装命令只指定了四个，遗漏图标包。
因此旧版“完整安装成功”的文档结论撤回，不以此前的启动测试代表 L1 完成。

## 修复与回归检查

- 由目标系统中的 shell 展开所有 Azusa deb，一次安装完整包集。
- 构建前校验五个必要包、重复版本、包格式和架构。
- 重复准备镜像时清理旧包，并逐条检查启动项。
- 更新被修改文件的校验值，避免沿用失效清单。
- 在 ISO 安装末尾执行身份脚本，并重新生成 GRUB。
- 八项 Linux 回归测试通过，包括使用真实 xorriso 构建、解包并校验一个小型引导镜像。

最终候选镜像：`azusalinux-0.1-l1-amd64.iso`，6,485,473,280 字节。
SHA256：`4b8e6b97ed4f64c2643bfcbf1329bdf2db418792ca57633beea644cfe39f5897`。
它基于原镜像使用 xorriso replay 重新打包，包含当前源码中的安装配置和身份脚本；
已有五个 deb 保持原样。先前仅修复包安装命令的中间镜像不作为最终交付。

## 最终镜像的完整验收结果

**L1 在 VMware + BIOS 环境通过。** 安装器于 2026-11-24 04:00:53（Asia/Shanghai）
记录 `subiquity/Install/install: SUCCESS`；原始日志采用 UTC，对应 11 月 23 日 20:00:53。

| 项目 | 实测结果 |
|---|---|
| 镜像内安装配置和身份脚本与源码一致 | 通过 |
| 安装器镜像完整性校验 | 通过，无校验不一致文件 |
| 从空白 40 GB 磁盘自动安装 | 通过，所有 late-commands 成功 |
| 五个 Azusa deb | 全部 `install ok installed` |
| `os-release` | `ID=azusalinux`，`UBUNTU_CODENAME=resolute` |
| GRUB | 菜单项为 `AzusaLinux GNU/Linux` |
| 安装后自动重启 | 从虚拟硬盘启动成功 |
| 正常关机、完全禁用虚拟光驱后冷启动 | 通过；块设备列表没有光驱，根为硬盘上的 ext4/LVM |
| `azusa` / `azusa` 密码登录 | 串口登录、GNOME 图形登录均通过 |
| 图形会话 | Wayland，`State=active` |
| 独立安装验收脚本 | 21 项通过，0 项失败 |
| 系统级失败服务 | 0 |

21 项检查覆盖身份、主机名、五个包、图形目标、强调色、深色模式、字体设置和实际
字体解析、图标主题、两套壁纸文件、图标链接，以及三个工具的真实执行。
新用户首次登录仍显示 Ubuntu 上游的初始设置向导，欢迎标题正确读取 AzusaLinux 身份。

验收机额外启用了串口 getty，并安装 `python3-evdev` 以自动输入图形登录密码；
这些是测试环境配置，交付 ISO 未加入这两个测试步骤。
本机保留 `regression-tests.txt`、`installed-checks.txt`、`final-proof.txt`、`serial.log`
和 `desktop.png`，可与镜像 SHA256 对照复查。

## 尚未覆盖

- UEFI 完整安装、物理机、专有显卡驱动及多显示器等硬件组合。
- 后续 `base-files` 升级对系统身份文件的影响，仍需持久化身份包或 diversion 处理。
- Ptyxis 调色板自动选择，当前仍沿用手动应用方式。
- GitHub Release 的旧附件未替换；本次修复镜像先保存在本地。
