# 审阅：`docs/plan-deb.md`

审阅时间：2026-11-22。审阅者：dsh。状态：**未执行，等用户拍板**。

## 结论

计划整体可执行，分步、验收、提交边界都清楚，比之前的 mkosi 手搓路线靠谱得多。
但有 **3 个会导致「验收通过但实际无效」的问题**，建议先改再开工：

1. `[org.gnome.Ptyxis.Profile]` 的 override 极可能静默失效，而第 4 步验收不覆盖它。
2. `:ubuntu` 段重复的理由写错了（结论碰巧还是对的），会误导后续维护。
3. `debian/copyright` 的 `License: TBD` 与「lintian 不能有 E:」的验收标准冲突。

## 一、独立核实过的事实

| 计划里的说法 | 核实方式 | 结果 |
|---|---|---|
| `GRUB_COLOR_NORMAL/HIGHLIGHT` 不被读取 | `grep` 遍 `/etc/grub.d/`、`/usr/sbin/grub-mkconfig`、`/usr/lib/grub/` | ✅ **0 处引用**，是死配置 |
| 本机 GRUB 菜单是蓝色的 | `sudo grep menu_color /boot/grub/grub.cfg` | ✅ `menu_color_normal=cyan/blue`，`05_debian_theme` 走 Debian 分支 |
| `/usr/lib/os-release` 属于 base-files 且非 conffile | `dpkg -S`、`dpkg-query -W -f='${conffiles}'` | ✅ 归属 base-files，conffiles 里 0 条 |
| Ubuntu 用 `[schema:ubuntu]` 段 | `10_ubuntu-settings.gschema.override` 第 79–105 行 | ✅ 确有 `:ubuntu` 段 |
| `_find_root()` 没有 `/usr/share/azusalinux` | `grep -l` 全部 `bin/*` | ✅ 只有 `AZUSA_ROOT`、仓库目录、`/usr/local/share` |
| `azusa-apply` 每次都 `--emit` 且写 `ROOT/dist` | 读 `generate()` | ✅ 无条件调用，失败即 `sys.exit` |
| `azusa-logo` 需要 Pillow | 读 import | ✅ `from PIL import ...` |
| foot 的 `/etc/xdg/foot/foot.ini` 是 conffile | `dpkg-deb -e` 解出 `conffiles` | ✅ 是 |
| debhelper / devscripts / lintian 未安装 | `dpkg -s` | ✅ 三个都缺 |

**未能核实**（环境里没有对应软件，装完第 0 步应补验）：

- `dh_installgsettings --priority` 这个参数是否存在、生成的文件名是否真是 `20_<包名>.gschema.override`。
- kitty 合并 `/etc/xdg/kitty/kitty.conf` 的行为（本机没装 kitty）。
- Ptyxis 是否真的不读系统级调色板（目前只有 `strings` 的间接证据）。

## 二、需要修正的三处

### 2.1 `:ubuntu` 段的理由错了，但结论对

计划写「只写不带后缀的那份在 Ubuntu 会话里不生效」。**这句话只对一部分键成立。**

实测（临时 schema 目录 + `GSETTINGS_BACKEND=memory` + `XDG_CURRENT_DESKTOP=ubuntu:GNOME`）：

| 键 | 只写全局段（20_）的结果 | 是否必须写 `:ubuntu` |
|---|---|---|
| `accent-color` | `'purple'`（我们的值生效） | ❌ 不需要 |
| `color-scheme` | 同理（Ubuntu 的 `:ubuntu` 段没设它） | ❌ |
| `picture-options` | 同理 | ❌ |
| `font-name` | `'Ubuntu Sans 11'`（**我们的值失效**） | ✅ 必须 |
| `document-font-name` | 同上 | ✅ |
| `monospace-font-name` | 同上 | ✅ |
| `icon-theme` | 同上（Ubuntu 在 `:ubuntu` 设了 `Yaru`） | ✅ |
| `picture-uri` / `picture-uri-dark` | `warty-final-ubuntu.png`（**我们的值失效**） | ✅ |
| `titlebar-font`（wm.preferences） | Ubuntu 没设 `:ubuntu` 段 | ❌ |

机制不是「桌面后缀优先」，而是**同键后文件覆盖前文件**；Ubuntu 的 `:ubuntu` 段只要设了某个键，就会压过我们更晚的全局段。

