# 应用图标 / Application icon

`AppIcon.svg` 是为 MacBar 制作的矢量母版：深蓝底、三个白色菜单项与浅蓝收纳托盘表达菜单栏收集功能。方案经 AI 辅助探索后以矢量重绘，确保透明边缘干净。`AppIcon.png` 是供文档预览的导出图。

`scripts/make-icon.sh` 使用 macOS 自带的 `sips` 和 `iconutil`，直接从矢量母版生成 16–1024 像素的标准 `.icns` 尺寸；每次构建自动放入应用的 `Contents/Resources/MacBar.icns`。

此图用于 Spotlight、访达及系统应用信息。菜单栏中的单色四格操作按钮保持简洁，适配系统明暗外观。

本目录素材按项目 [GPL-3.0-or-later](../LICENSE) 许可证提供。
