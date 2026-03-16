# Install Layout Smoke Checklist

## app / data 分层检查

- 确认安装根目录存在 `app\` 与 `data\` 两层。
- 确认 `OpenClaw Launcher.exe`、`manifest.json` 与 `uninstall.exe` 位于安装根目录。
- 确认 `app\node\` 与 `app\openclaw\` 被视为可替换层。
- 确认 `data\config\`、`data\workspace\`、`data\skills\`、`data\logs\` 被视为保留层。
- 确认 `data\logs\launcher.log` 与 `data\logs\launcher-crash.log` 使用安装目录内的本地路径。

## env 重定向检查

- `OPENCLAW_HOME=<InstallRoot>\data`
- `OPENCLAW_STATE_DIR=<InstallRoot>\data`
- `OPENCLAW_CONFIG_PATH=<InstallRoot>\data\config\openclaw.json`
- `NPM_CONFIG_USERCONFIG=<InstallRoot>\data\config\npmrc`
- 子进程 `PATH` 仅前置 `<InstallRoot>\app\node`，不写系统 `PATH`

## config / workspace / skills 路径检查

- `data\config\openclaw.json`
- `data\config\npmrc`
- `data\workspace\`
- `data\skills\`
- `app\openclaw\skills\`

## diagnostics 入口检查

- “重新打开 Web UI” 在 Ready 后重开本地浏览器
- “打开日志目录” 指向 `data\logs`
- `launcher.log` 记录 launcher 启动与显式错误
- `launcher-crash.log` 记录 panic / fatal crash 详情
- “打开配置目录” 指向 `data\config`
- “验证配置” 通过内置 `node.exe + openclaw.mjs config validate`
- “检查 skills” 通过内置 `node.exe + openclaw.mjs skills check`
