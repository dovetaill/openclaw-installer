# OpenClaw Launcher Start Flow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `重新打开 Web UI` non-blocking, single-flight, slower-start tolerant, and visibly diagnosable in the Windows launcher.

**Architecture:** Refactor launcher and supervisor state to use interior mutability, run startup through `slint::spawn_local(...)`, and surface lifecycle/error detail back into the existing Slint window. Keep one managed gateway child per launcher process and clean it up on failed starts.

**Tech Stack:** Rust, Slint, Tokio, async-compat, cargo test, shell smoke tests

---

### Task 1: Lock Behavior With Failing Tests

**Files:**
- Modify: `crates/launcher-app/tests/state_tests.rs`
- Create: `crates/process-supervisor/tests/startup_error_tests.rs`
- Modify: `crates/process-supervisor/tests/supervisor_tests.rs`

**Step 1: Write failing tests**

Add tests that describe:

- repeated launch requests during `Starting` do not transition back into a fresh launch
- start failures can be formatted with stderr context
- a failed start resets supervisor state so a later retry is allowed

**Step 2: Run tests to verify they fail**

Run:

```bash
cargo test -p launcher-app --test state_tests -- --nocapture
cargo test -p process-supervisor --test startup_error_tests -- --nocapture
cargo test -p process-supervisor --test supervisor_tests -- --nocapture
```

Expected: FAIL because the current implementation has no single-flight startup helper, no structured startup failure detail, and no explicit failed-start cleanup behavior.

### Task 2: Refactor Supervisor For Async Single-Flight Start

**Files:**
- Modify: `crates/process-supervisor/src/supervisor.rs`
- Modify: `crates/process-supervisor/src/readiness.rs`
- Modify: `crates/launcher-app/src/launcher.rs`

**Step 1: Implement minimal async lifecycle changes**

- Replace blocking launcher startup with async start methods.
- Use interior mutability for supervisor status/current child/current port.
- Add a longer readiness timeout constant.
- On readiness timeout or other startup failure, stop and clear the child before returning the error.

**Step 2: Run focused tests**

Run:

```bash
cargo test -p process-supervisor --test startup_error_tests -- --nocapture
cargo test -p process-supervisor --test supervisor_tests -- --nocapture
```

Expected: PASS.

### Task 3: Make UI Launch Non-Blocking And Error-Visible

**Files:**
- Modify: `crates/launcher-app/src/app.rs`
- Modify: `crates/launcher-app/src/state.rs`
- Modify: `crates/launcher-app/ui/main-window.slint`
- Modify: `crates/launcher-app/src/metadata.rs`
- Modify: `crates/launcher-app/Cargo.toml`

**Step 1: Implement minimal UI behavior**

- Add a detail/status text field to the Slint window.
- Launch gateway startup through `slint::spawn_local(async_compat::Compat::new(...))`.
- If the supervisor is already `Starting`, do not spawn another launch task.
- If already `Ready`, reopen the browser only.
- Show concrete error/detail text for startup and browser failures.

**Step 2: Run launcher tests**

Run:

```bash
cargo test -p launcher-app --test state_tests -- --nocapture
cargo test -p launcher-app --test manifest_display_tests -- --nocapture
cargo test -p launcher-app --test launch_flow_tests -- --nocapture
```

Expected: PASS.

### Task 4: Full Verification

**Files:**
- Modify as needed based on previous tasks only

**Step 1: Run complete relevant verification**

Run:

```bash
cargo test
bash scripts/smoke-launcher.sh
```

Expected: PASS.

**Step 2: Commit**

```bash
git add crates/process-supervisor/src/supervisor.rs \
  crates/process-supervisor/src/readiness.rs \
  crates/process-supervisor/tests/startup_error_tests.rs \
  crates/process-supervisor/tests/supervisor_tests.rs \
  crates/launcher-app/src/app.rs \
  crates/launcher-app/src/launcher.rs \
  crates/launcher-app/src/state.rs \
  crates/launcher-app/ui/main-window.slint \
  crates/launcher-app/Cargo.toml \
  crates/launcher-app/tests/state_tests.rs \
  docs/plans/2026-03-14-openclaw-launcher-start-flow-design.md \
  docs/plans/2026-03-14-openclaw-launcher-start-flow-implementation-plan.md
git commit -m "fix: make launcher startup non-blocking and single-flight"
```
