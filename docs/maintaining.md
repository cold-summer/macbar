# 维护与发布

## 日常检查

```bash
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

版本写在 `Info.plist` 的 `CFBundleShortVersionString`，构建号为 `CFBundleVersion`。发布前同步 CHANGELOG 和 README 的版本状态、测试数量、已知限制。不要把 GUI 未验证的功能写成已全面验证。

## 发布流程

1. 完成测试和变更审查，更新版本及构建号。
2. 推送到 `main`，等待 CI 通过。
3. 创建与应用版本匹配的标签，例如 `v2.5.0`，推送标签。
4. Release 工作流会重新测试并构建 universal ZIP 和 SHA-256，验证标签与应用版本一致，然后发布 **预览版**。
5. 在 Release 页面核对产物、安装说明、源代码链接和限制。无 Apple Developer ID / 公证凭证时，不要把预览包标为已公证。

工作流发布说明取自 `.github/release-notes.md`，发布前按版本更新该文件。它不会安装或启动应用，也不需要访问个人代码签名私钥。

## 发布包内容

- universal `MacBar.app`，内置 LICENSE 和 NOTICE。
- 中英文 README、CHANGELOG 和用户文档。
- 外部 SHA-256 校验文件。

GitHub 自动提供与标签对应的源代码归档。发布包不包含 `backups/`、用户偏好、日志、调试符号或本地证书。打包脚本使用 ad-hoc 签名；如后续提供 Developer ID / 公证分发，应单独设计凭证管理并更新用户文档。
