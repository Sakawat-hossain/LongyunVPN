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

- **Windows** —— 安装包（`LongyunVPN-Setup.exe`），支持应用内自动更新。
- **Android** —— APK（`LongyunVPN.apk`，应用 ID `com.longyunvpn.app`）。

## 发布新版本

在 [`pubspec.yaml`](pubspec.yaml) 中修改版本号（纯语义化，例如 `version: 1.0.2`），
提交后推送对应标签：

```bash
git tag v1.0.2
git push origin v1.0.2
```

推送 `v*` 标签会触发 [`.github/workflows/release.yml`](.github/workflows/release.yml)，
自动构建 Windows 安装包与 Android APK，并发布到 GitHub Release。

## 协议与致谢

本项目采用 GNU GPL-3.0 协议，并基于开源的
[mihomo / Clash.Meta](https://github.com/MetaCubeX/mihomo) 内核构建。
完整条款见 [LICENSE](LICENSE)。
