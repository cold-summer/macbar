MacBar 2.5.1 Preview：默认不捕获屏幕，并明确菜单栏图标的自动检测范围。

### 下载与安装

1. 下载下方 `MacBar-2.5.1-universal.zip`，支持 Apple Silicon / Intel，要求 macOS 14+。
2. 解压，将 `MacBar.app` 放入 `~/Applications` 或 `/Applications`。
3. 打开并授予辅助功能权限。默认无需屏幕录制权限。
4. 左键点菜单栏四格按钮打开收集栏，右键打开设置。

随附 `.sha256` 文件，可通过 `shasum -a 256 -c MacBar-2.5.1-universal.zip.sha256` 校验。发布包采用 ad-hoc 签名，**未通过 Apple 公证**。首次打开可能需要系统“隐私与安全性 → 仍要打开”，不需要全局关闭系统安全保护。

### 本次修复

- 默认使用应用图标，不读取屏幕画面；2.5.0 的默认开启状态不会自动沿用。
- 原样图标需重新明确开启，界面说明会触发 macOS 捕获提示；即使已允许权限，也只在收集栏可见时读取画面。
- 增加实际图像捕获调用次数，方便诊断是否仍在读取屏幕。
- 明确自动检测范围：应用已有的右上角状态图标，不会为只有 Dock 图标的普通应用创建状态项。
- 保留三种位置、通用左右键、多显示器处理和有上限的恢复任务。

### 验证与边界

117 条回归断言覆盖身份、点击、图像、布局、恢复，以及默认关闭、旧偏好迁移和后台不捕获。私有系统接口、部分系统图标、特殊第三方菜单及所有全屏/多屏组合尚未全面实机验收；请按预览软件使用。应用自己决定重新打开后显示哪个窗口。

无遥测、账号或应用内网络请求。日志本地保存，反馈前请脱敏。

[安装说明](https://github.com/cold-summer/macbar/blob/main/docs/installation.md) · [已知限制](https://github.com/cold-summer/macbar/blob/main/docs/compatibility.md) · [反馈问题](https://github.com/cold-summer/macbar/issues/new/choose) · [源代码与 GPL 许可证](https://github.com/cold-summer/macbar)

### English

Screen capture is now off by default, including after upgrading from 2.5.0. Native pixel capture requires a fresh explicit opt-in and runs only while the collection is visible. App discovery and movement do not require Screen Recording. MacBar manages existing status items, not every running application's Dock icon. Download the universal ZIP for macOS 14+; binaries are ad-hoc signed and not Apple-notarized. 117 regression assertions pass; GUI compatibility across every application and display arrangement is not guaranteed. See [README.en.md](https://github.com/cold-summer/macbar/blob/main/README.en.md).
