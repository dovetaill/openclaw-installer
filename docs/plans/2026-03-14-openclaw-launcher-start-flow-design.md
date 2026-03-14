# OpenClaw Launcher Start Flow Design

## Background

The current Windows launcher handles the `重新打开 Web UI` action synchronously on the UI thread. It preflights a port, starts the embedded OpenClaw gateway, waits up to 5 seconds for localhost readiness, and then tries to open the browser.

This creates four user-visible problems:

- The UI can appear frozen while startup work is in progress.
- Repeated clicks during startup can trigger additional launch attempts.
- The fixed 5 second readiness window is too short for cold starts on Windows.
- Failures are collapsed to `State: Error` without any actionable detail.

## Goals

1. Keep the launcher window responsive while starting the embedded gateway.
2. Enforce single-flight startup inside one launcher process.
3. Increase readiness waiting so slow but valid cold starts do not get reported as failures.
4. Surface concrete startup and browser-open failures in the launcher UI.
5. Clean up failed launches so retries do not accumulate orphan processes.

## Non-Goals

- Adding cross-process machine-wide single-instance coordination.
- Reworking the launcher into a tray app or service.
- Changing the embedded runtime layout or gateway command line.
- Adding persistent telemetry or external logging infrastructure.

## Options Considered

### Option A: Full worker-thread command bus

Move launcher state and process management into a dedicated worker thread, send commands from the UI, and post results back via Slint event-loop callbacks.

Pros:

- Strong separation between UI and background work.
- Natural home for richer lifecycle orchestration.

Cons:

- Larger refactor than this bugfix needs.
- More moving parts for command routing, shutdown, and testing.

### Option B: Slint async event-loop task with interior mutability

Keep the existing launcher structure, but refactor launcher/process state to use interior mutability and expose async start/stop operations. Trigger startup from the UI callback via `slint::spawn_local(...)`, guard duplicate starts with `Starting` status, and update UI status/detail text as results arrive.

Pros:

- Smallest change that addresses the actual failure mode.
- Keeps existing launcher/process-supervisor structure and tests relevant.
- Matches Slint’s documented async patterns for UI responsiveness.

Cons:

- Still keeps orchestration logic inside the launcher crate instead of a dedicated worker layer.

## Decision

Adopt Option B.

The launcher already has the right lifecycle boundaries. The bug is not architectural enough to justify introducing a separate command bus. Refactoring the launcher and supervisor to support async start without blocking the event loop is sufficient and lower risk.

## Behavioral Design

### Button behavior

- If the gateway is `Ready`, clicking `重新打开 Web UI` opens the browser only.
- If the gateway is `Starting`, clicking again does not start another process. The UI keeps showing startup progress.
- If the gateway is `Idle` or `Error`, clicking starts a new launch attempt asynchronously.

### Startup lifecycle

- The launcher enters `Preflight`, then `Starting`, without blocking the window.
- The embedded gateway process is spawned once.
- Readiness waits significantly longer than 5 seconds.
- On success, the launcher enters `Ready`, clears any previous error detail, and opens the browser.
- On failure or timeout, the launcher enters `Error`, kills the failed child process, and shows a concrete error string plus recent stderr output when available.

### Error visibility

The UI will show two separate concepts:

- `State`: coarse lifecycle state (`Idle`, `Starting`, `Ready`, `Error`, etc.)
- `Detail`: actionable status/error text such as missing embedded runtime, timeout waiting for localhost, browser-open failure, or last stderr lines from the gateway

## Testing Strategy

Required coverage:

- State transitions include startup and failure behavior.
- Repeated launch requests during `Starting` are ignored.
- Failure detail formatting includes stderr context when present.
- Existing launcher smoke checks continue to pass.

## Implementation Notes

- Prefer Slint’s documented async pattern rather than manual UI-thread blocking.
- Avoid holding `RefCell` borrows across `.await`.
- Ensure failed launch attempts clean up child process state before allowing retry.
