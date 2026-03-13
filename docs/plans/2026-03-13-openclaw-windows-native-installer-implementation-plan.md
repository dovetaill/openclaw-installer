# OpenClaw Windows 原生离线安装器 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个可在 Debian 13 上产出 Windows 11 x64 离线安装包的 OpenClaw 原生安装器项目，提供 `NSIS Setup.exe`、`Rust Launcher`、自包含 `Node + OpenClaw` 运行时，以及可验证的安装、启动、诊断与回滚链路。

**Architecture:** 项目采用 `app/data` 双层布局。`NSIS` 负责安装与卸载，`Rust + Slint + Tokio` 的 `Launcher` 负责路径重定向、OpenClaw 子进程托管、readiness 检测、浏览器引导与诊断入口。配置、workspace 与 skills 严格复用 OpenClaw 官方模型，通过 `OPENCLAW_HOME`、`OPENCLAW_STATE_DIR`、`OPENCLAW_CONFIG_PATH` 和 `NPM_CONFIG_USERCONFIG` 收口到安装目录。

**Tech Stack:** Rust, Slint, Tokio, cargo-xwin, NSIS, Node.js, OpenClaw payload, Bash, Windows x64

---

## 实施前说明

- 当前工作区几乎为空，implementation 需要先建立项目骨架。
- 本计划默认最终工程会被纳入 git 管理；如果执行时仓库仍未初始化，应在 Task 1 中补 `git init`。
- 本计划默认只实现已确认范围：
  - `x64 only`
  - `当前用户安装`
  - `按需启动`
  - `浏览器 onboarding`
  - `手动更新`
  - `无系统级 Node / PATH / Service / Scheduled Task`
- 本计划中的命令以 Linux 开发机为执行环境；Windows 行为通过构建产物和脚本验证，不要求当前阶段真实执行安装。

## 目录目标

实施完成后，项目应至少包含以下结构：

```text
Cargo.toml
rust-toolchain.toml
crates/
  launcher-app/
  runtime-config/
  process-supervisor/
packaging/
  windows/
scripts/
tests/
docs/
  plans/
  release/
manifest.json
```

## Task 1: 初始化 Rust 工作区与目录骨架

**Files:**
- Create: `Cargo.toml`
- Create: `rust-toolchain.toml`
- Create: `crates/launcher-app/Cargo.toml`
- Create: `crates/launcher-app/src/main.rs`
- Create: `crates/runtime-config/Cargo.toml`
- Create: `crates/runtime-config/src/lib.rs`
- Create: `crates/process-supervisor/Cargo.toml`
- Create: `crates/process-supervisor/src/lib.rs`
- Create: `packaging/windows/.gitkeep`
- Create: `scripts/.gitkeep`
- Create: `tests/smoke/.gitkeep`

**Step 1: 初始化版本控制（如果仓库尚未初始化）**

Run:

```bash
git rev-parse --is-inside-work-tree || git init
```

Expected: 输出 `true`，或完成仓库初始化。

**Step 2: 创建 Rust workspace 根配置**

Write:

```toml
[workspace]
members = [
  "crates/launcher-app",
  "crates/runtime-config",
  "crates/process-supervisor",
]
resolver = "2"
```

到 `Cargo.toml`。

**Step 3: 固定 toolchain 与 Windows target**

Write:

```toml
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy"]
targets = ["x86_64-pc-windows-msvc"]
```

到 `rust-toolchain.toml`。

**Step 4: 创建三个 crate 的最小骨架**

Write minimal skeletons:

```rust
fn main() {
    println!("openclaw launcher bootstrap");
}
```

到 `crates/launcher-app/src/main.rs`。

```rust
pub fn placeholder() {}
```

到 `crates/runtime-config/src/lib.rs` 与 `crates/process-supervisor/src/lib.rs`。

**Step 5: 创建空目录占位**

Run:

```bash
mkdir -p packaging/windows scripts tests/smoke
touch packaging/windows/.gitkeep scripts/.gitkeep tests/smoke/.gitkeep
```

Expected: 三个目录可见，后续任务可直接写入。

**Step 6: 运行 workspace 元数据检查**

Run:

```bash
cargo metadata --format-version 1 >/tmp/openclaw-installer-metadata.json
```

Expected: 成功退出，并生成 metadata JSON。

**Step 7: 运行基础编译检查**

Run:

```bash
cargo check
```

Expected: PASS，无缺失 workspace member 错误。

**Step 8: Commit**

```bash
git add Cargo.toml rust-toolchain.toml crates packaging scripts tests
git commit -m "chore: initialize installer workspace skeleton"
```

