#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_TRIPLE="x86_64-pc-windows-msvc"
PROFILE="${PROFILE:-release}"
BUILD_DIR="${ROOT_DIR}/.build/launcher/windows-x64"
OUTPUT_NAME="OpenClaw Launcher.exe"
SOURCE_EXE="${ROOT_DIR}/target/${TARGET_TRIPLE}/${PROFILE}/launcher-app.exe"
OUTPUT_EXE="${BUILD_DIR}/${OUTPUT_NAME}"
DRY_RUN="${DRY_RUN:-0}"

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

main() {
  ensure_git_bash
  mkdir -p "${BUILD_DIR}"

  echo "[1/3] build Windows launcher from Git Bash"
  run cargo build --target "${TARGET_TRIPLE}" --profile "${PROFILE}" -p launcher-app

  echo "[2/3] collect artifact"
  if [[ "${DRY_RUN}" != "1" && ! -f "${SOURCE_EXE}" ]]; then
    echo "missing launcher artifact: ${SOURCE_EXE}" >&2
    exit 1
  fi
  run cp "${SOURCE_EXE}" "${OUTPUT_EXE}"

  echo "[3/3] done"
  echo "launcher: ${OUTPUT_EXE}"
}

main "$@"
