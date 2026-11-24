# 开发笔记

这份文档记录项目结构、走过的路和踩过的坑。面向想改代码或者接手的人，
不是给用户看的（用户看 [README](../README.md)）。

## 项目结构

```
azusalinux/
├── bin/                    命令行工具（装进 /usr/bin）
│   ├── azusa-fetch         吉祥物 + 系统信息
│   ├── azusa-logo          真彩色半块字符画吉祥物
│   ├── azusa-palette       从 palette.json 派生各种配色
│   ├── azusa-apply         把配色/字体/壁纸套到当前用户
│   ├── azusa-mascot        生成萌系壁纸
│   ├── azusa-abstract      生成抽象壁纸
│   ├── azusa-wallpaper     立绘合成 16:9
│   ├── azusa-setup         系统身份（os-release / GRUB / hostname）
│   ├── azusa-verify        26 项可复现性检查
│   └── azusa-diff          两台机器的状态差分
├── branding/
│   ├── palette.json        唯一色板来源
│   ├── mascot/             AI 生成的原创角色
│   └── fastfetch/          fastfetch 配置
├── debian/                 deb 打包
├── iso-remaster/           官方 ISO 重打包 + autoinstall
├── docs/                   这份文档、ISO 说明、配色说明
└── packaging/              图标主题生成、壁纸 XML
```

## 走过的路

这个项目不是一次成型的，中间换过三次方向，记下来是为了避免重犯。

### 1. 中文环境工具 → 放弃

最初想做「Linux 中文环境模块化配置包」。核实后发现 **Debian/Ubuntu 的
tasksel 早就有 `task-chinese-s-desktop`**，而且实测 fontconfig 回退链在中文
语言支持下本来就是对的。真正的空档只剩输入法（尤其 Wayland）和维护工具，
价值不足以支撑一个项目。代码留在 `zh-env/`（不在本仓库）。

### 2. mkosi 自建镜像 → 存档

用 mkosi 从包清单构建可引导镜像，跑通过（`wip/mkosi-desktop` 分支）。
放弃原因：最小包集缺 `login`、`udev`、内核、grub EFI 模块，每缺一个都要
重新构建一轮；改成基于 `ubuntu-desktop-minimal` 后镜像涨到 5.4G，
构建和传输成本都高。

### 3. live-build → 放弃

在 Ubuntu 26.04 上踩了七个陈旧默认值：Debian 安全源、Debian 包名、
2011 年的 syslinux 主题、grub-legacy……它被维护，但 Ubuntu 分支只覆盖主线。

### 4. deb 包 + 官方 ISO 重打包 → 当前方案

- 我们的东西做成 deb，可装可卸
- ISO 用官方镜像 + autoinstall，安装器保持官方

## 层级演进

| 层级 | 判据 | 状态 |
|---|---|---|
| L0 | 手工调好一台机器 | ✅ |
| L0.75 | 脚本 + 状态差分验证 | ✅ |
| L0.9 | 从清单构建、可引导 | ✅ |
| L0.95 | deb 化，可装可卸 | ✅ |
| L1 | 从 ISO 安装、移除 ISO 后启动并登录 | ✅ 0.1.1 已在 VMware + BIOS/UEFI 完整验证，见 [记录](l1-validation.md) |
| L1.1 | 紫色文件夹独立主题 | ✅ |

## 验证方式（重要）

当前 ISO 的验收入口是 `tests/verify-installed.sh`，需要在完整安装后的新用户会话中运行；
完整测试记录见 [L1 验证记录](l1-validation.md)。下面的 `azusa-verify` 和状态差分
记录来自早期手工恢复方案，不能代替当前 deb/ISO 的安装验收。

不要只检查「文件在不在」，要真的执行一遍：

- `azusa-verify` —— 26 项自检，但它是**自证**（检查的是我写的清单）
- `azusa-diff` —— 两台机器状态差分，这才是独立证据
- ISO —— QEMU 无头启动 + 串口日志 + 镜像内自检服务

`azusa-diff` 自己在开发过程中出过三次 bug（两字段行塌缩、过滤名单没 export），
每次都是靠**造假数据**测出来的。自比永远测不出来。

## 踩过的坑

| 坑 | 教训 |
|---|---|
| `ID_LIKE=ubuntu debian` 没加引号 | os-release 会被 `lsb_release`、`grub-mkconfig` 当 shell source，直接报错 |
| 脚本把自己写的 os-release 当原始基底 | 幂等性要靠单独的 state 文件 |
| `sudo a && sudo b && ./install.sh` | sudo 只作用于紧邻的那条命令，第三条会丢权限 |
| mkosi 增量构建 | overlay 里删掉的文件不会从镜像里消失，要 `--incremental no` |
| `pgrep -f "lb build"` | 匹配到监视脚本自己的命令行，永远认为「还在跑」 |
| ISO 里 `quiet splash` | 拿「串口没输出」当「内核没启动」，白查了两小时 |
| Papirus 的 violet 命名 | 是前缀式 `folder-violet-documents.svg`，不是后缀式 |
| `/etc/skel` 放文件 | lintian 直接 E，Debian 政策不建议 |
| `dh_installgsettings` 默认优先级 10 | 和 Ubuntu 的 `10_` 文件同名排序时会被压掉，衍生版要用 20 |

## 已知未完成

- **GRUB 配色是死配置**：`GRUB_COLOR_NORMAL` / `GRUB_COLOR_HIGHLIGHT`
  在 grub2-common 2.14 里根本没有被读取；实际菜单颜色由
  `/etc/grub.d/05_debian_theme` 按发行版名分支决定，AzusaLinux 会落到 Debian 的蓝色分支。
- **身份升级保护已在 0.1.1 修复**：新增 `azusa-release`，通过包管理的链接与
  dpkg-divert 保护四个身份文件，移除包时恢复 Ubuntu 原件；生命周期实测见验证记录。
- **Ptyxis 调色板无法自动选中**：Profile 是可重定位 schema，普通 gsettings override
  选不中实例，需要 `azusa-apply --terminal --apply` 手动设置。

## 构建

```bash
# deb
dpkg-buildpackage -b -us -uc

# ISO（需要官方 ISO + 交叉验证环境）
cd iso-remaster && SRC_ISO=.../ubuntu-26.04.1-desktop-amd64.iso DEBS=/tmp/azusa-debs ./build.sh all
```
