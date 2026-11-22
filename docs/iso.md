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
