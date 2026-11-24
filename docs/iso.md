# ISO：官方镜像 + 自动安装

当前方案使用官方 Ubuntu Desktop ISO，加入 Azusa deb 和 NoCloud 配置，
通过 xorriso 的 `-boot_image any replay` 保留原镜像的引导结构。
`iso/` 和 `iso-mkosi/` 是早期方案，当前入口是 `iso-remaster/build.sh`。

## 构建

在 Linux 环境安装 `build-essential`、`debhelper`、`xorriso`、`dpkg-dev`、
`python3-pil`、`python3-yaml`。建议使用 `git archive` 导出的源码，避免 CRLF 进入脚本。
先构建 deb，并准备已校验的官方 Ubuntu 26.04.1 Desktop amd64 ISO：

```bash
dpkg-buildpackage -b -us -uc
SRC_ISO=/path/to/ubuntu-26.04.1-desktop-amd64.iso \
DEBS=/path/to/azusa-debs \
SOURCE_REVISION="$(git rev-parse HEAD)" \
OUT=/path/to/azusalinux-0.1.1-amd64.iso \
bash iso-remaster/build.sh all
```

`DEBS` 必须包含 `azusa-tools`、`azusa-artwork`、`azusa-settings`、`azusa-desktop`、
`azusa-icons`、`azusa-release` 六个同版本包。每个包只能出现一份。
构建器通过 deb 内部的 Package/Architecture 字段校验；缺包、重复包、损坏包和
不支持的架构会使构建失败。输出路径不得与输入镜像相同。

`/azusa-build.json` 记录源码修订、输入镜像与各包 SHA256。0.1.1 本次实际输入是
此前的本地修复镜像，输入链见验证记录和发布附件 `BUILD-MANIFEST.json`。

也可以分步运行 `extract`、`prepare`、`pack`。重复 `prepare` 会清理注入目录中的旧 deb，
逐条补齐启动项参数，并在打包时重新生成文件校验清单。

## 安装末尾执行什么

1. 把镜像中的 deb 复制到目标系统。
2. 在目标系统更新 APT 索引。
3. 在目标系统内部的 shell 展开 `/root/azusa-debs/azusa-*.deb`，一次安装所有本地包。
4. 由 `azusa-release` 包安装系统身份和登录横幅，并用 dpkg-divert 保留 Ubuntu 原件。
5. 执行 `update-grub`，使已安装系统的菜单使用新身份。
6. 清理临时 deb；旧版身份脚本不再注入或执行。

必须在目标系统内部展开通配符：安装器的 `/root` 与目标系统的 `/root` 是不同目录。
不要只列举旧版本的四个 deb。v0.1.0 因遗漏 `azusa-icons` 而在末尾返回 APT 错误码 100。

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
本轮结果见 [L1 验证记录](l1-validation.md)。

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
