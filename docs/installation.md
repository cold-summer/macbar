# 安装、更新与卸载

## 下载预览版

从 [GitHub Releases](https://github.com/cold-summer/macbar/releases) 下载 universal ZIP，解压后将 `MacBar.app` 移入 `~/Applications` 或 `/Applications`。无需安装额外运行库。

可在终端进入下载目录校验：

```bash
shasum -a 256 -c MacBar-2.5.3-universal.zip.sha256
```

校验文件与 ZIP 应来自同一 Release。校验值用于核对文件完整性，不能替代对发布来源的信任。

## 首次打开

发布包未经过 Apple 公证。若 macOS 阻止打开：

1. 确认下载自本项目 Release，并核对校验值。
2. 在“系统设置 → 隐私与安全性”找到刚被阻止的 MacBar，使用“仍要打开”。
3. 按系统提示确认。不同 macOS 版本的按钮位置和提示可能不同。

不要通过全局关闭 Gatekeeper 或关闭系统完整性保护来运行 MacBar。

## 授权

| 权限 | 用途 | 未授权时 |
| --- | --- | --- |
| 辅助功能 | 移动图标、转发原生点击 | 顶栏保持展开，不自动隐藏 |
| 屏幕录制 / 录屏与系统录音（标准模式不使用） | 选择“与顶部一致”后，读取收集栏实际显示的菜单栏图标画面 | 默认使用标准图标，仍可自动检测、移动和打开应用 |

1. 在 MacBar 设置中点击对应权限按钮。
2. 在系统权限列表中启用 `MacBar`。
3. 如果列表中没有它，用“+”选择实际安装的 `MacBar.app`。不要选择源码目录、ZIP 或 `Contents/MacOS` 内的裸可执行文件。
4. 如果 macOS 要求重新打开应用，请退出 MacBar 后从固定安装位置打开。

设置页直接显示系统实际授权结果：辅助功能已开启显示绿色，未授权显示“先开启才能用”。录屏权限与原始画面开关分开显示；绿色“录屏已授权”仅说明获得权限，是否使用由模式开关决定。从系统设置返回后，状态会在后续刷新时更新。

“标准图标”不需要操作录屏权限。选择“与顶部一致”后，只读取收集栏当前显示的图标窗口画面，关闭收集栏后停止。首次选择且未授权时先解释用途；可以前往系统设置，也可以继续使用标准图标。macOS 会显示“正在捕捉屏幕”的系统提示；这项提示无法通过只裁取图标消除。

授权对象是 MacBar，不是每个被管理的应用。安装新应用后无需再次录制或逐个授权：启动应用并让它创建菜单栏图标，MacBar 会自动发现并按“新图标放到”的全局设置处理。已有图标位置不变，系统图标默认留在顶部。权限被撤销或应用签名变化时，macOS 可能要求重新确认授权，这与新装了几个应用无关。

应用不采集音频。系统可能把这一权限放在“录屏与系统录音”页面；该页面名称不表示 MacBar 会录制系统音频。升级自旧版时，之前默认开启的原样模式会关闭，需要新的明确选择才会重新启用。

## 基本操作

- 左键点菜单栏四格按钮：打开收集栏。
- 右键点四格按钮：打开设置、展开全部、重新应用布局或退出。
- 设置中选择“顶部菜单栏”“收进 MacBar”“不显示”。
- “不显示”项可在设置的“不显示”筛选中恢复；对应应用仍在运行。
- 收集栏左键按应用类型打开客户端或转发原生操作；右键转发原生菜单。悬停可查看提示。
- 自动检测的是应用已有的右上角状态图标；没有状态图标的普通 Dock 应用不会凭启动就加入收集栏。

## 从源码安装

```bash
xcode-select --install
git clone https://github.com/cold-summer/macbar.git
cd macbar
./scripts/test.sh
./scripts/install.sh
```

如果 Command Line Tools 已安装，跳过第一步。脚本不需要 `sudo`，默认安装到当前用户的 `~/Applications`，且不会自动启动。

| 参数 | 默认值 | 用途 |
| --- | --- | --- |
| `MACBAR_SIGN_IDENTITY` | 已有 `MacBar Local Codesign` 证书，否则 `-` | 指定代码签名身份；`-` 表示 ad-hoc |
| `MACBAR_ARCHS` | 当前机器架构 | 构建 `arm64`、`x86_64` 或二者，以空格分隔 |
| `MACBAR_INSTALL_DIR` | `~/Applications` | 自定义安装目录；必须可写 |

```bash
MACBAR_SIGN_IDENTITY="Your Code Signing Identity" ./scripts/install.sh
MACBAR_ARCHS="arm64 x86_64" ./scripts/build.sh
./scripts/package.sh
```

打包脚本始终构建 universal 并采用 ad-hoc 签名；产物和校验值位于 `dist/`。构建产物不包含本机调试符号、备份或个人偏好。

## 更新与回滚

更新前从 MacBar 菜单退出，再用新版替换原安装位置的应用。尽量保持相同 bundle ID、安装路径及签名身份。更换身份、使用 ad-hoc 重新构建或系统权限状态变化时，macOS 可能要求重新授权。

源码安装脚本会将旧应用保存为项目 `backups/` 目录中的带时间戳 ZIP。回滚时先退出，再把备份中的应用恢复到原位置。发布包更新不包含这个自动备份步骤，可自行保留旧 ZIP。

## 卸载

1. 使用 MacBar 菜单的“退出”，让顶部图标展开。
2. 将已安装的 `MacBar.app` 移到废纸篓。
3. 如需删除授权，在系统权限列表中移除 MacBar。

偏好与日志默认保留，便于重装恢复。希望完全重置时，可自行删除 `~/Library/Preferences/cc.icc.macbar.plist`、`~/Library/Logs/MacBar/` 及 `/tmp/macbar-row.txt`；删除前应确认不再需要这些设置。不要删除其他应用的配置。
