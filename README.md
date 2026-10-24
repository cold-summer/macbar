<div align="center">

<img src="assets/AppIcon.png" width="96" height="96" alt="MacBar 应用图标">

# MacBar

**把拥挤的 Mac 菜单栏，收进随手可用的一行。**

原生 macOS 菜单栏管理工具 · Objective-C / AppKit · 无第三方运行依赖

[![CI](https://github.com/cold-summer/macbar/actions/workflows/ci.yml/badge.svg)](https://github.com/cold-summer/macbar/actions/workflows/ci.yml)
[![macOS](https://img.shields.io/badge/macOS-14%2B-111827?logo=apple)](#系统要求)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/cold-summer/macbar?include_prereleases)](https://github.com/cold-summer/macbar/releases)

[下载预览版](https://github.com/cold-summer/macbar/releases) · [安装指南](docs/installation.md) · [反馈问题](https://github.com/cold-summer/macbar/issues/new/choose) · [English](README.en.md)

![MacBar 功能示意：顶部菜单栏、收集栏和不显示三种位置](docs/assets/overview.svg)

</div>

MacBar 将不常用的菜单栏图标收进一个悬浮收集栏，保留常用图标在顶部。需要时点开收集栏，打开应用或继续操作原生菜单。**默认使用应用图标，不捕获屏幕；仅管理应用本身提供的右上角状态图标，不是所有运行中应用的启动器。**

> **预览状态：** 当前版本为 **2.5.3 Preview**。当前源码已有 129 条回归断言，部分交互在本机验证过；所有第三方应用、显示器组合及 macOS 版本尚未逐一验证。它使用私有窗口接口，系统升级可能影响兼容性。

## 功能

| 功能 | 使用方式 |
| --- | --- |
| 三种显示位置 | 顶部菜单栏、收进 MacBar、不显示；隐藏项可在设置中恢复 |
| 新图标自动加入 | 全局选择收集栏或顶部；新应用创建菜单栏图标后自动处理，不改变已有位置 |
| 原样图标（默认关闭） | 明确开启并授权后，仅在收集栏打开时读取原生画面，每 3 秒刷新；系统会显示捕获提示 |
| 通用左右键 | 普通客户端左键打开应用；右键打开原生托盘菜单，无应用名单 |
| 常驻工具操作 | 面板型工具保留原生左键；操作时鼠标跟随到顶部图标 |
| 明暗适配 | 按原生内容明暗调整收集栏背景，不反色或重染品牌图标 |
| 顺序与持久化 | 收集栏单独排序，设置重启后保留 |
| 安全恢复 | 原生菜单关闭后回收图标；失败最多自动重试 3 次，随后等待手动重试 |
| 多显示器处理 | 按当前屏幕的菜单栏尺寸和窗口身份识别，支持负坐标布局 |

## 系统要求

- macOS **14.0 或更新版本**。
- 发布 PKG 和 ZIP 都包含 Apple Silicon 与 Intel 两种架构。
- **辅助功能权限**：用于移动菜单栏图标和转发点击。
- **屏幕录制权限（可选，默认不使用）**：仅为主动开启的原样图标模式读取图标和文字画面；检测图标、移动图标、打开应用不需要它。

目前界面为简体中文。测试覆盖和已知限制见 [兼容性说明](docs/compatibility.md)。

## 安装与首次使用

1. 从 [Releases](https://github.com/cold-summer/macbar/releases) 下载推荐使用的 `MacBar-版本号-universal.pkg`，双击后按安装器提示完成安装。
2. 安装器会把 MacBar 放到 `/Applications`，完成后直接打开。偏好手动管理文件时也可下载 universal ZIP，解压后放入 `~/Applications` 或 `/Applications`。
3. 在偏好设置的“辅助功能”区域点击“去开启…”，允许 MacBar。页面读取系统实际授权状态：已开启显示绿色，未开启显示“先开启才能用”。
4. “图标显示”默认选择“标准图标”，无需录屏。如需同步顶部数字和状态文字，选择“与顶部一致”。首次设置会解释系统录屏权限的用途，再由你授权；按系统提示重新打开应用。授权对象是 MacBar，不需要每安装一个应用就重新设置。已授权不代表正在使用。
5. 左键点击菜单栏中的四格图标打开收集栏；右键打开设置、展开全部或重新应用布局。

下载包采用 ad-hoc 签名，**尚未通过 Apple 公证**，macOS 可能阻止首次打开。确认来源和校验值后，使用系统“隐私与安全性”中的“仍要打开”；不需要关闭 Gatekeeper。详细步骤及源码安装见 [安装指南](docs/installation.md)。

### 点击规则

| 图标类型 | 左键 | 右键 |
| --- | --- | --- |
| 普通应用 | 通过系统重新打开正在运行的应用，图标保持收起 | 临时显示顶部图标并打开原生菜单 |
| 常驻面板工具、系统图标 | 临时显示顶部图标并转发原生左键 | 转发原生右键 |

规则根据应用运行类型和 `LSUIElement` / `LSBackgroundOnly` 声明判断，不按应用名称或 bundle ID 特判。应用自己决定重新打开后的窗口；声明为常驻工具但仍提供主窗口的应用可能保留原生操作。悬停图标可查看当前点击动作。

“不显示”只是从顶部和收集栏隐藏图标，不会退出对应应用。“展开全部”、退出 MacBar 或缺少辅助功能权限时会展开图标，便于恢复操作。

### 收集栏会显示飞书等应用的未读数字吗？

| 图标模式 | 收集栏内容 | 未读数字与动态文字 | 录屏权限 |
| --- | --- | --- | --- |
| 标准图标（默认） | 应用本身的图标，与顶部状态图标的外观可能不同 | 不自动显示；没有独立读取飞书消息数或 Dock 角标的接口 | 无需 |
| 与顶部一致（可选） | 读取顶部对应菜单栏图标窗口的画面 | 数字画在同一窗口内时可随图像保留；收集栏打开时每 3 秒刷新 | 统一为 MacBar 授权，无需逐个应用设置 |

顶部同步不是消息推送订阅，也不会自行生成未读角标。数字由独立窗口绘制、应用离屏后不重绘或窗口读取失败时，未必能同步；失败时可能保留上次画面或回退为应用图标，可在设置页和图标悬停提示中查看状态。尚未用真实新到达的飞书消息验证未读数同步。

### 为什么启动应用后没有出现？

自动检测的对象是右上角的菜单栏状态图标。Dock 中的应用图标、左上角“文件 / 编辑”应用菜单，不是可收进 MacBar 的状态图标。应用没有创建状态图标时，MacBar 不会替它创建一个；它仍可从 Dock、Spotlight 或访达打开。这不依赖录屏权限。

## 从源码构建

安装 Xcode Command Line Tools 后：

```bash
git clone https://github.com/cold-summer/macbar.git
cd macbar
./scripts/test.sh
./scripts/build.sh
./scripts/install.sh
```

默认构建当前机器架构，安装到 `~/Applications/MacBar.app`；安装前测试并备份旧应用，不自动启动。未配置签名证书时使用 ad-hoc 签名。如果已有名为 `MacBar Local Codesign` 的本地代码签名证书，会自动沿用。

```bash
# 使用自己的固定签名身份，便于保留系统授权
MACBAR_SIGN_IDENTITY="Your Code Signing Identity" ./scripts/install.sh

# 构建两种架构并打包，不安装、不启动
MACBAR_SIGN_IDENTITY=- ./scripts/package.sh
```

构建参数、签名与更新说明见 [安装指南](docs/installation.md)；贡献代码前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 隐私

MacBar 不包含遥测、账号系统、自动更新器或应用内网络请求。图标捕获、设置和诊断都在本机处理。

- 设置保存在 macOS 用户偏好中。
- 图标画面仅在内存缓存，不保存为图片文件。
- 原样模式默认关闭；2.5.0 的默认开启状态不会自动沿用，需要重新明确开启。关闭原样模式或关闭收集栏后，不再调用图像捕获接口。
- 运行日志位于 `~/Library/Logs/MacBar/events.jsonl`。
- 诊断摘要位于 `/tmp/macbar-row.txt`，可能含应用名称、图标文字和窗口标识。**分享日志前请先检查并脱敏。**

权限范围、故障排查和卸载方式见 [安装指南](docs/installation.md) 与 [故障排查](docs/troubleshooting.md)。

## 项目文档

- [安装、更新与卸载](docs/installation.md)
- [已知限制和验证范围](docs/compatibility.md)
- [故障排查与诊断](docs/troubleshooting.md)
- [代码结构与工作原理](docs/architecture.md)
- [更新日志](CHANGELOG.md)
- [参与贡献](CONTRIBUTING.md) · [安全问题](SECURITY.md) · [行为准则](CODE_OF_CONDUCT.md)

## 许可证与致谢

MacBar 使用 **GPL-3.0-or-later** 许可证。底层窗口捕获与菜单栏事件处理参考并改编了 [Ice](https://github.com/jordanbaird/Ice) 的相关实现，保留其来源及许可声明，详见 [NOTICE](NOTICE)。MacBar 由本仓库独立维护，与 Apple 及 Ice 作者无隶属关系。

欢迎提交可复现的问题和改进建议。请勿在 Issue 中直接公开未经检查的个人日志或截图。
