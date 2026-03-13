# OpenClaw Windows 原生离线安装器设计

## 背景

`openclaw/openclaw` 当前是一个以 Node 为运行时的个人 AI assistant，官方文档对 Windows 的推荐路径仍偏向 `WSL2`。本方案的目标不是修改 OpenClaw 核心架构，而是在 **Debian 13** 开发环境中，为 **Windows 11 x64** 提供一个 **纯 Windows 原生、一键安装、目录自包含** 的离线安装方案。

本设计严格遵循以下已确认前提：

- 目标仓库是 `openclaw/openclaw`
- 安装形态是 **纯 Windows 原生安装**
- 技术栈限定为 `Rust + Slint + Tokio`
- 首发为 **x64 only**
- 首发为 **全离线安装包**
- 更新策略为 **手动更新**
- 安装权限模型为 **当前用户安装**
- 运行模式为 **按需启动，不常驻**
- 启动入口为 **Rust Launcher**
- 首次配置入口为 **浏览器 onboarding / Web UI**
- 打包范围为 **尽量全量包**
- 网络镜像需要兼容中国大陆，`npm` / skills 安装默认走 `registry.npmmirror.com`
- 安装过程不得污染系统级 `Node`、`PATH`、系统服务或默认 `C:` 盘固定目录

本方案同时遵循本地规范文件 `.codex/AGENTS.md` 的总体方向：

- 优先复用官方与标准生态能力
- 避免引入额外自研维护面
- 设计优先复用 OpenClaw 现有的 `config`、`workspace`、`skills`、CLI 与 onboarding 机制

## 目标

本方案的目标如下：

1. 为 Windows 11 用户提供一个可双击运行的 `Setup.exe`
2. 允许用户自由选择安装盘符和目录，不强制写入 `C:` 的固定位置
3. 将 `Node runtime`、`OpenClaw payload`、配置、状态、日志、workspace、skills 全部收口到安装目录内部
4. 安装完成后通过桌面图标启动 `Rust Launcher`，由 `Launcher` 托管 OpenClaw 网关进程
5. 在网关就绪后自动打开系统默认浏览器进入本机 `OpenClaw Web UI / onboarding`
6. 保留 Windows 原生安装体验，同时保持内部结构具备“绿色软件”的可迁移性
7. 为后续手动升级、修复安装、版本回退提供清晰边界

## 边界

本设计明确包含与不包含的范围如下。

包含：

- `NSIS` 安装器
- `Rust + Slint + Tokio` 启动器
- 自包含 `Node runtime`
- 自包含 `OpenClaw` 运行载荷
- 本地 `config / state / workspace / skills / logs`
- 桌面与开始菜单快捷方式
- 当前用户级卸载入口

不包含：

- `Windows Service`
- `Scheduled Task`
- 默认开机自启
- 系统托盘常驻
- 系统级 `Node` 安装
- 系统级 `PATH` 修改
- 全局写入 `ProgramData`
- 重写 OpenClaw 的浏览器 onboarding 为原生 Slint 配置器
- 自动增量更新器
- `arm64` 支持
- 与官方 OpenClaw 配置模型相冲突的 Windows 专用配置体系

## 方案对比

### 方案 A：`NSIS` 外层安装器 + `Rust Launcher` + 自包含运行时

这是最终推荐方案。

优点：

- 最符合“Windows 原生安装 + 绿色自包含”的双重目标
- 可在 `Debian 13` 上通过 `cargo-xwin` + `NSIS` 完整构建
- 用户体验最接近常规 Windows 软件
- 可严格限制所有运行时文件落在安装目录中
- 升级与回滚边界清晰，可将 `app` 与 `data` 分层处理

缺点：

- 需要实现自己的 `Launcher` 进程编排与诊断逻辑
- 离线全量包体积较大

### 方案 B：便携包优先 + 薄安装壳

优点：

