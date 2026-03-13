#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_TRIPLE="x86_64-pc-windows-msvc"
BUILD_DIR="${ROOT_DIR}/.build/windows-x64"
STAGE_DIR="${BUILD_DIR}/payload"
DIST_DIR="${BUILD_DIR}/dist"
LAUNCHER_NAME="OpenClaw Launcher.exe"
DRY_RUN="${DRY_RUN:-0}"

LAUNCHER_SRC="${ROOT_DIR}/target/${TARGET_TRIPLE}/release/launcher-app.exe"
APP_PAYLOAD_DIR="${ROOT_DIR}/packaging/windows/payload/app"
DATA_PAYLOAD_DIR="${ROOT_DIR}/packaging/windows/payload/data"
NSIS_SCRIPT="${ROOT_DIR}/packaging/windows/openclaw-installer.nsi"

run() {
  echo "+ $*"
  if [[ "${DRY_RUN}" != "1" ]]; then
    "$@"
  fi
}

ensure_git_bash() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *)
      if [[ "${DRY_RUN}" == "1" ]]; then
        echo "DRY_RUN: skipping Git Bash environment enforcement"
        return 0
      fi
      echo "this script must run under Git Bash / MSYS2 on Windows" >&2
      exit 1
      ;;
  esac
}

to_windows_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s\n' "$1"
  fi
}

main() {
  ensure_git_bash

  mkdir -p "${STAGE_DIR}/app" "${STAGE_DIR}/data" "${DIST_DIR}"
  if [[ "${DRY_RUN}" != "1" ]]; then
    rm -rf "${STAGE_DIR}/app" "${STAGE_DIR}/data"
    mkdir -p "${STAGE_DIR}/app" "${STAGE_DIR}/data"
  fi

  echo "[1/4] build launcher"
  run cargo build --release --target "${TARGET_TRIPLE}" -p launcher-app

  if [[ "${DRY_RUN}" != "1" && ! -f "${LAUNCHER_SRC}" ]]; then
    echo "missing launcher build output: ${LAUNCHER_SRC}" >&2
    exit 1
  fi

  if [[ "${DRY_RUN}" != "1" && ! -d "${APP_PAYLOAD_DIR}" ]]; then
    echo "missing app payload directory: ${APP_PAYLOAD_DIR}" >&2
    exit 1
  fi

  if [[ "${DRY_RUN}" != "1" && ! -d "${DATA_PAYLOAD_DIR}" ]]; then
    echo "missing data payload directory: ${DATA_PAYLOAD_DIR}" >&2
    exit 1
  fi

  echo "[2/4] stage payload"
  run cp "${LAUNCHER_SRC}" "${STAGE_DIR}/${LAUNCHER_NAME}"
  run cp "${ROOT_DIR}/manifest.json" "${STAGE_DIR}/manifest.json"
  run cp -R "${APP_PAYLOAD_DIR}/." "${STAGE_DIR}/app/"
  run cp -R "${DATA_PAYLOAD_DIR}/." "${STAGE_DIR}/data/"

  echo "[3/4] package with NSIS"
  local stage_dir_win
  local dist_dir_win
  local nsis_script_win
  stage_dir_win="$(to_windows_path "${STAGE_DIR}")"
  dist_dir_win="$(to_windows_path "${DIST_DIR}")"
  nsis_script_win="$(to_windows_path "${NSIS_SCRIPT}")"

  run makensis \
    -DPRODUCT_VERSION=0.1.0 \
    -DSTAGE_DIR="${stage_dir_win}" \
    -X"OutFile ${dist_dir_win}/OpenClaw-Setup.exe" \
    "${nsis_script_win}"

  echo "[4/4] done"
  echo "installer: ${DIST_DIR}/OpenClaw-Setup.exe"
}

main "$@"