## Task 2: 定义离线 payload 与安装目录模型

**Files:**
- Create: `manifest.json`
- Create: `crates/runtime-config/src/layout.rs`
- Create: `crates/runtime-config/src/manifest.rs`
- Modify: `crates/runtime-config/src/lib.rs`
- Test: `crates/runtime-config/tests/layout_tests.rs`

**Step 1: 写安装目录模型的失败测试**

Write:

```rust
#[test]
fn install_layout_builds_expected_paths() {
    let layout = InstallLayout::new("D:\\OpenClaw".into());
    assert_eq!(layout.app_dir().to_string_lossy(), "D:\\OpenClaw\\app");
    assert_eq!(layout.data_dir().to_string_lossy(), "D:\\OpenClaw\\data");
    assert_eq!(layout.openclaw_config_path().to_string_lossy(), "D:\\OpenClaw\\data\\config\\openclaw.json");
}
```

到 `crates/runtime-config/tests/layout_tests.rs`。

**Step 2: 运行测试确认失败**

Run:

```bash
cargo test -p runtime-config install_layout_builds_expected_paths -- --exact
```

Expected: FAIL，提示 `InstallLayout` 未定义或路径不匹配。

**Step 3: 定义 layout 类型**

Write minimal implementation:

```rust
pub struct InstallLayout {
    root: std::path::PathBuf,
}
```

并补齐 `app_dir()`、`data_dir()`、`openclaw_config_path()`、`node_dir()`、`workspace_dir()` 等方法到 `crates/runtime-config/src/layout.rs`。

**Step 4: 定义 manifest 模型**

Write minimal manifest types:

```rust
#[derive(Debug, Clone, serde::Deserialize, serde::Serialize)]
pub struct PayloadManifest {
    pub version: String,
    pub node_version: String,
    pub entries: Vec<BundleEntry>,
}
```

到 `crates/runtime-config/src/manifest.rs`。

**Step 5: 暴露公共接口**

Modify `crates/runtime-config/src/lib.rs`:

```rust
pub mod layout;
pub mod manifest;
```

**Step 6: 创建 manifest 模板**

Write:

```json
{
  "version": "0.1.0",
  "node_version": "24.x",
  "entries": [
    { "name": "node", "path": "app/node" },
    { "name": "openclaw", "path": "app/openclaw" }
  ]
}
```

到 `manifest.json`。

**Step 7: 运行测试确认通过**

Run:

```bash
cargo test -p runtime-config
```

Expected: PASS，至少 `layout_tests` 通过。

**Step 8: Commit**

```bash
git add manifest.json crates/runtime-config
git commit -m "feat: define payload manifest and install layout model"
```

## Task 3: 实现 OpenClaw 路径重定向与 env 组装

**Files:**
- Create: `crates/runtime-config/src/env.rs`
- Create: `crates/runtime-config/src/openclaw_paths.rs`
- Modify: `crates/runtime-config/src/lib.rs`
- Test: `crates/runtime-config/tests/env_tests.rs`

**Step 1: 写 env builder 的失败测试**

Write:

```rust
#[test]
fn launcher_env_sets_openclaw_paths_and_local_npmrc() {
    let layout = InstallLayout::new("D:\\OpenClaw".into());
    let envs = build_launcher_env(&layout);
    assert_eq!(envs["OPENCLAW_HOME"], "D:\\OpenClaw\\data");
    assert_eq!(envs["OPENCLAW_STATE_DIR"], "D:\\OpenClaw\\data");
    assert_eq!(envs["OPENCLAW_CONFIG_PATH"], "D:\\OpenClaw\\data\\config\\openclaw.json");
    assert_eq!(envs["NPM_CONFIG_USERCONFIG"], "D:\\OpenClaw\\data\\config\\npmrc");
}
```

到 `crates/runtime-config/tests/env_tests.rs`。

**Step 2: 运行测试确认失败**

Run:

```bash
cargo test -p runtime-config launcher_env_sets_openclaw_paths_and_local_npmrc -- --exact
```

Expected: FAIL，提示 `build_launcher_env` 未定义。

**Step 3: 实现 OpenClaw 路径映射**

Write `crates/runtime-config/src/openclaw_paths.rs`:

```rust
pub struct OpenClawPaths {
    pub home: std::path::PathBuf,
    pub state_dir: std::path::PathBuf,
    pub config_path: std::path::PathBuf,
    pub workspace_dir: std::path::PathBuf,
    pub managed_skills_dir: std::path::PathBuf,
}
```

并提供从 `InstallLayout` 派生这些路径的方法。

**Step 4: 实现 env builder**

Write `crates/runtime-config/src/env.rs`，最少包含：

