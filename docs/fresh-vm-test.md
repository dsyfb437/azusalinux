# 干净 VM 验证清单

目的：验证 README 里的恢复流程在**一台跟别处无关的系统**上成立。
现在这套东西是在一台机器上手工长出来的，只有跑通这一步，才算"可复现"。

## 0. 建 VM

- Ubuntu **26.04 Desktop**，全新安装
- 磁盘 ≥ 40G，内存 ≥ 4G
- **不要**在安装时勾选额外软件，保持默认
- 装完先别改任何设置

## 1. 把代码带进去

```bash
git clone https://github.com/dsyfb437/azusalinux.git
cd azusalinux
```

（离线环境才用 tar.gz 备用包。）

## 2. 按 README 跑

```bash
sudo apt install fonts-inter fastfetch papirus-icon-theme
./bin/azusa-mascot
python3 bin/azusa-apply --all --apply
sudo ./bin/azusa-apply --system --apply
sudo ./azusa-setup --apply
./install.sh
```

## 3. 验收

```bash
azusa-verify
```

**期望：0 项失败。** 如果有失败项，把输出贴回来——那就是流程缺的东西。

## 常见失败点

| 现象 | 原因 |
|---|---|
| gsettings 全部跳过 | 用 SSH 跑的，没有 DBus 会话；必须在桌面终端的图形会话里跑 |
| `Ptyxis profile 配色` 失败 | 新机器 profile uuid 不同，脚本会自动读，一般不会；若失败看 uuid 是否为空 |
| `文件夹颜色` 失败 | `--system` 没加 sudo |
| `壁纸文件` 缺失 | `azusa-mascot` 没跑，或跑的时候不在仓库目录 |
| apt 装不上 | 检查网络 / 源 |

## 这项测试**不能**验证什么

- 图形效果好不好看（只能人眼看）
- 显卡驱动、HiDPI、多显示器
- GRUB 菜单（`azusa-verify` 读不到时是 skip，需要重启看）

## 通过了之后

L0.5 → 具备做 L1（ISO）的前提：所有改动都有脚本可复现。
