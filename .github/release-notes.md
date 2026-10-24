MacBar 2.5.3 Preview：重新设计偏好设置，并让新应用图标自动进入收集栏。

### 本次更新

- 浅色紧凑设置页，按顶部菜单栏、收集栏和不显示筛选图标。
- 辅助功能真实授权状态直接显示：已开启为绿色，未授权提示“先开启才能用”。
- 新增“新图标放到”全局选项；新应用创建菜单栏图标后自动加入，已有位置保持不变。
- 图标显示改为“标准图标”与“与顶部一致”。标准模式无需录屏，也不包含菜单栏未读数字。
- 首次选择“与顶部一致”时先说明 MacBar 的统一录屏授权；可取消并继续使用标准图标。
- 录屏授权与图标同步分别显示。只读取收集栏当前显示的图标，关闭收集栏后停止。
- 同步失败时保留可用的旧画面或标准图标，状态放在设置页和悬停提示中，收集栏不增加文字行。
- 新增 129 条回归断言和原生界面测试，覆盖新应用自动发现、权限流程、筛选、缩放及失败恢复。

### 安装

推荐下载 `MacBar-2.5.3-universal.pkg`，双击后按系统安装器提示完成安装。`universal` 表示同一个安装包同时支持 Apple Silicon 与 Intel Mac，要求 macOS 14+。偏好手动管理文件时也可下载 universal ZIP。更新前退出旧版。辅助功能权限用于移动和操作图标；标准图标无需录屏权限。

随附 SHA-256 文件，可运行 `shasum -a 256 -c MacBar-2.5.3-universal.pkg.sha256` 校验。应用为 ad-hoc 签名，安装器尚未通过 Apple 公证；首次打开可能需要系统“隐私与安全性 → 仍要打开”，无需全局关闭系统安全保护。

预览版仍使用私有窗口接口。真实飞书新消息的未读数字同步尚未完成实机验证；数字由独立窗口绘制或应用停止更新画面时，不能保证与顶部实时一致。完整兼容性说明见项目文档。

[安装说明](https://github.com/cold-summer/macbar/blob/main/docs/installation.md) · [已知限制](https://github.com/cold-summer/macbar/blob/main/docs/compatibility.md) · [反馈问题](https://github.com/cold-summer/macbar/issues/new/choose)

### English

MacBar 2.5.3 Preview redesigns the native preferences window and automatically adds newly discovered status icons to the configured destination. Accessibility status is shown directly, and the icon mode now distinguishes standard app icons from menu-bar-matching images. Native sync uses one MacBar-wide Screen Recording grant, runs only while the collection is open, and never saves screenshots or video. This remains a preview using private window APIs. Download the recommended universal PKG for macOS 14+, or use the ZIP for manual installation, and verify it with the accompanying SHA-256 file. Both formats support Apple Silicon and Intel Macs.