- `build_launcher_env(&InstallLayout) -> BTreeMap<String, String>`
- `child_process_path(&InstallLayout, &std::env::VarsOs) -> String`

确保只为子进程扩展 `PATH`。

**Step 5: 固定 npm 镜像配置写法**

在 `env builder` 对应的逻辑中明确使用 `data/config/npmrc`，并约束该文件应包含：

```ini
registry=https://registry.npmmirror.com/
```

**Step 6: 暴露模块**

Modify `crates/runtime-config/src/lib.rs`:

```rust
pub mod env;
pub mod openclaw_paths;
```

**Step 7: 运行测试确认通过**

Run:

```bash
cargo test -p runtime-config
```

Expected: PASS，env 与 layout 相关测试都通过。

**Step 8: Commit**

```bash
git add crates/runtime-config
git commit -m "feat: add openclaw path redirection and env builder"
```

## Task 4: 实现 Launcher UI 骨架与状态机

**Files:**
- Modify: `crates/launcher-app/Cargo.toml`
- Create: `crates/launcher-app/src/app.rs`
- Create: `crates/launcher-app/src/state.rs`
- Modify: `crates/launcher-app/src/main.rs`
- Create: `crates/launcher-app/ui/main-window.slint`
- Test: `crates/launcher-app/tests/state_tests.rs`

**Step 1: 写状态机失败测试**

Write:

```rust
#[test]
fn state_machine_transitions_idle_to_preflight_to_starting() {
    let mut state = LauncherState::Idle;
    state = state.next(LauncherEvent::BeginPreflight);
    assert_eq!(state, LauncherState::Preflight);
    state = state.next(LauncherEvent::PreflightPassed);
    assert_eq!(state, LauncherState::Starting);
}
```

到 `crates/launcher-app/tests/state_tests.rs`。

**Step 2: 运行测试确认失败**

Run:

```bash
cargo test -p launcher-app state_machine_transitions_idle_to_preflight_to_starting -- --exact
```

Expected: FAIL，提示 `LauncherState` 未定义。

**Step 3: 添加 UI 依赖**

Modify `crates/launcher-app/Cargo.toml`，引入最少依赖：

- `slint`
- `tokio`
- `runtime-config`
- `process-supervisor`

**Step 4: 实现状态机**

Write `crates/launcher-app/src/state.rs`，定义：

- `LauncherState`
- `LauncherEvent`
- `next()` 转换方法

至少覆盖：

- `Idle`
- `Preflight`
- `Starting`
- `Ready`
- `Error`
- `Stopping`

**Step 5: 创建 Slint 主窗口**

Write minimal UI 到 `crates/launcher-app/ui/main-window.slint`：

- 显示状态文本
- 显示当前安装目录
- 显示当前端口
- 预留“打开 Web UI”“查看日志”“退出”按钮

**Step 6: 在 app/main 中绑定 UI 与状态**

Modify `crates/launcher-app/src/app.rs` 与 `src/main.rs`，实现：

- 启动窗口
- 状态文本更新
- UI 事件分发到状态机

**Step 7: 运行测试与编译检查**

Run:

```bash
cargo test -p launcher-app
cargo check -p launcher-app
```

Expected: PASS，Launcher 可编译，状态测试通过。

**Step 8: Commit**

```bash
git add crates/launcher-app
git commit -m "feat: scaffold launcher ui and state machine"
```

## Task 5: 实现子进程托管、端口探测与 readiness 检测

**Files:**
- Create: `crates/process-supervisor/src/port_probe.rs`
- Create: `crates/process-supervisor/src/readiness.rs`
- Create: `crates/process-supervisor/src/supervisor.rs`
- Modify: `crates/process-supervisor/src/lib.rs`
- Create: `crates/launcher-app/src/launcher.rs`
- Modify: `crates/launcher-app/src/app.rs`
- Test: `crates/process-supervisor/tests/supervisor_tests.rs`

**Step 1: 写端口与 readiness 失败测试**

Write tests for:

```rust
#[test]
fn chooses_next_available_port_when_default_is_occupied() { /* ... */ }

#[tokio::test]
async fn does_not_report_ready_before_probe_succeeds() { /* ... */ }
```

到 `crates/process-supervisor/tests/supervisor_tests.rs`。

**Step 2: 运行测试确认失败**

Run:

```bash
cargo test -p process-supervisor
```

Expected: FAIL，提示 `port_probe` / `readiness` / `supervisor` 缺失。

**Step 3: 实现端口探测**

Write `crates/process-supervisor/src/port_probe.rs`：

- 检查默认端口 `18789`
- 冲突时按顺序尝试下一个端口
- 返回最终可用端口

