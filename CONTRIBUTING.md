# 参与贡献 / Contributing

欢迎提交问题、文档改进、兼容性修复和代码。中文或英文均可。

## 开始之前

- 搜索已有 Issue，避免重复；描述需求或复现步骤，不必先提出完整实现。
- 涉及新的点击规则或大幅架构变更时，先在 Issue 讨论预期行为。
- 安全问题按 [SECURITY.md](SECURITY.md) 私下报告，不要在公开 Issue 上传敏感信息。

## 本地开发

需要 macOS 14+ 和 Xcode Command Line Tools，无需第三方运行库。

```bash
git clone https://github.com/cold-summer/macbar.git
cd macbar
./scripts/test.sh
./scripts/build.sh
```

测试不会移动真实图标或修改日常偏好。实机测试前请退出其他 MacBar 副本；使用固定的签名身份和路径，避免不必要的权限重置。

## 实现约定

- 与位置、宽度或动态文字无关的稳定身份是持久化基础；不要用坐标或标题匹配不同窗口。
- 不维护应用名称或 bundle ID 的点击特例名单，优先使用可解释的通用规则。
- 原生点击一次投递一个 down/up 对；收到事件不等于用户界面已打开。
- 原生菜单打开时保留恢复任务；恢复失败必须有次数上限和可操作的提示。
- 新的系统接口或权限需要说明用途、失败路径及兼容性边界。
- 引入参考实现时保留许可证与来源，更新 NOTICE。

## 验证与 Pull Request

1. 运行 `./scripts/test.sh`，为行为变化补充有意义的回归测试。
2. 运行 `./scripts/build.sh`；涉及架构或分发时运行 `./scripts/package.sh`。
3. 涉及界面或跨进程交互时，记录 macOS 版本、架构、屏幕组合和实测应用。
4. PR 说明问题、改动后的行为、验证结果和仍未验证的范围。

自动测试是必要检查；CI 不能替代 Accessibility、Screen Recording 或真实原生菜单的实机测试。不要将备份、签名私钥、用户配置或未经脱敏的日志提交进仓库。

贡献按本项目的 GPL-3.0-or-later 许可证发布。请遵守 [行为准则](CODE_OF_CONDUCT.md)。

## English

Please include a reproducible problem, expected behavior and validation in your issue or pull request. Run the test and build scripts above. GUI and permission changes need hands-on validation in addition to CI. Do not introduce application-specific routing allowlists, unbounded retries, credentials or personal diagnostics. Contributions are licensed under GPL-3.0-or-later.
