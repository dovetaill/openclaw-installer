# OpenClaw Windows Installer

`openclaw-install` 是一个面向 `OpenClaw` 的 Windows 原生离线安装器项目。它的目标是在 Linux 开发环境中产出一个可分发的 `Setup.exe`，把 `Rust Launcher`、内置 `Node runtime`、`OpenClaw runtime` 和安装目录内的本地数据布局组合成一个可安装、可回滚、可诊断的 Windows 安装方案。

当前方案的核心原则：

- Windows 原生安装体验，使用 `NSIS` 生成安装包
- 安装目录自包含，不依赖系统级 `Node`
- `app / data` 双层布局，便于升级和保留用户数据
- `Launcher` 负责启动内置 gateway、打开浏览器、输出本地日志
- 运行时数据、配置、workspace、skills、日志都收口到安装目录

## 支持范围

- 支持：`Windows 10 x64`、`Windows 11 x64`
- 不支持：`Windows 7`
- 原因：打包的 OpenClaw runtime 依赖 `Node.js 22.x+`

## 主要特性

- `Rust + Slint + Tokio` 实现的原生 `Launcher`
- 内置 `node.exe` 和 OpenClaw runtime，避免依赖用户机器的全局 Node
- 日志目录固定在 `<InstallRoot>\data\logs`
- 支持默认使用中文翻译版 runtime，也支持切换为 upstream runtime
- 安装器和运行时元数据通过 `manifest.json` 统一描述

## 仓库结构

```text
.
├── crates/
│   ├── launcher-app/         # Windows Launcher
│   ├── process-supervisor/   # 子进程托管与 readiness 检测
│   └── runtime-config/       # 安装布局、环境变量、manifest 解析
├── docs/
│   ├── plans/                # 设计文档与实现计划
│   └── release/              # 发布与打包说明
├── packaging/windows/        # NSIS 安装器与 payload 布局
├── scripts/                  # 构建、校验、smoke 脚本
├── tests/smoke/              # 文本与脚本 smoke checks
├── manifest.json             # 安装器/运行时元数据
└── Cargo.toml                # Rust workspace
```

## 安装目录布局

安装后目录采用 `app / data` 双层结构：

```text
<InstallRoot>\
  OpenClaw Launcher.exe
  manifest.json
  uninstall.exe
  app\
    node\
    openclaw\
  data\
    config\
    workspace\
    skills\
    logs\
```

其中：

- `app\` 是可替换层，主要放运行时二进制和 payload
- `data\` 是保留层，主要放配置、workspace、skills 和日志

## 日志与诊断

Launcher 和内置 runtime 的日志都位于：

```text
<InstallRoot>\data\logs
```

常见日志文件：

- `launcher.log`：Launcher 启动、显式错误、动作失败日志
- `launcher-crash.log`：Launcher panic / fatal crash 详情
- `gateway.log`：内置 OpenClaw gateway 标准输出
- `gateway.err.log`：内置 OpenClaw gateway 标准错误

如果用户反馈“点开 launcher 直接闪退”，优先收集整个 `data\logs\` 目录。

## 构建前置条件

推荐在 Linux 环境中构建，当前仓库按 `Debian 13` 设计和验证。

常用依赖：

- `rustup` / `cargo`
- `cargo-xwin`
- `makensis`
- `curl`
- `python3`
- `node`（可选，用于部分 payload 校验）

Rust target 需要：

```text
x86_64-pc-windows-msvc
```

## 快速开始

### 1. 准备 payload

把离线 payload 放到：

```text
packaging/windows/payload/
```

至少需要包含：

- `app/node/node.exe`
- `app/openclaw/openclaw.mjs`
- `data/config/npmrc`

### 2. 校验 payload

```bash
bash scripts/verify-payload.sh
```

### 3. 运行 Rust 检查与测试

```bash
cargo check
cargo test
```

### 4. 生成 Windows 安装包

默认构建翻译版 runtime：

```bash
bash scripts/build-win-x64.sh
```

如果要切换到 upstream runtime：

```bash
bash scripts/build-win-x64.sh --runtime-source upstream
```

## 构建产物

默认输出目录：

```text
.build/windows-x64/
```

关键产物：

- `.build/windows-x64/dist/OpenClaw-Setup.exe`
- `.build/windows-x64/payload/`
- `.build/windows-x64/manifest.generated.json`

## 常用验证命令

```bash
cargo test -p launcher-app -- --nocapture
bash scripts/smoke-launcher.sh
bash tests/smoke/nsis-script-check.sh
```

说明：

- `scripts/smoke-launcher.sh` 会做 `cargo check`、`cargo test` 和静态断言
- 如果未放入真实 payload，部分脚本会以 `SKIP` 结束，而不是伪造通过

## 当前限制

- 仓库当前不自带完整的真实离线 payload，发布前需要在目标环境补齐
- 当前 launcher 记录文本日志，但没有接入 Windows WER / minidump
- 当前目标是 `x64 only`
- 更新策略是手动更新，不包含自动增量更新器

## 相关文档

- 发布与打包说明：[`docs/release/windows-installer.md`](docs/release/windows-installer.md)
- Windows 安装器设计：[`docs/plans/2026-03-13-openclaw-windows-native-installer-design.md`](docs/plans/2026-03-13-openclaw-windows-native-installer-design.md)
- Launcher 日志与 Win10 支持设计：[`docs/plans/2026-03-15-openclaw-launcher-logging-and-win10-support-design.md`](docs/plans/2026-03-15-openclaw-launcher-logging-and-win10-support-design.md)

## 备注

当前默认 runtime source 是：

- `translated`

对应包信息记录在 [manifest.json](manifest.json) 和构建脚本中。对外发布前，建议始终重新执行 payload 校验、launcher smoke 和 NSIS 检查。