**Step 4: 实现 readiness 检测**

Write `crates/process-supervisor/src/readiness.rs`：

- 等待进程已启动
- 轮询本地端口或 HTTP/WS readiness
- readiness 成功前不允许进入 `Ready`

**Step 5: 实现子进程监督器**

Write `crates/process-supervisor/src/supervisor.rs`：

- 启动内置 `node.exe`
- 传入 OpenClaw 入口参数
- 注入 Task 3 的 env map
- 收集 stdout/stderr
- 提供 stop/restart/status 接口

**Step 6: 将监督器接入 Launcher**

Write `crates/launcher-app/src/launcher.rs` 并修改 `src/app.rs`：

- preflight
- start
- wait ready
- update UI state

**Step 7: 运行测试与编译检查**

Run:

```bash
cargo test -p process-supervisor
cargo check
```

Expected: PASS，端口冲突和 readiness 行为可测试。

**Step 8: Commit**

```bash
git add crates/process-supervisor crates/launcher-app
git commit -m "feat: supervise openclaw process and readiness flow"
```

## Task 6: 实现浏览器引导与诊断入口

**Files:**
- Create: `crates/launcher-app/src/browser.rs`
- Create: `crates/launcher-app/src/diagnostics.rs`
- Modify: `crates/launcher-app/src/app.rs`
- Modify: `crates/launcher-app/ui/main-window.slint`
- Test: `crates/launcher-app/tests/diagnostics_tests.rs`

**Step 1: 写诊断入口失败测试**

Write:

```rust
#[test]
fn diagnostics_commands_target_local_embedded_runtime() {
    let cmds = diagnostics_commands("D:\\OpenClaw");
    assert!(cmds.iter().any(|c| c.contains("openclaw config validate")));
    assert!(cmds.iter().any(|c| c.contains("openclaw skills check")));
}
```

到 `crates/launcher-app/tests/diagnostics_tests.rs`。

**Step 2: 运行测试确认失败**

Run:

```bash
cargo test -p launcher-app diagnostics_commands_target_local_embedded_runtime -- --exact
```

Expected: FAIL，提示 `diagnostics_commands` 未定义。

**Step 3: 实现浏览器打开逻辑**

Write `crates/launcher-app/src/browser.rs`：

- 接收 ready 后的本地 URL
- 调用系统默认浏览器
- 对失败返回可显示的错误

**Step 4: 实现诊断命令封装**

Write `crates/launcher-app/src/diagnostics.rs`：

- `open log dir`
- `open config dir`
- `openclaw config validate`
- `openclaw skills check`

确保命令都基于本地内置 runtime 与安装根目录。

**Step 5: 接入 UI 按钮**

Modify `crates/launcher-app/ui/main-window.slint` 与 `src/app.rs`：

- “重新打开 Web UI”
- “打开日志目录”
- “打开配置目录”
- “验证配置”
- “检查 skills”

**Step 6: readiness 成功后调用浏览器**

Modify `crates/launcher-app/src/app.rs`：

- only after `LauncherState::Ready`
- 已运行实例复用时也可重新打开浏览器

**Step 7: 运行测试与编译检查**

Run:

```bash
cargo test -p launcher-app
cargo check -p launcher-app
```

Expected: PASS，诊断命令与 UI 按钮绑定可编译。

**Step 8: Commit**

```bash
git add crates/launcher-app
git commit -m "feat: add browser onboarding handoff and diagnostics"
```

## Task 7: 实现 NSIS 安装器与卸载逻辑

**Files:**
- Create: `packaging/windows/openclaw-installer.nsi`
- Create: `packaging/windows/include/layout.nsh`
- Create: `packaging/windows/include/uninstall.nsh`
- Create: `scripts/build-win-x64.sh`
- Test: `tests/smoke/nsis-script-check.sh`

**Step 1: 写 NSIS 行为检查脚本**

Write a smoke checker to assert script text includes:

- current-user uninstall registration
- desktop/start menu shortcuts
- no system PATH mutation
- no service creation

到 `tests/smoke/nsis-script-check.sh`。

**Step 2: 运行检查确认失败**

Run:

```bash
bash tests/smoke/nsis-script-check.sh
```

Expected: FAIL，因为 NSIS 脚本尚不存在。

**Step 3: 编写 layout 常量与宏**

Write `packaging/windows/include/layout.nsh`：

- 安装目录变量
- `app` / `data` 子目录常量
- 快捷方式目标

**Step 4: 编写卸载宏**

Write `packaging/windows/include/uninstall.nsh`：

- 标准卸载
- 完全卸载
- `HKCU` 卸载信息清理

