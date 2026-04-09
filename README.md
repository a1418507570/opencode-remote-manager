# OpenCode Remote Manager

<p align="center">
  <a href="https://github.com/a1418507570/opencode-remote-manager/actions/workflows/ci.yml"><img src="https://github.com/a1418507570/opencode-remote-manager/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/a1418507570/opencode-remote-manager/releases"><img src="https://img.shields.io/github/v/release/a1418507570/opencode-remote-manager?display_name=tag" alt="Latest Release"></a>
  <a href="https://github.com/a1418507570/opencode-remote-manager/blob/main/LICENSE"><img src="https://img.shields.io/github/license/a1418507570/opencode-remote-manager" alt="License"></a>
</p>

<p align="center">
  A macOS menu bar app for managing two OpenCode remote connections and exposing localhost remotes.
</p>

<p align="center">
  <a href="https://github.com/a1418507570/opencode-remote-manager">GitHub Repository</a>
</p>

**Language / 语言**: [中文](#chinese) · [English](#english)

---

<a id="chinese"></a>
## 中文

**导航**: [概览](#zh-overview) · [功能](#zh-features) · [安装](#zh-installation) · [开发](#zh-development) · [打包](#zh-packaging) · [发布](#zh-release) · [许可与社区](#zh-license-community)

<a id="zh-overview"></a>
### 概览

OpenCode Remote Manager 是一个开源 macOS 菜单栏应用，用于管理两个 OpenCode 远程连接，并将 localhost remote 稳定暴露给本机工作流。它面向日常使用，重点是常驻、状态清晰和操作简单。

<a id="zh-features"></a>
### 功能

- 菜单栏常驻，快速查看连接与健康状态
- 管理两个固定的 OpenCode remote 连接
- 维护 SSH 隧道与 localhost remote 暴露
- 支持登录后自动启动，减少手动干预
- 提供 CLI 诊断与常用运维命令

<a id="zh-installation"></a>
### 安装

- 发布版本可从 [GitHub Releases](https://github.com/a1418507570/opencode-remote-manager/releases) 下载
- 打包产物名称为 `dist/OpenCodeRemoteManager-macOS.zip`
- 解压后将应用移入 Applications 并启动

<a id="zh-development"></a>
### 开发

要求：

- macOS 14+
- Swift 6.3+

```bash
git clone https://github.com/a1418507570/opencode-remote-manager.git
cd opencode-remote-manager
swift build
DYLD_FRAMEWORK_PATH="/Library/Developer/CommandLineTools/Library/Developer/Frameworks" \
DYLD_LIBRARY_PATH="/Library/Developer/CommandLineTools/Library/Developer/usr/lib" \
swift test -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib
swift run OpenCodeRemoteManagerCLI diagnose --json
```

<a id="zh-packaging"></a>
### 打包

```bash
./Scripts/package-app.sh
./Scripts/package-release.sh
```

发布压缩包输出到 `dist/OpenCodeRemoteManager-macOS.zip`。

<a id="zh-release"></a>
### 发布

- CI 工作流文件：`.github/workflows/ci.yml`
- 发布标签格式：`v*`，例如 `v0.1.0`
- 建议在 GitHub Release 中附上 `dist/OpenCodeRemoteManager-macOS.zip`

<a id="zh-license-community"></a>
### 许可与社区

- 许可证：[Apache-2.0](LICENSE)
- 贡献说明：[CONTRIBUTING.md](CONTRIBUTING.md)
- 社区行为：[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- 安全反馈：[SECURITY.md](SECURITY.md)

---

<a id="english"></a>
## English

**Navigation**: [Overview](#en-overview) · [Features](#en-features) · [Installation](#en-installation) · [Development](#en-development) · [Packaging](#en-packaging) · [Release](#en-release) · [License & Community](#en-license-community)

<a id="en-overview"></a>
### Overview

OpenCode Remote Manager is an open-source macOS menu bar app for managing two OpenCode remote connections and exposing localhost remotes to local workflows. It is built for day to day use, with a focus on always-on presence, clear status, and simple operation.

<a id="en-features"></a>
### Features

- Menu bar first experience with quick connection and health visibility
- Management for two fixed OpenCode remote connections
- SSH tunnel handling and localhost remote exposure
- Login-time auto start for less manual setup
- CLI diagnostics and operator commands when needed

<a id="en-installation"></a>
### Installation

- Download releases from [GitHub Releases](https://github.com/a1418507570/opencode-remote-manager/releases)
- The packaged artifact is `dist/OpenCodeRemoteManager-macOS.zip`
- Unzip the app bundle, move it into Applications, and launch it

<a id="en-development"></a>
### Development

Requirements:

- macOS 14+
- Swift 6.3+

```bash
git clone https://github.com/a1418507570/opencode-remote-manager.git
cd opencode-remote-manager
swift build
DYLD_FRAMEWORK_PATH="/Library/Developer/CommandLineTools/Library/Developer/Frameworks" \
DYLD_LIBRARY_PATH="/Library/Developer/CommandLineTools/Library/Developer/usr/lib" \
swift test -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib
swift run OpenCodeRemoteManagerCLI diagnose --json
```

<a id="en-packaging"></a>
### Packaging

```bash
./Scripts/package-app.sh
./Scripts/package-release.sh
```

The release archive is written to `dist/OpenCodeRemoteManager-macOS.zip`.

<a id="en-release"></a>
### Release

- CI workflow file: `.github/workflows/ci.yml`
- Release tags should follow `v*`, for example `v0.1.0`
- Attach `dist/OpenCodeRemoteManager-macOS.zip` to the GitHub release

<a id="en-license-community"></a>
### License & Community

- License: [Apache-2.0](LICENSE)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)
- Code of Conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Security: [SECURITY.md](SECURITY.md)
