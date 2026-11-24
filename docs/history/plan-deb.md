> 历史资料：保留原始过程记录，不作为当前安装或构建指南。当前入口见[文档目录](../README.md)。

# 计划：AzusaLinux 改为 deb 包交付（v0.1.0）

执行者：dsh。审阅者：仓库主人。
本文分两部分：**第一部分已核实，照做**；**第二部分未核实，只做调查、不改代码**。

## 0. 执行规则（必须遵守）

- 仓库：`~/workspace/azusalinux`，分支 `master`。只做本地提交，**不要 `git push`**。
- **你没有 sudo**（需要交互式密码）。凡是标「人工」的步骤，停下来，把要执行的命令原样交给用户。
- **不要删除或覆盖 `dist/`**。里面有不进 git 的同人壁纸，删了无法恢复。构建产物一律放 `build/`。
- 不要改 `vendor/`，不要动 `iso/`、`iso-mkosi/` 里的文件（第 1 步的存档提交除外）。
- 临时文件放 `/tmp`，不要留在 `~/workspace`。
- 每一步做完就跑这一步的「验收」，通过后单独提交一次。提交信息用 Conventional Commits，正文写「为什么」。
- 验收失败时贴原始输出，不要自行改断言，也不要跳到下一步。
- 遇到本文没写到的分歧，停下来问，不要自己选。

## 1. 目标与判据

把现有脚本做成一组 deb 包。完成的判据：在一台干净的 Ubuntu 26.04（resolute）上执行
`sudo apt install ./azusa-desktop_*.deb ./azusa-*.deb`，新建的用户登录后能看到 Azusa 的强调色、字体、壁纸和终端配色；
执行 `sudo apt purge azusa-*` 后，这些默认值恢复成 Ubuntu 原样。

这一版**不包含**系统身份（os-release），也不做 ISO，见第二部分。

## 2. 已核实的事实

以下事实来自本机（Ubuntu 26.04 resolute）的实测，后面的步骤依赖它们：

| 事实 | 来源 |
|---|---|
| Ubuntu 会话用 `[schema:ubuntu]` 这种按桌面区分的段落设默认值，优先级 10 | `/usr/share/glib-2.0/schemas/10_ubuntu-settings.gschema.override` |
| `dh_installgsettings --priority=20` 会生成 `20_<包名>.gschema.override`，20 留给衍生发行版 | debhelper 13.31 的 `dh_installgsettings` |
| kitty 会以较低优先级合并 `/etc/xdg/kitty/kitty.conf`，kitty 包本身不带这个文件 | kitty 0.45 `cli.py` 的 `SYSTEM_CONF` |
| `/etc/xdg/foot/foot.ini` 是 foot 包的 conffile，不能由我们的包直接提供 | `dpkg-deb -I foot_1.25.0-1_amd64.deb` |
| Ptyxis 只从用户目录读自定义调色板，二进制里没找到系统级调色板目录；默认 profile 的 `palette` 键可以用 override 设置（`10_ptyxis` 就这么做） | `strings /usr/bin/ptyxis`、`10_ptyxis.gschema.override` |
| 壁纸列表 XML 的格式：`<filename>`、`<filename-dark>`、`<options>zoom</options>` | `/usr/share/gnome-background-properties/resolute-wallpapers.xml` |
| 脚本查找资源的顺序是 `AZUSA_ROOT`、仓库目录、`/usr/local/share/azusalinux`，**没有 `/usr/share/azusalinux`** | `bin/*` 里的 `_find_root()` |
| `azusa-apply` 每次运行都会调用 `azusa-palette --emit`，把文件写进 `ROOT/dist`；装到 `/usr/share` 后普通用户没有写权限 | `bin/azusa-apply` 的 `generate()` |
| `azusa-logo` 运行时需要 Pillow | `bin/azusa-logo` 的 import |
| 本机没装 debhelper、devscripts、lintian | `dpkg-query` |

# 第一部分：已核实，照做

## 第 0 步（人工）：装打包工具

交给用户执行：

```bash
sudo apt install debhelper devscripts lintian
```

验收：`dpkg-query -W debhelper devscripts lintian` 三个包都有版本号。

## 第 1 步：存档 mkosi 的未提交改动