- 自包含最彻底
- 卸载最简单
- 迁移目录最方便

缺点：

- Windows 原生安装感较弱
- 后续修复安装、升级与用户预期不如标准安装器自然

### 方案 C：双阶段本地部署器

优点：

- 主安装包可进一步拆层
- 后续扩展“修复安装 / 补装组件”空间更大

缺点：

- 首启链路更复杂
- 容错面更大
- 不符合首版“一键安装、稳定优先”的目标

## 最终决策

最终采用：

- **方案 A 作为主路线**
- 内部目录与运行方式吸收方案 B 的“便携自包含”原则

即：

- 外部形态是标准 Windows 安装器
- 内部结构是严格分层、可搬迁、可回滚的自包含运行目录

### 架构分层

推荐采用四层结构：

1. `Installer Layer`
   - 由 `NSIS Setup.exe` 负责安装与卸载
   - 只处理目录选择、文件落盘、快捷方式、卸载入口

2. `Launcher Layer`
   - 由 `Rust + Slint + Tokio` 实现 `OpenClaw Launcher.exe`
   - 负责环境检查、端口管理、子进程托管、浏览器打开、错误提示

3. `Runtime Layer`
   - 内置 `Node runtime`
   - 内置 `OpenClaw payload`
   - 不依赖系统级 `Node`

4. `State Layer`
   - 收口 `config`、`credentials`、`sessions`、`workspace`、`skills`、`logs`、`cache`
   - 避免散落到用户默认 `Home` 或 `AppData`

### 组件划分

- `NSIS Bootstrapper`
- `Launcher UI`
- `Launcher Core`
- `Process Supervisor`
- `Local Config Resolver`
- `Offline Payload Manager`

### 安装目录结构

推荐目录结构如下：

```text
<InstallRoot>\
  OpenClaw Launcher.exe
  uninstall.exe
  manifest.json

  app\
    node\
      node.exe
      npm
      npx
    openclaw\
      package.json
      openclaw.mjs
      dist\
      assets\
      docs\
      extensions\
      skills\
      node_modules\
    bundles\
      optional\
      offline-cache\

  data\
    launcher\
      launcher.json
      ports.json
      last-run.json
    config\
      openclaw.json
      .env
      npmrc
    credentials\
    agents\
    skills\
    workspace\
      AGENTS.md
      SOUL.md
      USER.md
      TOOLS.md
      IDENTITY.md
      HEARTBEAT.md
      memory\
      skills\
    logs\
    cache\
    tmp\
```

### 运行时约定

`Launcher` 每次启动 OpenClaw 时都显式注入：

- `OPENCLAW_HOME=<InstallRoot>\data`
- `OPENCLAW_STATE_DIR=<InstallRoot>\data`
- `OPENCLAW_CONFIG_PATH=<InstallRoot>\data\config\openclaw.json`
- `NPM_CONFIG_USERCONFIG=<InstallRoot>\data\config\npmrc`

额外约定：

- 仅对子进程临时扩展 `PATH`，绝不写系统 `PATH`
- 默认端口优先尝试 `18789`，冲突时自动寻找可用端口并写入 `data\launcher\ports.json`
- 快捷方式始终指向 `OpenClaw Launcher.exe`
- 关闭 `Launcher` 时默认结束本次 OpenClaw 进程树

### OpenClaw 配置、workspace 与 skills 设计

本方案不自定义一套新的配置系统，而是复用 OpenClaw 官方现有模型。

#### 配置文件

- 主配置文件为 `data\config\openclaw.json`
- 配置写入优先通过官方 onboarding / Web UI 完成
- 高级用户仍可直接编辑 `openclaw.json`
- 也允许通过 `openclaw config get/set/validate` 进行 CLI 级调整

#### workspace

