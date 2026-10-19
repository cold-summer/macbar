# 安全政策 / Security Policy

## 支持范围

当前仅对最新公开预览版接收安全修复。预览版不提供固定响应或修复时限。

## 私密报告

请通过仓库 [Security → Report a vulnerability](https://github.com/cold-summer/macbar/security/advisories/new) 私密报告安全问题。不要把凭证、完整个人日志、屏幕内容或可直接滥用的细节发到公开 Issue。

建议包含受影响版本、macOS 版本、复现步骤、影响范围和最小化示例。请尽可能删除个人信息。

## 权限与本地数据

- 辅助功能权限用于跨进程图标移动及点击，屏幕录制权限用于菜单栏窗口画面捕获。
- 应用不包含遥测、账号系统、自动更新器或应用内网络请求。
- 日志和 `/tmp/macbar-row.txt` 可能包含应用名称、图标文字、进程和窗口标识。诊断数据不自动上传。
- 发布包采用 ad-hoc 签名，未通过 Apple 公证。请核对发布来源和 SHA-256；不需要全局关闭系统安全机制。

## English

Report vulnerabilities privately using [GitHub private vulnerability reporting](https://github.com/cold-summer/macbar/security/advisories/new). Include the affected version, environment, reproduction and impact, with personal information removed. Only the latest preview is supported, without a guaranteed response time. Accessibility and Screen Recording access are sensitive capabilities; local diagnostics may contain app and window details and are never automatically uploaded.