工作区里有一批没提交的 mkosi 改动：`iso-mkosi/mkosi.conf` 被修改，删掉了自检服务的两个文件，新增了 `iso-mkosi/login-test.py`。主线不再继续这条路，但这些改动要留档。

```bash
cd ~/workspace/azusalinux
git switch -c wip/mkosi-desktop
git add iso-mkosi/mkosi.conf iso-mkosi/login-test.py
git add -u iso-mkosi/mkosi.extra/etc/systemd/system/
git commit -m "wip(mkosi): archive desktop image attempt" -m "Main line moves to deb packaging; keep this attempt for reference."
git switch master
git add docs/plan-deb.md
git commit -m "docs: add deb packaging plan" -m "Building images from scratch kept failing on problems outside our code; ship our layer as debs on top of stock Ubuntu instead."
```

不要把 `foot_1.25.0-1_amd64.deb`（仓库根目录）和 `iso-mkosi/azusalinux_0.4d.vmx` 加进提交。

验收：`git status --short` 只剩这两个未跟踪文件；`git log --oneline -1 wip/mkosi-desktop` 能看到存档提交。

## 第 2 步：让脚本在 `/usr/share/azusalinux` 下也能运行

改动三处，提交为 `fix(bin): find resources under /usr/share/azusalinux`。

**2a.** 下面 6 个脚本的 `_find_root()` 里，在 `candidates.append(Path("/usr/local/share/azusalinux"))` 这一行**后面**加一行
`candidates.append(Path("/usr/share/azusalinux"))`：
`bin/azusa-palette`、`bin/azusa-abstract`、`bin/azusa-apply`、`bin/azusa-mascot`、`bin/azusa-wallpaper`、`bin/azusa-logo`。
`bin/azusa-icons` 已经弃用，不改。

**2b.** `bin/azusa-fetch`：在 `/usr/local/share/azusalinux` 那个 `elif` 后面，按相同写法再加一个 `/usr/share/azusalinux` 分支。

**2c.** `bin/azusa-apply` 的 `generate()`：如果 `ROOT` 不可写（`os.access(ROOT, os.W_OK)` 为假），就不调用 `azusa-palette --emit`，直接使用已经随包装好的 `ROOT/dist`；可写时保持原来的行为。

验收：
```bash
./bin/azusa-palette | head -3                     # 仓库内运行，行为不变
python3 bin/azusa-apply                           # 只预览，不报错
d=$(mktemp -d /tmp/azusa-root.XXXX); cp -r branding "$d"/
AZUSA_ROOT="$d" python3 bin/azusa-palette --emit && ls "$d/dist"   # 5 个文件
```

## 第 3 步：打包骨架，以及 `azusa-tools`、`azusa-artwork` 两个包

一份源码 `azusalinux` 出多个二进制包。这一步新建下面的文件，提交为 `build(debian): add packaging for azusa-tools and azusa-artwork`。

**`debian/source/format`**
```
3.0 (native)
```

**`debian/changelog`**（日期用 `date -R` 的实际输出）
```
azusalinux (0.1.0) resolute; urgency=medium

  * Initial packaging: azusa-tools, azusa-artwork.

 -- azusa <dsyfb437@users.noreply.github.com>  <date -R 的输出>
```

**`debian/control`**
```
Source: azusalinux
Section: misc
Priority: optional
Maintainer: azusa <dsyfb437@users.noreply.github.com>
Build-Depends: debhelper-compat (= 13), python3, python3-pil
Standards-Version: 4.7.4
Rules-Requires-Root: no
Homepage: https://github.com/dsyfb437/azusalinux

Package: azusa-tools
Architecture: all
Depends: ${misc:Depends}, python3, python3-pil
Recommends: fastfetch
Description: AzusaLinux command-line tools
 azusa-fetch, azusa-logo, azusa-palette, azusa-apply and the wallpaper
 generators, with the shared palette and mascot under /usr/share/azusalinux.

Package: azusa-artwork
Architecture: all
Depends: ${misc:Depends}
Description: AzusaLinux wallpapers
 Mascot wallpapers (light and dark) generated from the AzusaLinux palette,
 registered in the GNOME wallpaper picker.
```