使用 `data\workspace\` 作为 OpenClaw 工作区，对应官方 `~/.openclaw/workspace` 的角色。

其中包含：

- `AGENTS.md`
- `SOUL.md`
- `USER.md`
- `TOOLS.md`
- `IDENTITY.md`
- `HEARTBEAT.md`
- `memory\`
- `skills\`

设计原则：

- 不自行维护 Windows 专用 bootstrap 模板
- 首次启动时优先调用 OpenClaw 官方 `setup / onboard / configure` 机制生成缺失文件
- 避免与上游默认模板长期漂移

#### skills

skills 采用三层布局：

1. `app\openclaw\skills\`
   - OpenClaw 自带 `bundled skills`

2. `data\skills\`
   - 对应官方 `managed skills`

3. `data\workspace\skills\`
   - 对应官方 `workspace-specific skills`
   - 用于覆盖或补充 bundled / managed skills

skills 相关配置保留 OpenClaw 官方结构：

- `skills.allowBundled`
- `skills.load.extraDirs`
- `skills.load.watch`
- `skills.install.nodeManager`
- `skills.entries.<skillKey>`

默认策略：

- 默认启用 bundled skills
- 默认启用 `skills.load.watch`
- 默认不额外配置 `load.extraDirs`
- 默认 `skills.install.nodeManager = "npm"`
- 本地 `npmrc` 固定配置 `registry=https://registry.npmmirror.com/`

## 实施步骤

以下为推荐实施顺序，供后续 `implementation plan` 使用。

1. **确定 Windows 载荷边界**
   - 固定 `Node` 版本
   - 固定 OpenClaw 版本与离线载荷内容
   - 输出 `manifest.json`

2. **建立 Debian 13 -> Windows 构建链**
   - 使用 `cargo-xwin` 构建 `x86_64-pc-windows-msvc`
   - 使用 `NSIS` 打包 `Setup.exe`

3. **实现 `Rust Launcher`**
   - 用 `Slint` 提供状态界面
   - 用 `Tokio` 实现异步进程编排
   - 托管 `node.exe + OpenClaw`

4. **实现本地路径重定向**
   - 固定 `OPENCLAW_HOME`
   - 固定 `OPENCLAW_STATE_DIR`
   - 固定 `OPENCLAW_CONFIG_PATH`
   - 固定 `NPM_CONFIG_USERCONFIG`

5. **接入官方初始化与 onboarding**
   - 首次启动自动准备 `workspace`
   - 由 OpenClaw 官方机制 seed 缺失 bootstrap files
   - 网关 ready 后自动打开默认浏览器

6. **实现 `NSIS` 安装与卸载逻辑**
   - 自定义安装目录
   - 快捷方式创建
   - 当前用户级卸载信息写入
   - 修复安装与重装入口预留

7. **实现诊断与故障恢复入口**
   - 查看日志目录
   - 打开配置目录
   - 调用 `openclaw config validate`
   - 调用 `openclaw skills check`

8. **形成发布与升级模型**
   - `app` 作为可替换层
   - `data` 作为保留层
   - 手动更新通过新安装包覆盖 `app`

## 风险与回滚

### 主要风险

1. **离线全量包体积偏大**
   - 会影响下载与分发成本

2. **Windows 原生模块兼容性**
   - OpenClaw 依赖的部分 Node 模块在 Windows 上可能有额外兼容风险

3. **浏览器引导链路存在时序问题**
   - 浏览器可能在网关 ready 前打开

4. **配置与 skills 被用户破坏性修改**
   - `openclaw.json` 语法错误
   - `workspace skills` 覆盖 bundled skills 后行为漂移

5. **杀毒软件或系统策略锁文件**
   - 可能导致安装、升级、卸载失败

6. **升级后 `app` 与 `data` 之间存在版本不兼容**
   - 可能影响现有配置或 skills

### 回滚策略

回滚模型采用：

- `app` = 可替换资产
- `data` = 可保留资产

具体策略：