**Step 5: 编写主 NSIS 脚本**

Write `packaging/windows/openclaw-installer.nsi`：

- 目录选择
- 文件释放
- 快捷方式
- 当前用户级卸载登记
- 不修改系统 `PATH`
- 不安装系统级 `Node`
- 不创建服务/计划任务

**Step 6: 编写 Linux 构建脚本**

Write `scripts/build-win-x64.sh`：

- `cargo xwin build --target x86_64-pc-windows-msvc`
- payload 准备
- NSIS 打包

**Step 7: 运行脚本文本检查**

Run:

```bash
bash tests/smoke/nsis-script-check.sh
```

Expected: PASS，脚本文本满足约束。

**Step 8: Commit**

```bash
git add packaging/windows scripts/build-win-x64.sh tests/smoke/nsis-script-check.sh
git commit -m "feat: add nsis installer and uninstall packaging"
```

## Task 8: 建立验证链与发布文档

**Files:**
- Create: `scripts/verify-payload.sh`
- Create: `scripts/smoke-launcher.sh`
- Create: `tests/smoke/install-layout.md`
- Create: `docs/release/windows-installer.md`
- Modify: `docs/plans/2026-03-13-openclaw-windows-native-installer-design.md`

**Step 1: 写 payload 完整性校验脚本**

Create `scripts/verify-payload.sh`，检查：

- `app/node/node.exe`
- `app/openclaw/openclaw.mjs`
- `data/config/npmrc`
- `manifest.json`

**Step 2: 写 Launcher 烟雾脚本**

Create `scripts/smoke-launcher.sh`，覆盖：

- `cargo check`
- `cargo test`
- Launcher 启动前后状态
- readiness 前不打开浏览器的检查逻辑

**Step 3: 写安装目录验证说明**

Create `tests/smoke/install-layout.md`，列出：

- `app/data` 分层检查
- env 重定向检查
- config/workspace/skills 路径检查
- diagnostics 入口检查

**Step 4: 写发布与回滚文档**

Create `docs/release/windows-installer.md`，包含：

- build
- package
- install
- upgrade
- rollback
- uninstall

**Step 5: 将实现验证链回写到设计文档**

Modify `docs/plans/2026-03-13-openclaw-windows-native-installer-design.md`，补一个简短引用段，指向 implementation plan 和 release 文档。

**Step 6: 运行完整验证命令**

Run:

```bash
cargo check
cargo test
bash scripts/verify-payload.sh
bash scripts/smoke-launcher.sh
bash tests/smoke/nsis-script-check.sh
```

Expected: 全部 PASS；若某项无法在当前环境执行，需要在 `docs/release/windows-installer.md` 中记录限制与替代检查方法。

**Step 7: 做最终审阅**

Checklist:

- 与设计文档一致
- 未引入自动更新、托盘、自启动
- 未引入系统级 Node / PATH / Service
- config/workspace/skills 仍复用 OpenClaw 官方模型

**Step 8: Commit**

```bash
git add scripts tests docs
git commit -m "docs: add verification chain and release runbook"
```

## 执行顺序

按以下顺序执行，不要跳步：

1. Task 1
2. Task 2
3. Task 3
4. Task 4
5. Task 5
6. Task 6
7. Task 7
8. Task 8

## 每任务通用要求

- 每完成一个 Task，先运行该 Task 指定测试，再进入下一项。
- 若测试失败，先在当前 Task 内修复，不要带着失败进入下一 Task。
- 每个 Task 完成后都应单独 commit。
- 若执行时发现目录或文件路径必须调整，必须先同步更新设计文档与本计划，再继续实现。

## 关键验收标准

- 可从 Debian 13 构建 Windows x64 `Launcher.exe`
- 可生成 `NSIS Setup.exe`
- 运行时仅依赖安装目录内的 `Node + OpenClaw`
- `OPENCLAW_HOME`、`OPENCLAW_STATE_DIR`、`OPENCLAW_CONFIG_PATH`、`NPM_CONFIG_USERCONFIG` 全部正确重定向
- 默认浏览器只在 readiness 达成后打开本地 Web UI
- `config / workspace / managed skills / workspace skills / bundled skills` 路径层级符合设计
- 不写系统 `PATH`
- 不安装系统级 `Node`
- 不创建服务、计划任务、默认自启动

## 交接说明

执行本计划时，优先参照以下文档：

- `docs/plans/2026-03-13-openclaw-windows-native-installer-design.md`
- `docs/release/windows-installer.md`

执行过程中若发现设计与现实约束冲突，先修订设计文档，再修订 implementation plan，然后再改代码。

