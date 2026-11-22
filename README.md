# AzusaLinux

一个基于 Ubuntu 的 Azusa 自己的系统。

不是从零写内核，是在 Ubuntu 之上把「默认值」换成自己的：身份、桌面、预装、安装体验。
生态照单全收——apt、PPA、Flatpak、deb 全都继续能用。

## 现在是什么状态

**第 1 层：身份。已完成。**

`azusa-setup` 把一台干净的 Ubuntu 变成 AzusaLinux：

| 改什么 | 内容 |
|---|---|
| `/etc/os-release` | `ID=azusalinux`、`ID_LIKE=ubuntu debian`、`VERSION_CODENAME=azusa` |
| `/etc/lsb-release` | `DISTRIB_ID=AzusaLinux` |
| `/etc/issue`、`/etc/issue.net` | 登录横幅 |
| hostname | `azusalinux` |

设计约定跟 `zh-env` 一致：**默认只预览，`--apply` 才写，写之前备份到
`/var/lib/azusalinux/backup/`。**

```bash
./azusa-setup                 # 看会改什么
sudo ./azusa-setup --apply    # 真的改
```

## 还没做

- **第 2 层：桌面默认值** —— 壁纸、主题、字体、面板布局、默认应用、`/etc/skel`

**第 2 层的地基（配色）已完成**：

- `branding/palette.json` —— 亮/暗两套语义色，来自 8 张角色立绘的统计取样
- `bin/azusa-palette` —— 从色板派生出 GTK / kitty / foot / GRUB 配色，并打印终端实色预览
- `tools/render-swatch.py` —— 渲染 PNG 色卡（开发用）

```bash
./bin/azusa-palette          # 看色板和终端实色预览
./bin/azusa-palette --emit   # 写到 dist/
```

规则：**所有颜色只能来自 `palette.json`，不允许在别处硬编码。**

壁纸：把立绘合成 16:9（需要 Pillow）。横图铺满、纯色底抠图、背景复杂就做圆角卡片。

```bash
./bin/azusa-wallpaper --src 图1.png 图2.jpg --out dist/wallpapers
```

授权说明见 `wallpapers/SOURCES.md`——**同人图只能自用，不能进 ISO。**

抽象壁纸（发布版用这个，没有版权问题）：

```bash
./bin/azusa-abstract                       # 生成全部风格
./bin/azusa-abstract --style dusk --seed 7
```

风格里 **dusk**（黄昏山脊：天空 + 地平线辉光 + 多层剪影 + 星点）是默认，
因为纯渐变永远像「没做完」——好的系统壁纸需要光源和前后层次。

吉祥物壁纸（默认风格，萌系）：

```bash
./bin/azusa-mascot --size 2880x1800 --avatar
```

角色图来自 `branding/mascot/`，是 AI 生成的原创角色，可以进 ISO。
手绘/同人图的版权约束见 `wallpapers/SOURCES.md`。

图标（继承 Adwaita，只覆盖 9 个文件，其余照旧）：

```bash
./bin/azusa-icons --install
# 还原： gsettings set org.gnome.desktop.interface icon-theme Yaru
```

终端里显示吉祥物（24 位色半块字符，不是 ASCII）：

```bash
./bin/azusa-fetch              # 吉祥物 + 系统信息（需要 fastfetch）
./bin/azusa-logo --width 36    # 只打印吉祥物
```

套到系统上（默认只预览，`--apply` 才写，改前备份）：

```bash
./bin/azusa-apply                 # 预览会做什么
./bin/azusa-apply --terminal --apply   # 终端配色（不需要 root）
sudo ./bin/azusa-apply --grub --apply  # GRUB 配色 + update-grub
./bin/azusa-apply --gnome --apply      # GNOME 强调色（需在桌面会话里）
./bin/azusa-apply --fonts --apply      # 界面字体 Inter + JetBrains Mono
```

`--dest-root` / `--etc-root` 是测试用的，可以把改动落到临时目录里验证。

- **第 3 层：预装清单 + 元包** —— `azusa-desktop` 只写 `Depends:`
- **第 4 层：ISO** —— live-build 出 `azusalinux-0.1-amd64.iso` + Calamares 安装器

## 为什么不用从头做

`/etc/os-release` 的写法、`ID_LIKE` 的层级、`VERSION_CODENAME` 与
`UBUNTU_CODENAME` 分家（Mint 的做法）——这些是发行版的「身份协议」，
软件靠它判断怎么对待你。写对了，`lsb_release -a`、系统设置、neofetch
就都认你是 AzusaLinux；写错了，一堆软件会退回 Ubuntu 分支。

## 相关项目

- [zh-env](../zh-env) —— 中文环境自检工具，以后可以作为可选包进 `defaults/`

## v1 现状（2026-11）

视觉层定稿，功能可用。但它现在还是「手工调出来的一台机器」，不是「可复制的一套东西」——
下表标出哪些已经脚本化、哪些还得手敲。

### 已脚本化

| 项目 | 命令 |
|---|---|
| 系统身份（os-release / lsb-release / issue / hostname） | `sudo ./azusa-setup --apply` |
| 配色派生（GTK / kitty / foot / GRUB / Ptyxis） | `./azusa-palette --emit` |
| 终端配色 + 字体 + GNOME 强调色 + GRUB 配色 | `./bin/azusa-apply --all --apply` |
| 萌系壁纸（6 种分辨率） | `./bin/azusa-mascot` |
| 抽象壁纸 | `./bin/azusa-abstract` |
| 终端吉祥物 + 系统信息 | `./bin/azusa-fetch` |
| 工具装进 PATH | `./install.sh` |

### 恢复这台机器的全部步骤

```bash
# 1. 依赖（只需一次）
sudo apt install fonts-inter fonts-jetbrains-mono fastfetch papirus-icon-theme git curl

# 2. 用户级：终端配色、字体、强调色、壁纸、图标主题（不需要 sudo）
./bin/azusa-mascot
python3 bin/azusa-apply --all --apply

# 3. 系统级：文件夹染色 + GRUB 配色（需要 sudo）
sudo ./bin/azusa-apply --system --apply

# 4. 系统身份（需要 sudo，只需一次）
sudo ./azusa-setup --apply

# 5. 工具装进 PATH（可选）
./install.sh
```

**注意作用域**：`--all` 是用户级，**不要加 sudo**（sudo 会丢掉 DBus 会话，
gsettings 静默失败）；需要 root 的操作统一走 `--system`。这个区分是踩出来的——
一开始把两者混在一起，结果把终端调色板写进了 `/root/.local`。

### 已知未做

- ISO / 安装器
- 登录界面（GDM）品牌化
- `/etc/skel` 默认配置
- `azusa-fetch` 没挂到 `.bashrc`（故意的：每次开终端都刷一遍会烦）
