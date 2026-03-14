#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_BIN="${ROOT_DIR}/target/x86_64-pc-windows-msvc/release/launcher-app.exe"

if [[ ! -f "${TARGET_BIN}" ]]; then
  echo "missing launcher binary: ${TARGET_BIN}" >&2
  echo "build it first with: cargo xwin build --release --target x86_64-pc-windows-msvc -p launcher-app" >&2
  exit 1
fi

if ! command -v objdump >/dev/null 2>&1; then
  echo "objdump is required to inspect Windows PE imports" >&2
  exit 1
fi

imports="$(objdump -p "${TARGET_BIN}")"

if grep -Eq 'DLL Name: VCRUNTIME140(_1)?\.dll' <<<"${imports}"; then
  echo "launcher-app.exe still depends on the Visual C++ runtime" >&2
  exit 1
fi

if grep -Eq 'DLL Name: api-ms-win-crt-' <<<"${imports}"; then
  echo "launcher-app.exe still depends on the Universal CRT redistributable" >&2
  exit 1
fi

echo "Launcher runtime dependency smoke check passed."
