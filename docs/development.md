# 开发指南

AzusaLinux 使用 deb 包交付桌面资源与配置，通过重打包 Ubuntu Desktop ISO 提供自动安装镜像。

## 项目结构

| 路径 | 职责 |
|---|---|
| `bin/` | 命令行工具及桌面配置工具 |
| `branding/` | 色板、吉祥物和 fastfetch 资源 |
| `debian/` | 六个 deb 包的元数据和维护脚本 |
| `packaging/` | 壁纸、图标和发行标识生成器 |
| `iso-remaster/` | 当前 ISO 构建入口与自动安装配置 |
| `tests/` | 构建回归、安装验收和身份包生命周期检查 |
| `docs/` | 使用、开发及版本验证文档 |
| `iso/`、`iso-mkosi/` | 早期构建方案，非当前构建入口 |

## 软件包与配置

软件包清单和构建命令见[软件包指南](packages.md)。

- GNOME 默认值由 azusa-settings 的 GSettings override 提供，已有用户配置优先。
- Azusa-Papirus 继承 Papirus-Dark，以独立主题覆盖文件夹图标。
- 系统身份由 azusa-release 管理，使用 dpkg-divert 保护 Ubuntu 原件。
- Ptyxis 的配置档需要在用户会话中选择调色板，不能仅依赖全局 override。
- 色板数据来自 `branding/palette.json`，修改方式见[配色设计](color.md)。

旧的 `azusa-setup` 和手工恢复脚本不属于当前 ISO 安装路径。
GRUB 配色仍有上游兼容问题，不应把写入配置变量等同于实际菜单已改变。

## 构建与验证

1. 按[软件包指南](packages.md)构建六个同版本 deb。
2. 按[ISO 构建指南](iso.md)制作镜像并记录源码与输入校验值。
3. 执行[测试指南](fresh-vm-test.md)中的回归和独立安装检查。
4. 将已验证的版本信息、测试结果和限制写入版本报告。

构建产物存放于忽略的目录，不应提交进源码仓库。Linux 脚本使用 LF 换行；
从 Windows 环境交付构建源码时，使用 git archive 导出 Git 中的内容。

## 文档与发布约定

- README 介绍产品、下载入口、使用要求与文档导航。
- 使用指南说明操作步骤；开发指南说明维护方法。
- 验证报告记录具体版本、环境、结果和限制，不混入日常使用说明。
- 早期计划、方案比较和开发过程记录放入[历史目录](history/README.md)。
- Release 保留安装镜像分卷、校验文件和必要的合并助手；截图、报告和构建清单放入仓库文档。

ISO 和校验文件应在完成验收后发布。修改说明文档不代表重新构建了镜像；
保持已发布镜像的文件名、校验值和构建来源准确。
