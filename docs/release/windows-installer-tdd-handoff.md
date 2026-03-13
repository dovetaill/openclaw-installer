# TDD Handoff

## 已完成的 Red / Green 轨迹

- Task 2: `layout_tests.rs` 先失败，再实现 `InstallLayout`
- Task 3: `env_tests.rs` 先失败，再实现 env builder 与 OpenClaw 路径映射
- Task 4: `state_tests.rs` 先失败，再实现状态机与 Slint UI 骨架
- Task 5: `supervisor_tests.rs` 先失败，再实现端口探测与 readiness
- Task 6: `diagnostics_tests.rs` 先失败，再实现浏览器与 diagnostics 封装
- Task 7: `nsis-script-check.sh` 先失败，再补 NSIS 安装器脚本

## 当前验证入口

- `cargo check`
- `cargo test`
- `bash scripts/verify-payload.sh`
- `bash scripts/smoke-launcher.sh`
- `bash tests/smoke/nsis-script-check.sh`

## 当前已知限制

- 仓库尚未 vendored 真正的 `Node + OpenClaw` 离线 payload
- `scripts/verify-payload.sh` 与 `scripts/smoke-launcher.sh` 在 payload 缺失时会输出 `SKIP`
- `scripts/build-win-x64.sh` 依赖：
  - `cargo xwin`
  - `makensis`
  - `packaging/windows/payload/`

## 下一位接手者需要优先做的事

1. 引入真实离线 payload 到 `packaging/windows/payload/`
2. 用真实 payload 跑通：
   - `bash scripts/verify-payload.sh`
   - `bash scripts/smoke-launcher.sh`
3. 在 Debian 13 上安装并验证：
   - `cargo xwin`
   - `makensis`
4. 产出首个真实 `OpenClaw-Setup.exe`