**`debian/rules`**（可执行，`chmod +x`）
```make
#!/usr/bin/make -f
BUILD := $(CURDIR)/build

%:
	dh $@

override_dh_auto_build:
	mkdir -p $(BUILD)/root
	cp -r branding $(BUILD)/root/
	AZUSA_ROOT=$(BUILD)/root python3 bin/azusa-palette --emit
	AZUSA_ROOT=$(BUILD)/root python3 bin/azusa-mascot --size 2880x1800 --out $(BUILD)/wallpapers

override_dh_auto_clean:
	rm -rf $(BUILD)
```
这里故意把 `branding/` 复制到 `build/root`，让 `azusa-palette --emit` 写进 `build/root/dist`，而不是仓库里的 `dist/`。`clean` 只删 `build/`。

**`debian/azusa-tools.install`**
```
bin/azusa-fetch usr/bin
bin/azusa-logo usr/bin
bin/azusa-palette usr/bin
bin/azusa-apply usr/bin
bin/azusa-mascot usr/bin
bin/azusa-abstract usr/bin
bin/azusa-wallpaper usr/bin
branding usr/share/azusalinux
build/root/dist/* usr/share/azusalinux/dist
```

**`debian/azusa-tools.links`**
```
usr/bin/azusa-fetch usr/bin/azusafetch
```

**`debian/azusa-artwork.install`**
```
build/wallpapers/mascot-*.jpg usr/share/backgrounds/azusa
packaging/azusa-wallpapers.xml usr/share/gnome-background-properties
```

**`packaging/azusa-wallpapers.xml`**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper>
    <name>Azusa</name>
    <filename>/usr/share/backgrounds/azusa/mascot-light-2880x1800.jpg</filename>
    <filename-dark>/usr/share/backgrounds/azusa/mascot-dark-2880x1800.jpg</filename-dark>
    <options>zoom</options>
  </wallpaper>
</wallpapers>
```

**`debian/copyright`**：先按下面写。许可证还没定（见第二部分 B5），这里先占位，lintian 报警告是预期的。
```
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: azusalinux
Source: https://github.com/dsyfb437/azusalinux

Files: *
Copyright: 2026 azusa
License: TBD
 License not decided yet. Do not redistribute until this is filled in.
