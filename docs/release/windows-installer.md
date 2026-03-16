# OpenClaw Windows Installer Runbook

## Support Target

- Supported: `Windows 10 x64`, `Windows 11 x64`
- Unsupported: `Windows 7`
- Rationale: the bundled OpenClaw runtime requires Node.js 22.x, which is not a supported Windows 7 runtime baseline.

## Build

1. 准备离线 payload 到 `packaging/windows/payload/`
2. 确认 payload 至少包含：
   - `app/node/node.exe`
   - `app/openclaw/openclaw.mjs`
   - `data/config/npmrc`
3. 运行 `bash scripts/verify-payload.sh`
4. 运行 `cargo check`
5. 运行 `cargo test`

## Package

1. 运行 `bash scripts/build-win-x64.sh`
2. 构建脚本会执行 `cargo xwin build --target x86_64-pc-windows-msvc -p launcher-app`
3. 构建脚本会把 `launcher-app.exe`、`manifest.json` 与 payload staged 到 `.build/windows-x64/payload/`
4. 构建脚本会调用 `makensis` 生成 `.build/windows-x64/dist/OpenClaw-Setup.exe`

## Install

1. 双击 `OpenClaw-Setup.exe`
2. 选择任意盘符与目录
3. 安装器会创建：
   - 桌面快捷方式 `OpenClaw Launcher.lnk`
   - 开始菜单目录 `OpenClaw`
   - 当前用户卸载入口 `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenClaw`
4. 安装后日志位于 `<InstallRoot>\data\logs\`
   - `launcher.log`
   - `launcher-crash.log`
   - `gateway.log` / `gateway.err.log`（当内置 runtime 成功启动并写日志时）

## Upgrade

1. 保留现有 `data\`
2. 用新版本安装包覆盖安装
3. 重点检查：
   - `manifest.json`
   - `app\`
   - `data\config\openclaw.json`
   - `data\workspace\`

## Rollback

1. 使用上一版本安装包覆盖当前版本
2. 保留 `data\config`、`data\workspace`、`data\skills`、`data\credentials`
3. 回滚后执行：
   - `bash tests/smoke/nsis-script-check.sh`
   - `bash scripts/verify-payload.sh`
   - `bash scripts/smoke-launcher.sh`

## Uninstall

1. 标准卸载：
   - 删除 `app\`
   - 删除 `OpenClaw Launcher.exe`
   - 删除快捷方式
   - 删除 `HKCU` 卸载信息
   - 默认保留 `data\`
2. 完全卸载：
   - 删除整个安装目录，包括 `data\`

## Verification Limits

- 当前仓库尚未 vendored 真实离线 payload，`scripts/verify-payload.sh` 与 `scripts/smoke-launcher.sh` 会在缺少 `packaging/windows/payload/` 时以 `SKIP` 形式提示，而不是伪造通过。
- 当前 Debian 13 环境未实际执行 `makensis` 生成 `Setup.exe`；本阶段通过 NSIS 文本 smoke check、`cargo check` 与 `cargo test` 作为替代验证。
- 真实发布前必须在具备完整 payload 的环境中重新执行：
  - `bash scripts/verify-payload.sh`
  - `bash scripts/smoke-launcher.sh`
  - `bash tests/smoke/nsis-script-check.sh`
