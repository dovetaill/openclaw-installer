#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NSIS_SCRIPT="${ROOT_DIR}/packaging/windows/openclaw-installer.nsi"

if [[ ! -f "${NSIS_SCRIPT}" ]]; then
  echo "missing NSIS script: ${NSIS_SCRIPT}" >&2
  exit 1
fi

if ! command -v makensis >/dev/null 2>&1; then
  echo "skipped: makensis not installed"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

STAGE_DIR="${TMP_DIR}/payload"
DIST_DIR="${TMP_DIR}/dist"
LOG_FILE="${TMP_DIR}/makensis.log"

mkdir -p "${STAGE_DIR}/app" "${STAGE_DIR}/data/config" "${DIST_DIR}"
printf 'launcher-binary\n' > "${STAGE_DIR}/OpenClaw Launcher.exe"
printf '{ "version": "0.1.0" }\n' > "${STAGE_DIR}/manifest.json"
printf 'app payload\n' > "${STAGE_DIR}/app/demo.txt"
printf 'config payload\n' > "${STAGE_DIR}/data/config/demo.txt"

if makensis \
  -DPRODUCT_VERSION=0.1.0 \
  -DSTAGE_DIR="${STAGE_DIR}" \
  -DOUTPUT_FILE="${DIST_DIR}/OpenClaw-Setup.exe" \
  "${NSIS_SCRIPT}" >"${LOG_FILE}" 2>&1; then
  :
else
  cat "${LOG_FILE}" >&2
  exit 1
fi

if [[ ! -f "${DIST_DIR}/OpenClaw-Setup.exe" ]]; then
  echo "expected NSIS output missing: ${DIST_DIR}/OpenClaw-Setup.exe" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

echo "Linux NSIS compile smoke check passed."
