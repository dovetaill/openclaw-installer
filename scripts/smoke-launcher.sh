#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_RS="${ROOT_DIR}/crates/launcher-app/src/app.rs"
LAUNCHER_RS="${ROOT_DIR}/crates/launcher-app/src/launcher.rs"
SUPERVISOR_RS="${ROOT_DIR}/crates/process-supervisor/src/supervisor.rs"

echo "[1/4] cargo check"
cargo check

echo "[2/4] cargo test"
cargo test

echo "[3/4] static launcher flow assertions"
rg -n 'LauncherEvent::BeginPreflight' "${APP_RS}" >/dev/null
rg -n 'LauncherEvent::Ready' "${APP_RS}" >/dev/null
rg -n 'LauncherEvent::StartFailed' "${APP_RS}" >/dev/null
rg -n 'browser::open_dashboard' "${APP_RS}" >/dev/null
rg -n 'wait_for_tcp_ready' "${SUPERVISOR_RS}" >/dev/null

echo "[4/4] payload-backed runtime smoke"
if [[ ! -f "${ROOT_DIR}/packaging/windows/payload/app/node/node.exe" ]]; then
  echo "SKIP: embedded payload not staged; runtime launch smoke reduced to static code checks" >&2
  exit 0
fi

echo "NOTE: staged payload detected. Add live launch smoke here once embedded payload is vendored."
