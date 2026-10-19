MacBar 首个公开预览版：把不常用的菜单栏图标收进悬浮收集栏，保留常用图标在顶部。

### 下载与安装

1. 下载下方 `MacBar-2.5.0-universal.zip`，支持 Apple Silicon / Intel，要求 macOS 14+。
2. 解压，将 `MacBar.app` 放入 `~/Applications` 或 `/Applications`。
3. 打开并授予辅助功能权限；需要原生图标与动态文字时再授予屏幕录制权限。
4. 左键点菜单栏四格按钮打开收集栏，右键打开设置。

随附 `.sha256` 文件，可通过 `shasum -a 256 -c MacBar-2.5.0-universal.zip.sha256` 校验。发布包采用 ad-hoc 签名，**未通过 Apple 公证**。首次打开可能需要系统“隐私与安全性 → 仍要打开”，不需要全局关闭系统安全保护。

### 主要功能

- 顶部菜单栏、收进 MacBar、不显示三种位置，支持恢复和持久化排序。
- 保留完整原生图标、文字、宽度和颜色，自动适配背景明暗。
- 通用点击规则：普通应用左键重新打开客户端，右键原生菜单；常驻工具保留原生操作。
- 多显示器窗口身份校验、关闭菜单后恢复、失败最多自动重试 3 次。

### 验证与边界

111 条回归断言覆盖身份、点击、图像、布局与恢复。私有系统接口、部分系统图标、特殊第三方菜单及所有全屏/多屏组合尚未全面实机验收；请按预览软件使用。应用自己决定重新打开后显示哪个窗口。

无遥测、账号或应用内网络请求。日志本地保存，反馈前请脱敏。

[安装说明](https://github.com/cold-summer/macbar/blob/main/docs/installation.md) · [已知限制](https://github.com/cold-summer/macbar/blob/main/docs/compatibility.md) · [反馈问题](https://github.com/cold-summer/macbar/issues/new/choose) · [源代码与 GPL 许可证](https://github.com/cold-summer/macbar)

### English

First public preview. Download the universal ZIP for macOS 14+, move the app into Applications, and grant Accessibility access. Screen Recording is optional for native icon/text capture. Binaries are ad-hoc signed and not Apple-notarized; use macOS's per-app Open Anyway flow after verifying the source and checksum. Generic client reopening, native tray actions, reversible placement and bounded recovery are included. 111 regression assertions pass; full GUI compatibility across all applications and display arrangements is not guaranteed. See [README.en.md](https://github.com/cold-summer/macbar/blob/main/README.en.md).