1. 升级失败时，允许重新安装上一版本安装包覆盖 `app`
2. 默认保留 `data\config`、`data\workspace`、`data\skills`、`data\credentials`、`data\agents`
3. payload 损坏时优先提供“修复安装 / 重装当前版本”
4. 配置损坏时优先恢复默认配置或引导用户手动修复
5. skills 异常时优先通过 `openclaw skills check` 定位，而不是由安装器自定义判断

### 卸载策略

建议提供两种卸载边界：

1. **标准卸载**
   - 删除 `app`
   - 删除 `Launcher`
   - 删除快捷方式
   - 删除当前用户卸载入口
   - 可选择保留 `data`

2. **完全卸载**
   - 删除整个安装目录，包括 `data`

## 验证清单

以下检查项用于证明该方案达到交付标准。

### 构建验证

- [ ] 可在 `Debian 13` 上构建 Windows `Launcher.exe`
- [ ] 可在 `Debian 13` 上生成可执行的 `Setup.exe`
- [ ] 安装包仅面向 `x64`

### 安装验证

- [ ] 安装器允许用户选择任意盘符与目录
- [ ] 不要求管理员权限即可完成当前用户安装
- [ ] 不写系统 `PATH`
- [ ] 不安装系统级 `Node`
- [ ] 不创建服务、计划任务、默认开机自启

### 运行验证

- [ ] 桌面图标启动的是 `OpenClaw Launcher.exe`
- [ ] `Launcher` 能正确拉起内置 `node.exe`
- [ ] OpenClaw 网关 ready 后才打开浏览器
- [ ] 如果已有网关运行，二次启动不重复拉起，只重新打开浏览器
- [ ] 关闭 `Launcher` 后默认结束当前 OpenClaw 进程树

### 目录自包含验证

- [ ] OpenClaw 配置写入 `data\config\openclaw.json`
- [ ] `credentials`、`sessions`、`skills`、`workspace`、`logs` 均落在安装目录内
- [ ] 不依赖用户默认 `~/.openclaw`
- [ ] 删除安装目录后，不残留主要运行时资产

### 配置与 skills 验证

- [ ] `workspace` 缺失时可由官方初始化逻辑补齐 bootstrap files
- [ ] `bundled skills`、`managed skills`、`workspace skills` 三层路径生效
- [ ] `workspace skills` 覆盖优先级符合 OpenClaw 官方模型
- [ ] `openclaw config validate` 可用于校验配置
- [ ] `openclaw skills check` 可用于校验 skills 可用性

### 大陆网络镜像验证

- [ ] 本地 `npmrc` 固定为 `registry.npmmirror.com`
- [ ] skills 相关 Node 安装行为默认继承该镜像设置
- [ ] 不污染系统用户级或全局级 `npm` 配置

### 升级与回滚验证

- [ ] 新版本安装包可覆盖 `app` 层并保留 `data`
- [ ] 回退到上一版本安装包后，用户配置与 workspace 仍可继续使用
- [ ] 标准卸载与完全卸载行为边界清晰

## 最终结论

针对 `openclaw/openclaw` 的 Windows 一键安装需求，推荐采用：

- **`NSIS` 外层安装器**
- **`Rust + Slint + Tokio` 启动器**
- **自包含 `Node + OpenClaw` 运行时**
- **`app / data` 明确分层**
- **浏览器 onboarding**
- **当前用户安装**
- **按需启动**
- **手动升级**

这是在以下约束下最平衡的方案：

- 开发环境是 `Debian 13`
- 目标环境是 `Windows 11`
- 需要中国大陆网络镜像
- 需要绿色、自包含、可选盘符安装
- 需要 Windows 原生安装体验

其核心原则只有两条：

1. **对外保持标准 Windows 安装器体验**
2. **对内保持可搬迁、可回滚、可诊断的自包含目录结构**

后续如需继续推进，应在本设计确认后，另行编写：

- `docs/plans/2026-03-13-openclaw-windows-native-installer-implementation-plan.md`

