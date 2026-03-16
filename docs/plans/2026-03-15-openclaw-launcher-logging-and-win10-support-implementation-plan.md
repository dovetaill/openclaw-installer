# OpenClaw Launcher Logging And Win10 Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add install-local launcher logs and crash logs under `data\logs`, and update support statements to Windows 10 x64 plus Windows 11 x64.

**Architecture:** Keep the existing launcher structure intact. Add one std-only logging module in `crates/launcher-app`, initialize it before entering the Slint UI, and route panic plus top-level fatal failures through that module. Update documentation and smoke checklists to align support statements with the existing Node 22 runtime boundary.

**Tech Stack:** Rust std, Slint, Tokio, cargo test, Markdown docs

---

### Task 1: Add failing launcher logging tests

**Files:**
- Create: `crates/launcher-app/tests/logging_tests.rs`
- Modify: `crates/launcher-app/Cargo.toml` only if a new dependency becomes strictly necessary
- Reference: `crates/launcher-app/src/install_root.rs`
- Reference: `crates/runtime-config/src/layout.rs`

**Step 1: Write the failing test**

Add tests that assert:

- logger initialization creates `<temp>\data\logs`
- info/error records append to `launcher.log`
- crash records append to `launcher-crash.log`

**Step 2: Run test to verify it fails**

Run: `cargo test -p launcher-app --test logging_tests -- --nocapture`
Expected: FAIL because the logging module does not exist yet.

**Step 3: Write minimal implementation**

Do not implement yet. This task exists to establish red tests first.

**Step 4: Run test to verify it still fails for the expected reason**

Run: `cargo test -p launcher-app --test logging_tests -- --nocapture`
Expected: FAIL referencing the missing logging functions or module.

### Task 2: Implement launcher logging module

**Files:**
- Create: `crates/launcher-app/src/logging.rs`
- Modify: `crates/launcher-app/src/main.rs`
- Modify: `crates/launcher-app/src/app.rs` only if lightweight action-level error logging is needed
- Test: `crates/launcher-app/tests/logging_tests.rs`

**Step 1: Write minimal implementation**

Implement:

- install-root based log directory resolution
- `init_logging()`
- append helpers for `launcher.log` and `launcher-crash.log`
- panic record formatter
- top-level fatal logging path in `main`

**Step 2: Run targeted test**

Run: `cargo test -p launcher-app --test logging_tests -- --nocapture`
Expected: PASS

**Step 3: Refine**

Ensure the panic hook is installed once per process and does not require external crates.

**Step 4: Run focused regression tests**

Run: `cargo test -p launcher-app --test diagnostics_tests -- --nocapture`
Expected: PASS

### Task 3: Update support statements and diagnostics docs

**Files:**
- Modify: `docs/plans/2026-03-13-openclaw-windows-native-installer-design.md`
- Modify: `docs/release/windows-installer.md`
- Modify: `tests/smoke/install-layout.md`
- Reference: `packaging/windows/payload/app/openclaw/package.json`
- Reference: `packaging/windows/payload/app/openclaw/openclaw.mjs`

**Step 1: Update docs**

Change wording from Windows 11-only to Windows 10 x64 and Windows 11 x64 where the repo is describing its support target.

**Step 2: Document the launcher log files**

Mention `launcher.log` and `launcher-crash.log` under `data\logs`.

**Step 3: Run targeted verification**

Run: `cargo test -p launcher-app --test diagnostics_tests -- --nocapture`
Expected: PASS, confirming diagnostics assumptions still hold.

### Task 4: Run final verification

**Files:**
- Reference: `crates/launcher-app/tests/logging_tests.rs`
- Reference: `crates/launcher-app/tests/diagnostics_tests.rs`
- Reference: `crates/launcher-app/tests/install_root_tests.rs`

**Step 1: Run launcher test set**

Run:

```bash
cargo test -p launcher-app --test logging_tests -- --nocapture
cargo test -p launcher-app --test diagnostics_tests -- --nocapture
cargo test -p launcher-app --test install_root_tests -- --nocapture
```

Expected: all PASS

**Step 2: Review changed files**

Run: `git diff -- crates/launcher-app docs/release tests/smoke docs/plans`
Expected: only launcher logging and support-statement changes appear.

**Step 3: Commit**

```bash
git add crates/launcher-app docs/release tests/smoke docs/plans
git commit -m "feat: add launcher logs and support windows 10"
```
