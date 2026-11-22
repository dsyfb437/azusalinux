# ISO：官方镜像 + 自动安装

## 思路

不做「从零构建 rootfs」，而是**重打包官方 Ubuntu ISO**，在里面塞两样东西：

1. `/nocloud/user-data` —— autoinstall 配置（主机名、用户、late-commands）
2. `/azusa-debs/` —— 我们的四个 deb

启动参数追加 `autoinstall ds=nocloud;s=/cdrom/nocloud/`，安装器就会无交互装完系统，
最后在 `late-commands` 里 `apt install` 我们的包。

好处：**用的是官方安装器和官方包仓库**，不是自制 install 逻辑。

## 构建

```bash
# 1. 下载官方 ISO（6.2G）并校验
curl -O https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/26.04.1/ubuntu-26.04.1-desktop-amd64.iso
sha256sum -c  # 对比 SHA256SUMS

# 2. 解包 → 注入 → 重打包
cd iso-remaster
SRC_ISO=.../ubuntu-26.04.1-desktop-amd64.iso DEBS=/tmp/azusa-debs ./build.sh all
```

产物 `build/azusalinux-0.1-amd64.iso`，卷标 `AZUSALINUX`。

## 关键实现点

- **El Torito 参数**从原 ISO 反向导出：`xorriso -report_el_torito as_mkisofs`，
  重打包时原样使用，保证 BIOS + EFI 双启动都能引导。
- 该参数是多行、带引号的 shell 片段，**必须先合并成一行再 eval**，
  否则每一行会被当成独立命令。
- 只往 ISO 里**加文件**，不动 `casper/filesystem.squashfs`，所以 `md5sum.txt` 仍然有效。
- `nocloud` 的两个文件要**分别 cp**，用一条 cp 传两个源时曾出现只拷进去一个。

## 安装后的状态

autoinstall 的 `late-commands` 会：

```
cp -r /cdrom/azusa-debs /target/root/azusa-debs
curtin in-target -- apt-get update
curtin in-target -- apt-get install -y /root/azusa-debs/*.deb
rm -rf /root/azusa-debs
```

装出来的系统：主机名 `azusalinux`，用户 `azusa`（密码 `azusa`），
四个包已安装，新用户登录即是紫色强调色 + Inter 字体 + Azusa 壁纸。

## 还没做的

- 桌面首次登录会走 GNOME 初始设置，壁纸/强调色要重新登录一次才完全生效
- 紫色文件夹图标仍是 `papirus-folders` 手工染色，干净安装不会带上（B4 未做）
- 安装器界面是英文（subiquity 的 locale 不影响安装界面语言）

## 两个已修的坑（都是实测暴露的）

### EFI 分区偏移

原 ISO 的 `-e` 参数写死了 EFI 分区的起始 LBA（`appended_partition_2_start_3162499s`）。
重打包后 ISO 变大，EFI 分区实际落到 LBA 3163984，死偏移就指向了错误数据，
UEFI 启动报 `can't find command 'grub_platform'`，而 **BIOS 启动正常**——
所以只要不测 UEFI 就发现不了。

修法：把 `-e` 换成 `--interval:appended_partition_2:all::`，让 xorriso 自己解析实际位置。

### 紫色文件夹（B4）

`papirus-folders` 是直接改 `papirus-icon-theme` 包里的文件，升级即还原。
改成独立主题 `Azusa-Papirus`：

- `Inherits=Papirus-Dark,Papirus,Adwaita,hicolor`
- 只在 5 个尺寸的 `places/` 下放 385 个相对软链，指向 Papirus 自带的 violet 变体
- 命名是**前缀式**（`folder-violet-documents.svg`），不是后缀式——第一版全拼错，405 个里只有 1 个能解析
- 有 4 个名字（`folder-violet-desktop` 等）在 Papirus 里没有对应变体，已从清单剔除
- 包只有 4.6 KB

## 当前状态

| 项 | 状态 |
|---|---|
| ISO 能打出来 | ✅ 6.1G，含 5 个 deb + autoinstall seed |
| BIOS 启动 | ✅ 用户已在 VMware 里装成功 |
| UEFI 启动 | ✅ 内核启动、autoinstall 参数传入（QEMU + OVMF 实测） |
| autoinstall 触发 | ✅ cmdline 里有 `autoinstall ds=nocloud;s=/cdrom/nocloud/`，cloud-init 服务启动 |
| 无人值守安装到完成 | ⚠️ **未在本机 QEMU 跑完**：机器负载过高后关机中断 |

### 为什么没跑完完整安装

本机只有 11G 内存，QEMU 里同时跑 6G ISO + 4G 虚拟机和构建任务时会把宿主机拖到卡死。
关掉完整安装测试是对的。**用 VMware 装机验证更省资源**：分配 4G 内存、
20G 磁盘、固件选 BIOS，从 ISO 启动后会自动进入安装流程。

### 排查记录：一个让我误判很久的坑

前面的结论一度写成「UEFI 启动失败，内核起不来」。**那是错的。**

真实情况：内核一直在正常启动，但官方 ISO 的 cmdline 带 `quiet`，
内核日志被压掉，而**官方 ISO 本来也不把日志输出到串口**。
我拿「串口没有输出」当成了「没有启动」，于是把引导链上每一环都怀疑了一遍。

定位方法：在 `grub.cfg` 的菜单项里插 `echo`，确认 `linux` / `initrd` 命令
返回正常（A/B/C/D 四个标记都打印出来），再把 `quiet splash` 换成 `loglevel=7`
——内核日志立刻出现在串口里。

教训：**静默不等于失败**。调试启动问题，先确保你有一条能看见的通道
（`console=ttyS0` + `loglevel=7`），再去怀疑别的。

### 关于 `ds=nocloud;s=...` 里的分号

一度怀疑 GRUB 把 `;` 当命令分隔符、截断了后面的 `console=` 参数。
实测：加不加引号，内核 cmdline 里 `ds=nocloud;s=/cdrom/nocloud/` 都完整保留，
后面参数也都在。**分号不是问题**。引号保留着无害，但不必要。
