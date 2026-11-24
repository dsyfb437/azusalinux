# 测试指南

本指南适用于当前 deb 与 ISO 安装路径。已发布版本的测试结果见
[0.1.1 验证报告](l1-validation.md)，早期手工恢复测试见[历史资料](history/README.md)。

## 构建回归

在已安装构建依赖的 Linux 环境中运行：

```bash
python3 -m unittest discover -s tests -v
dpkg-buildpackage -b -us -uc
bash iso-remaster/check-debs.sh ..
```

回归覆盖包集、版本、架构、重复准备、目标 shell 通配符展开，以及真实 xorriso 引导镜像往返。

## 完整安装

使用独立空白虚拟磁盘，分别验证 BIOS 与 UEFI。记录 ISO 的 SHA256、
虚拟机配置、固件类型、Secure Boot 状态和安装日志。

1. 从最终 ISO 启动，等待安装及所有 late-commands 成功。
2. 正常关机，取消挂载或禁用虚拟光驱。
3. 从虚拟硬盘冷启动，完成串口或控制台密码登录。
4. 完成图形密码登录，检查实际桌面与中文输入。
5. 在新用户桌面终端运行：

```bash
bash /path/to/azusalinux/tests/verify-installed.sh
```

该脚本只读检查身份、包状态、GNOME 默认值、字体解析、壁纸、图标及工具执行。
还需单独确认根分区来源、实际固件类型、图形会话状态和失败服务。

## 升级回归

在已安装的测试系统中执行常规系统更新，再次启动和登录后重复安装验收。
重装 base-files 前后比较四个身份文件的内容，确认发行标识不被覆盖。

身份包的移除恢复测试会修改系统，**仅在可丢弃的 Ubuntu 基线虚拟机中运行**：

```bash
sudo env AZUSA_TEST_VM=1 bash tests/test-release-lifecycle.sh /path/to/release-debs
```

脚本验证安装/升级、base-files 重装、幂等安装、移除恢复厂商文件及 purge 后重装。

## 保存结果

版本报告应记录镜像与源码版本、测试环境、通过/失败项目及未测试范围。
保存原始日志和截图，公开资料中避免包含密码、令牌或无关的个人路径。
启动到 Live 桌面不能作为完整安装通过的依据。