```

**`.gitignore`** 追加：
```
build/
debian/.debhelper/
debian/azusa-*/
debian/files
debian/*.substvars
debian/debhelper-build-stamp
debian/*.debhelper.log
```

**构建**。dpkg-buildpackage 会把产物写到仓库的上一级 `~/workspace/`，构建完马上挪到 `/tmp`：
```bash
cd ~/workspace/azusalinux
dpkg-buildpackage -b -us -uc
mkdir -p /tmp/azusa-debs
mv ../azusa-*_0.1.0_all.deb ../azusalinux_0.1.0_*.buildinfo ../azusalinux_0.1.0_*.changes /tmp/azusa-debs/
```

验收：
```bash
lintian /tmp/azusa-debs/*.deb                 # 不能有 E: 行；W: 行原样列给用户
dpkg-deb -c /tmp/azusa-debs/azusa-tools_0.1.0_all.deb | grep -E 'usr/bin/azusa|share/azusalinux/(branding/palette.json|dist/)'
dpkg-deb -c /tmp/azusa-debs/azusa-artwork_0.1.0_all.deb | grep -E 'backgrounds/azusa|gnome-background-properties'
x=$(mktemp -d /tmp/azusa-x.XXXX); dpkg-deb -x /tmp/azusa-debs/azusa-tools_0.1.0_all.deb "$x"
AZUSA_ROOT="$x/usr/share/azusalinux" "$x/usr/bin/azusa-fetch" | head -5   # 能打印吉祥物
ls dist/wallpapers | wc -l                     # 和构建前的数量一样（dist/ 被 gitignore，git status 看不出来，要在构建前先记下数量）
```

## 第 4 步：`azusa-settings`，即桌面默认值

只改「默认值」，不改用户已有的设置。提交为 `feat(debian): ship desktop defaults as azusa-settings`。

**`debian/control`** 追加：
```
Package: azusa-settings
Architecture: all
Depends: ${misc:Depends}, azusa-artwork, fonts-inter, fonts-jetbrains-mono, papirus-icon-theme
Description: AzusaLinux desktop defaults
 GSettings overrides for accent colour, fonts, wallpaper and icon theme,
 plus system-wide kitty colours and a Ptyxis palette for new users.
```

**`debian/azusa-settings.gsettings-override`**。每个段落都要写两份：一份不带后缀，一份带 `:ubuntu`。原因是 Ubuntu 会话读的是 `:ubuntu` 段落，只写不带后缀的那份在 Ubuntu 会话里不生效。
```ini
[org.gnome.desktop.interface]
accent-color='purple'
color-scheme='prefer-dark'
font-name='Inter 11'
document-font-name='Inter 11'
monospace-font-name='JetBrains Mono 11'
icon-theme='Papirus-Dark'

[org.gnome.desktop.interface:ubuntu]
accent-color='purple'
color-scheme='prefer-dark'
font-name='Inter 11'
document-font-name='Inter 11'
monospace-font-name='JetBrains Mono 11'
icon-theme='Papirus-Dark'

[org.gnome.desktop.wm.preferences]
titlebar-font='Inter Bold 11'

[org.gnome.desktop.wm.preferences:ubuntu]
titlebar-font='Inter Bold 11'

[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/azusa/mascot-light-2880x1800.jpg'
picture-uri-dark='file:///usr/share/backgrounds/azusa/mascot-dark-2880x1800.jpg'
picture-options='zoom'

[org.gnome.desktop.background:ubuntu]
picture-uri='file:///usr/share/backgrounds/azusa/mascot-light-2880x1800.jpg'
picture-uri-dark='file:///usr/share/backgrounds/azusa/mascot-dark-2880x1800.jpg'
picture-options='zoom'

[org.gnome.desktop.screensaver:ubuntu]
picture-uri='file:///usr/share/backgrounds/azusa/mascot-dark-2880x1800.jpg'

[org.gnome.Ptyxis]
font-name='JetBrains Mono 11'
use-system-font=false

[org.gnome.Ptyxis.Profile]
palette='azusa'
```
这些值逐项抄自 `bin/azusa-apply` 当前的设定，不要自己改动。

**`debian/rules`** 追加：
```make
override_dh_installgsettings:
	dh_installgsettings --priority=20

execute_after_dh_install:
	install -D -m 0644 $(BUILD)/root/dist/kitty-azusa.conf \
		debian/azusa-settings/etc/xdg/kitty/kitty.conf
	install -D -m 0644 $(BUILD)/root/dist/ptyxis-azusa.palette \
		debian/azusa-settings/etc/skel/.local/share/org.gnome.Ptyxis/palettes/azusa.palette
```

foot 这次不处理，原因见第二部分 B3。

验收，按第 3 步重新构建、挪到 `/tmp` 之后跑。这一段不需要 root，也不会动本机的设置：
```bash
x=$(mktemp -d /tmp/azusa-s.XXXX); dpkg-deb -x /tmp/azusa-debs/azusa-settings_0.1.0_all.deb "$x"
ls "$x/usr/share/glib-2.0/schemas/"            # 应为 20_azusa-settings.gschema.override
d=$(mktemp -d /tmp/azusa-schema.XXXX)
cp /usr/share/glib-2.0/schemas/*.xml /usr/share/glib-2.0/schemas/*.override "$d"/
cp "$x"/usr/share/glib-2.0/schemas/*.override "$d"/
glib-compile-schemas --strict "$d"
for desk in GNOME ubuntu:GNOME; do
  for key in "org.gnome.desktop.interface accent-color" \
             "org.gnome.desktop.interface font-name" \
             "org.gnome.desktop.background picture-uri-dark"; do
    printf '%s %s = ' "$desk" "$key"
    GSETTINGS_SCHEMA_DIR="$d" GSETTINGS_BACKEND=memory XDG_CURRENT_DESKTOP="$desk" gsettings get $key
  done
done
```
期望：两种桌面下都输出 Azusa 的值（`'purple'`、`'Inter 11'`、Azusa 壁纸路径）。只要有一项显示 Ubuntu 的值（比如 `'orange'`），就停下，把输出原样交给用户。

## 第 5 步：`azusa-desktop` 元包和 README

提交为 `feat(debian): add azusa-desktop metapackage`。

**`debian/control`** 追加：
```
Package: azusa-desktop
Architecture: all
Depends: ${misc:Depends}, azusa-tools, azusa-artwork, azusa-settings, fastfetch
Description: AzusaLinux desktop (metapackage)
 Installs the AzusaLinux tools, artwork and desktop defaults on Ubuntu.
```
`azusa-base`（系统身份）这次**不加**，见第二部分 B1。

**`debian/changelog`**：不要新增版本条目，在 0.1.0 条目里补一行 `* Add azusa-settings and azusa-desktop.`。

**`README.md`**：在「## 现在是什么状态」**前面**加一节「## 用 deb 安装（0.1.0 起）」，写三件事：构建命令（第 3 步那两段）、安装命令 `sudo apt install /tmp/azusa-debs/azusa-*.deb`、卸载命令 `sudo apt purge azusa-desktop azusa-settings azusa-artwork azusa-tools`。再加一句：已有用户的设置不会被覆盖，要套用到当前用户，继续用 `azusa-apply`。
README 其他部分、`provision.sh`、`install.sh` 都不改，等第 6 步通过后再决定。

验收：重新构建，`lintian` 没有 E: 行，`/tmp/azusa-debs/` 里有 4 个 deb。

## 第 6 步（人工）：在干净虚拟机里验收

dsh 做到第 5 步就停下，把下面这段交给用户。本机没有 `/dev/kvm`，要用 VMware 里的 Ubuntu 26.04 虚拟机，装好后先打快照。**不要在开发机上装这些包**：开发机已经被 `azusa-apply` 手工改过，在它上面验收说明不了问题。

```bash
# 在虚拟机里
sudo apt install ./azusa-*.deb
sudo adduser --gecos '' azusatest      # 注销，用 azusatest 登录
# 以 azusatest 身份检查：
gsettings get org.gnome.desktop.interface accent-color      # 'purple'
gsettings get org.gnome.desktop.interface font-name         # 'Inter 11'
gsettings get org.gnome.desktop.background picture-uri-dark # Azusa 壁纸
ls ~/.local/share/org.gnome.Ptyxis/palettes/azusa.palette   # 存在
azusa-fetch                                                 # 打印吉祥物和系统信息
# 肉眼检查：壁纸、强调色、Ptyxis 配色、设置 → 外观里能选到 Azusa 壁纸
# 卸载检查：
sudo apt purge azusa-desktop azusa-settings azusa-artwork azusa-tools
# 再新建一个用户登录，应该是 Ubuntu 默认的橙色和 Ubuntu 壁纸
```

把每一项的结果（包括失败项的原始输出）记到 `docs/fresh-vm-test.md` 末尾新增的「deb 验收」一节。

# 第二部分：未核实，只调查

这一部分**不要改代码**。每一项把调查结果写进 `docs/plan-deb.md` 对应条目下面的「调查结果」，然后停下来等用户决定。

## B1. `azusa-base`：系统身份（os-release / lsb-release / issue）

已知：
- `/usr/lib/os-release` 属于 base-files 包，**不是** conffile；`/etc/lsb-release`、`/etc/issue`、`/etc/issue.net` 是 conffile。
- 所以开发机现在的状态不稳：base-files 下次升级会把 `azusa-setup` 写进 `/usr/lib/os-release` 的内容覆盖回 Ubuntu 原样。
- 候选做法是用 config-package-dev 的 displace（`dh $@ --with config-package`，加 `debian/azusa-base.displace`），由 dpkg-divert 把原文件挪开、卸载时还原。它自带的示例就是 displace `/etc/issue.net`。

要调查的问题：
1. `ID=azusalinux` 会不会让 `do-release-upgrade`、`ubuntu-drivers`、`software-properties`、snapd 这类程序走错分支？在源码或文档里找它们判断发行版的位置，列出文件和行号。
2. 对照方案：保留 `ID=ubuntu`，只改 `NAME`、`PRETTY_NAME`、`VERSION`。列出两种方案各自影响到的程序。
3. `GRUB_DISTRIBUTOR` 取自 os-release 的 `NAME`，改名会影响 GRUB 主题分支（见 B2）。

注意：开发机上的这几个文件已经被改过。如果直接在开发机上 displace，被挪开保存的会是改过的版本，而不是 Ubuntu 原版。验证只能在干净虚拟机里做。

## B2. GRUB 菜单配色

已知：
- grub2-common 2.14-2ubuntu2.1 的 `grub-mkconfig` 和 `/etc/grub.d/*` 都不读 `GRUB_COLOR_NORMAL`、`GRUB_COLOR_HIGHLIGHT`。也就是说，`azusa-apply --grub` 现在往 `/etc/default/grub` 写的那两行**不起作用**。
- `05_debian_theme` 只有在 `GRUB_DISTRIBUTOR` 是 `Ubuntu` 或 `Kubuntu` 时才用黑白配色，其他名字都走 Debian 的 `cyan/blue`。本机 `GRUB_DISTRIBUTOR` 取 os-release 的 `NAME`，现在是 `AzusaLinux`。由此推断本机 GRUB 菜单现在是蓝色的，但我没读到 `/boot/grub/grub.cfg`（需要 root），这一点未确认。

要调查的问题：
1. （人工）让用户执行 `sudo grep -n 'menu_color\|color_normal' /boot/grub/grub.cfg`，确认当前实际生效的配色。
2. GRUB 的 `menu_color_normal` 是否接受 `#rrggbb` 写法，还是只接受 16 个颜色名？`dist/grub-azusa.cfg` 现在用的是十六进制。在 GRUB 2.14 的文档或源码里找到依据。
3. 候选做法：由包提供 `/etc/grub.d/06_azusa_theme`，在 `05_debian_theme` 之后输出 `set menu_color_*`。写清楚它和 05 的先后顺序，并说明 postinst 是否需要调用 `update-grub`。

## B3. foot 终端配色

`/etc/xdg/foot/foot.ini` 是 foot 包的 conffile，我们的包不能直接提供这个文件。foot 也不是 Ubuntu 默认安装的终端。建议这一版不做，继续交给 `azusa-apply`（用户级）。如果要做，只能用 displace，调查 foot 的 `include=` 是否允许写绝对路径（man page 说可以），以及 displace 一个 conffile 的风险。

## B4. 紫色文件夹图标

已知：`papirus-folders` 是直接改 papirus-icon-theme 包里的文件（把 `places/folder*.svg` 的软链指向 violet 版本）。开发机的 `48x48/places/folder.svg` 现在指向 `folder-violet.svg`，papirus-icon-theme 升级后会被还原。

候选做法：自己出一个图标主题 `Azusa-Papirus`，`Inherits=Papirus-Dark`，只在 `22x22 24x24 32x32 48x48 64x64` 这几个 `places` 目录里放指向 Papirus-Dark violet 图标的软链（`papirus-folders` 改的也是这几个尺寸）。

要调查的问题：这个主题的 `index.theme` 要写哪些 `Directories`；软链在图标缓存（`gtk-update-icon-cache`）下是否正常；Nautilus 是否会显示成紫色。调查结果出来之前，第 4 步的 override 里仍然用 `icon-theme='Papirus-Dark'`。

## B5. 许可证（用户决定）

仓库里没有 LICENSE 文件。`debian/copyright` 现在是占位。代码用什么许可证、吉祥物图片（`branding/mascot/SOURCES.md` 说是 AI 生成的原创角色）用什么许可证，需要用户决定。决定之前不要往任何公开渠道发布 deb。

## B6. ISO

等第 6 步验收通过、B1 定下来以后，再单独出计划。候选方向有两个：解包官方 ISO 装进 deb 再重打包，或者用官方安装器的 autoinstall 在安装时装 deb。

# 不做的事

- 不把 `azusa-icons`（已弃用）、`azusa-diff`、`azusa-verify` 打进包。它们是开发和验收工具，留在仓库里用。
- 不把 `wallpapers/` 下的同人图打进任何包（`wallpapers/SOURCES.md` 规定只能自用）。
- 不改 hostname，这交给安装器。
- 不删 `install.sh`、`provision.sh`，第 6 步通过后由用户决定。