结论：**第 4 步的写法照旧可以**（多写不报错），但计划里的解释要改，否则以后有人只写全局段会踩坑。

### 2.2 Ptyxis profile 的 override 很可能无效

第 4 步写：

```ini
[org.gnome.Ptyxis.Profile]
palette='azusa'
```

`org.gnome.Ptyxis.Profile` 是**可重定位（relocatable）schema**，实例路径是
`/org/gnome/Ptyxis/Profiles/<uuid>/`，而 uuid 每台机器不同。GSettings 对可重定位 schema 的
override 要求写完整路径，不写路径的段**不会作用到任何实例**。

而且第 4 步的验收只查 `accent-color`、`font-name`、`picture-uri-dark`，**不查 Ptyxis**——
所以这条会「验收通过、实际没生效」。

建议二选一：

- **A（推荐）**：本版去掉这两行，终端配色继续由 `azusa-apply --terminal` 按用户设置。
  第 6 步的人工验收里明确写「Ptyxis 配色需要手动跑一次 azusa-apply」。
- **B**：保留文件投放（`/etc/skel/.../azusa.palette`），但不指望 profile 自动选中；
  在文档里写明「新用户需要自己选一次调色板」。

如果一定要自动选中，得写 postinst 遍历 `/home/*` 找 uuid 再 `gsettings set`——脏，不建议这个版本做。

### 2.3 `License: TBD` 与验收标准冲突

第 3 步写 `debian/copyright` 占位 `License: TBD`，第 3 步验收写「lintian 不能有 E: 行」。
`TBD` 不是合法许可证标识，lintian 大概率直接报 E（至少 `invalid-license` 一类）。

建议：**第 3 步之前就把许可证定下来**（B5 其实是阻塞项，不是「第二部分待调查」）。
或者把第 3 步验收放宽成「无 E: 行，**除 copyright 相关**」，并在第 6 步前必须解决。

## 三、其它小问题

1. **`azusa-apply --grub` 应该删掉或标注**。计划已确认它写的是死配置，但脚本里还在写。
   建议第 2 步顺手在 `apply_grub()` 加一行注释或直接禁用，避免用户以为生效了。
   （本版不改 `/etc/default/grub` 的话，第 2 步也可以不动，但要在 README 里注明。）
2. **`azusa-fetch` 安装后首次调用会先失败一次**：它先试 `$ROOT/bin/azusa-logo`，
   而装好后脚本在 `/usr/bin`，`/usr/share/azusalinux/bin/` 不存在，靠后面的 fallback 兜住。
   建议把 fallback 放到前面，或第 2 步一并调整。
3. **第 1 步的 `git add -u iso-mkosi/mkosi.extra/systemd/`**：实际路径是
   `iso-mkosi/mkosi.extra/etc/systemd/system/`，计划里写的是简写，执行时按实际路径。
4. **第 6 步装包**：`sudo apt install ./azusa-*.deb` 要求同一目录下所有依赖 deb 一起给；
   建议写成 `sudo apt install /tmp/azusa-debs/*.deb`（一次全给，apt 自己解序）。
5. **仓库大小**：`azusa-tools` 会带走 `branding/mascot/*.png`（两张共约 3.3M）和
   `dist/` 生成的文本产物，总量不大，但计划最好写一句预期体积，便于验收比对。

## 四、我建议的执行顺序调整

```
第 0 步（人工装工具）
  ↓
B5 定许可证  ← 从第二部分提前，否则第 3 步验收过不了
  ↓
第 1、2、3 步
  ↓
第 4 步（Ptyxis 那段按 2.2 方案 A 删掉）
  ↓
第 5 步
  ↓
第 6 步（人工，VM 验收）
```

第二部分里 **B2.1 已经可以关掉**（我读到实际 grub.cfg 了：`cyan/blue`，确认是蓝色）。
B1、B2.2、B3、B4 仍然需要调查，B6 等第 6 步。

## 五、尚未核实、执行时要留意

- `dh_installgsettings --priority` 的存在性（装完 debhelper 后 `dh_installgsettings --help | grep priority`）。
- 壁纸 XML 的 `<options>zoom</options>` 是否被 GNOME 26.04 的壁纸选择器接受（第 6 步肉眼确认）。
- `azusa-artwork` 的 XML 里的 `<filename-dark>` 配对是否正常。
