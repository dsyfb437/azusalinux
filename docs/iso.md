# ISO 构建

两个构建入口都基于官方 Ubuntu Desktop ISO，用 xorriso 保留 BIOS 和 UEFI 引导结构。

## Calamares 交互式安装镜像

开发版从 Live 桌面打开 AzusaLinux 安装器。安装器在用户确认后写盘，
目标系统包含 GNOME、六个 Azusa 软件包以及签名 APT 源。安装所需文件都在镜像内。

在 BIOS 模式选择“抹除磁盘”时，安装器将系统和 GRUB 写入同一块选定磁盘。
写盘前可在摘要中核对磁盘设备名。测试布局、保护盘校验和固件配置见
[Calamares 安装验收](calamares-validation.md)。

在独立的 Ubuntu 26.04 amd64 构建机上，给 Ubuntu 主仓库及更新仓库启用源码索引
（在 `ubuntu.sources` 对应的 `Types` 行使用 `deb deb-src`），然后安装构建依赖。

```bash
sudo apt-get update
sudo apt-get install build-essential xorriso squashfs-tools dpkg-dev util-linux patch
sudo apt-get build-dep calamares
```

构建脚本取得与 Live 安装器相同版本的 Ubuntu 源码，应用 Azusa 的 BIOS 整盘安装补丁，
并将重新编译的分区模块放入 Live 层。
从下文所述的已校验官方 ISO 和同版本 Azusa deb 构建。工作目录需要使用支持
OverlayFS 的 Linux 文件系统，最后一个参数指定将由脚本创建的新目录。

```bash
sudo bash iso-remaster/build-calamares.sh \
  /path/to/ubuntu-26.04.1-desktop-amd64.iso \
  /path/to/azusa-debs /var/tmp/azusa-calamares-build
cd /var/tmp/azusa-calamares-build
sha256sum -c SHA256SUMS
```

输出为 `azusalinux-calamares.iso`。构建时需要联网下载 Ubuntu 依赖。
安装器使用独立的 Live 层，写入硬盘的系统由官方桌面层和 Azusa 目标层组成。

## NoCloud 自动安装镜像

`iso-remaster/build.sh` 用于构建带有自动分区和预设账户的镜像。以下步骤适用于该入口。

在独立的 Ubuntu 26.04 amd64 构建环境中安装 `build-essential`、`debhelper`、`xorriso`、
`dpkg-dev`、`python3-pil`、`python3-yaml`。从指定 Git 提交用 `git archive` 导出源码，
避免本地改动和 CRLF 进入构建。先从 Ubuntu 发布目录下载官方 26.04.1 Desktop amd64 镜像和
`SHA256SUMS`、`SHA256SUMS.gpg`，验证签名后再核对镜像的 SHA256。
官方签名密钥和验证方法见 [Ubuntu 镜像校验指南](https://ubuntu.com/tutorials/how-to-verify-ubuntu)。

```bash
dpkg-buildpackage -b -us -uc
SRC_ISO=/path/to/ubuntu-26.04.1-desktop-amd64.iso \
DEBS=/path/to/azusa-debs \
SOURCE_REVISION="<已导出源码的完整 Git 提交 SHA>" \
OUT=/path/to/azusalinux-amd64.iso \
bash iso-remaster/build.sh all
```

`DEBS` 必须包含 `azusa-tools`、`azusa-artwork`、`azusa-settings`、`azusa-desktop`、
`azusa-icons`、`azusa-release` 六个同版本包。每个包只能出现一份。
制作与已发布软件包同版本的镜像时，用已签名 Azusa 软件源中的原始 deb 作为 `DEBS` 输入，
使镜像与软件源交付相同的包文件。接入方式见[软件更新指南](updates.md)。
构建器通过 deb 内部的 Package/Architecture 字段校验；缺包、重复包、损坏包和
不支持的架构会使构建失败。输出路径不得与输入镜像相同。

`/azusa-build.json` 记录源码修订、输入镜像与各包 SHA256。0.1.1 使用了此前的
本地修复镜像作为输入，详见[版本构建清单](releases/0.1.1-build.json)和[验证报告](l1-validation.md)。

也可以分步运行 `extract`、`prepare`、`pack`。重复 `prepare` 会清理注入目录中的旧 deb，
逐条补齐启动项参数，并在打包时重新生成文件校验清单。

## 安装末尾执行什么

1. 把镜像中的 deb 复制到目标系统。
2. 在目标系统更新 APT 索引。
3. 在目标系统内部的 shell 展开 `/root/azusa-debs/azusa-*.deb`，一次安装所有本地包。
4. 写入 Azusa 软件源配置和配套公钥，使用 `Signed-By` 限定公钥的用途。
5. 由 `azusa-release` 包安装系统身份和登录横幅，并用 dpkg-divert 保留 Ubuntu 原件。
6. 执行 `update-grub`，使已安装系统的菜单使用新身份，再清理临时 deb。

必须在目标系统内部展开通配符：安装器的 `/root` 与目标系统的 `/root` 是不同目录。
安装命令必须包含完整包集，避免因遗漏依赖而失败。

新用户默认名和密码均为 `azusa`，主机名为 `azusalinux`，安装需要联网。
镜像会自动分区，测试应使用独立的空白虚拟磁盘。

## 验证

```bash
python3 -m unittest discover -s tests -v
```

九项测试覆盖缺包、重复包、混合版本、错误架构、损坏包、重复准备镜像和目标 shell 的通配符展开，
以及真实 xorriso 构建、解包、验证校验清单和引导目录的往返流程。
它们不能替代完整安装：还必须验证镜像启动、安装完成、移除 ISO 后从虚拟硬盘启动、
登录、六个包的安装状态以及 GNOME 的实际默认值。
已发布版本的结果见[验证报告](l1-validation.md)。

完整安装后，在新用户的桌面终端中执行独立验收：

```bash
bash /path/to/azusalinux/tests/verify-installed.sh
```

它以 22 项检查验证系统身份、六个包、图形目标、桌面默认值、字体实际解析、壁纸和图标文件，
并实际运行调色板、吉祥物和系统信息工具。

## 当前边界

- BIOS 与 UEFI 的完整安装验证分别记录，不能从其中一个推断另一个。
- Ptyxis 配色仍需手动应用；首次 GNOME 登录可能出现初始设置向导。
- `azusa-release` 使用包管理的链接和 diversion 保护身份；移除时恢复 Ubuntu 原件。
  `tests/test-release-lifecycle.sh` 已在可丢弃的 Ubuntu 基线虚拟机中实测升级、
  base-files 重装、重复安装、移除恢复、purge 后重装。此脚本有修改性，仅供测试虚拟机使用。
- 修改源码不会自动更新 GitHub Release 中已经上传的 ISO。
