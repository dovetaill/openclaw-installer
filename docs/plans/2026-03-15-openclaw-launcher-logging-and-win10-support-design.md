# OpenClaw Launcher Logging And Win10 Support Design

## Summary

The Windows installer currently keeps OpenClaw runtime state under the install root, but the Rust launcher itself does not persist its own startup, fatal, or panic diagnostics. Users who report "launcher flashes and exits" can only inspect gateway logs if the embedded runtime started far enough to create them. This design adds launcher-owned log files under `<InstallRoot>\data\logs` and broadens the documented support target from Windows 11 x64 only to Windows 10 x64 and Windows 11 x64.

## Goals

1. Persist launcher startup and fatal diagnostics under the existing install-local `data\logs` directory.
2. Persist panic diagnostics with stack traces into a separate crash-focused log file.
3. Keep the launcher and gateway log roots colocated so support can request one folder from the user.
4. Update support statements to treat Windows 10 x64 and Windows 11 x64 as the supported target set.

## Non-Goals

- Implement Windows WER or minidump capture.
- Add a tray, service, or daemon process.
- Change the runtime layout away from install-local state.
- Claim Windows 7 compatibility.

## Current State

- The launcher resolves its install root from the launcher executable path.
- Diagnostics UI actions already point "Open log dir" at `<InstallRoot>\data\logs`.
- The embedded gateway inherits `OPENCLAW_HOME` and `OPENCLAW_STATE_DIR` as `<InstallRoot>\data`.
- The process supervisor buffers child stdout/stderr in memory and only surfaces recent stderr lines back into the UI.
- The launcher main entrypoint does not install a panic hook or persist top-level failures.

## Proposed Design

### Log Location

Reuse the existing install-local log directory:

- `launcher.log`: startup, shutdown, and explicit fatal/error events owned by the Rust launcher.
- `launcher-crash.log`: panic records and captured backtraces.
- Existing gateway logs remain in the same directory.

The launcher should create `data\logs` during logger initialization, before the Slint UI is constructed.

### Logger Shape

Add a small std-only launcher logging module inside `crates/launcher-app`:

- Resolve the install root using the existing `install_root` module.
- Derive the log directory from `InstallLayout`.
- Provide append-only helpers for `info`, `error`, and `crash`.
- Include timestamp, PID, and a short event label in each line.

Avoid external logging crates for this first pass. The goal is deterministic file creation and minimal packaging risk.

### Panic And Fatal Handling

Install a panic hook as early as possible in `main`:

- Write panic message, source location, thread name when available, and `Backtrace::force_capture()` to `launcher-crash.log`.
- Also append a one-line summary to `launcher.log`.

Wrap `app::run()` in explicit top-level error handling:

- On `Err`, append a fatal record to `launcher.log`.
- Return a non-zero exit code after logging.

This does not catch hard process termination by the OS, but it covers Rust panics and ordinary top-level failures, which are the gaps in the current implementation.

### Windows Support Statement

Update repo docs to state:

- Supported target: Windows 10 x64 and Windows 11 x64.
- Windows 7 is unsupported due to the bundled Node 22 runtime requirement.

This aligns the installer project with the runtime requirement already enforced by the packaged OpenClaw entrypoint.

## Testing Strategy

1. Add unit tests for logger path resolution and file append behavior under an install-root-shaped temp directory.
2. Add a test for panic record formatting and crash log file creation without requiring an actual crashing test process.
3. Keep launcher diagnostics tests green to confirm the log directory remains `data\logs`.
4. Run targeted launcher tests after implementation.

## Risks

- Panic hooks are global. Tests must avoid leaking hook state across cases.
- Backtrace formatting may vary by toolchain, so tests should assert stable substrings rather than exact full output.
- Launcher crashes caused by native aborts or OS-level faults still will not be captured by this change.

## Decision

Implement install-local launcher text logging now, keep the design std-only and low-risk, and explicitly support Windows 10 x64 alongside Windows 11 x64. Defer WER/minidumps unless real crash reports show the text logs are insufficient.
