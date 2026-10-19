MacBar 2.5.2 Preview：新增专用应用图标，替换默认占位图。

### 本次更新

- 深蓝底、白色菜单项与浅蓝收纳托盘的新应用图标。
- 标准 16–1024 像素 ICNS，适用于 Spotlight、访达及系统应用信息。
- 源码构建自动生成多尺寸图标，安装后刷新应用注册。
- 保留 2.5.1 的隐私默认值：不捕获屏幕，原样图标需要主动开启，且只在收集栏可见时读取画面。

### 安装

下载 `MacBar-2.5.2-universal.zip`，支持 Apple Silicon / Intel，要求 macOS 14+。解压后将应用放入固定的 Applications 目录。更新前退出旧版，再替换原位置。辅助功能权限用于移动和操作图标，默认无需屏幕录制权限。

随附 SHA-256 文件，可运行 `shasum -a 256 -c MacBar-2.5.2-universal.zip.sha256` 校验。发布包为 ad-hoc 签名，尚未通过 Apple 公证；首次打开可能需要系统“隐私与安全性 → 仍要打开”，无需全局关闭系统安全保护。

117 条回归断言及 universal 构建在 CI 验证。预览版仍使用私有窗口接口，完整兼容性说明见项目文档。

[安装说明](https://github.com/cold-summer/macbar/blob/main/docs/installation.md) · [已知限制](https://github.com/cold-summer/macbar/blob/main/docs/compatibility.md) · [反馈问题](https://github.com/cold-summer/macbar/issues/new/choose)

### English

New dedicated application icon for Spotlight, Finder and system app information, with standard 16–1024px ICNS representations. Builds generate the icon from the included transparent PNG source. Screen capture remains off by default. Download the universal ZIP for macOS 14+, with the accompanying SHA-256 checksum. Binaries are ad-hoc signed and not Apple-notarized. See [README.en.md](https://github.com/cold-summer/macbar/blob/main/README.en.md).
