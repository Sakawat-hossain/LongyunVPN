# LongyunVPN（龙云）

[**English**](README.md)

一款基于 Clash.Meta（mihomo）内核的高速、安全、多平台 VPN 客户端。
LongyunVPN 接入龙云订阅服务，提供简洁、本地化的界面来管理服务器、订阅与流量。

作者：**Sakawat Hossain** · 采用 **GNU GPL-3.0** 协议（见 [LICENSE](LICENSE)）。

## 功能特性

- 基于内置 mihomo 内核的高性能代理
- 一键购买与续费订阅（套餐、优惠码、流量重置）
- 账户面板：套餐、到期时间、设备数、余额与用量
- 服务器页面在有有效订阅时才显示，并提供节点状态健康监控
- 单节点诊断（DNS / TCP / TLS / HTTP）及通俗易懂的修复建议
- 快速 TCP Ping 与 URL 延迟测试
- 完整本地化（English、简体中文、日本語、Русский）
- 通过 GitHub Releases 的应用内自动更新

## 平台

- **Windows** —— `amd64` / `arm64` 安装包（`.exe`）与便携版 `.zip`，支持应用内自动更新。
- **Android** —— 分架构 APK（`arm64-v8a`、`armeabi-v7a`、`x86_64`）及 Play `.aab`，应用 ID `com.longyunvpn.app`。
- **macOS** —— `arm64` / `amd64` `.dmg`。
- **Linux** —— `amd64` 的 `.deb`、`.AppImage`、`.rpm`（以及 `arm64` 的 `.deb`）。

移动端通过应用商店更新，桌面端在应用内检查 GitHub Releases。（暂不支持 iOS。）

## 在 macOS 上打开

macOS 版 `.dmg` 未使用 Apple 开发者 ID 签名，也未经过公证（这需要付费的 Apple
开发者账号），因此首次启动时 macOS 会提示
**“无法打开 LongyunVPN，因为它来自身份不明的开发者”**。这属于正常现象——应用本身是
安全的，只是 macOS 无法验证未签名的构建。打开方式：

1. 将 DMG 中的 **LongyunVPN** 拖入 **应用程序（Applications）** 文件夹。
2. 移除下载隔离标记后再打开。在 **终端（Terminal）** 中执行：

   ```bash
   xattr -dr com.apple.quarantine /Applications/LongyunVPN.app
   open /Applications/LongyunVPN.app
   ```

或者不使用终端：先尝试打开一次应用，然后进入
**苹果菜单 →「系统设置」→「隐私与安全性」**，向下滚动，点击 LongyunVPN 提示旁边的
**“仍要打开”**。此操作只需执行一次。

## 发布新版本

在 [`pubspec.yaml`](pubspec.yaml) 中修改版本号（纯语义化，例如 `version: 1.0.2`），
提交后推送对应标签：

```bash
git tag v1.0.2
git push origin v1.0.2
```

推送 `v*` 标签会触发 [`.github/workflows/release.yml`](.github/workflows/release.yml)，
并行构建全部平台（Windows、Android、macOS、Linux），并将所有产物发布到同一个 GitHub Release。

## 协议与致谢

本项目采用 GNU GPL-3.0 协议，并基于开源的
[mihomo / Clash.Meta](https://github.com/MetaCubeX/mihomo) 内核构建。
完整条款见 [LICENSE](LICENSE)。
