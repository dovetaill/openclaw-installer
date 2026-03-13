#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_TRIPLE="x86_64-pc-windows-msvc"
BUILD_DIR="${ROOT_DIR}/.build/windows-x64"
STAGE_DIR="${BUILD_DIR}/payload"
DIST_DIR="${BUILD_DIR}/dist"
LAUNCHER_NAME="OpenClaw Launcher.exe"

LAUNCHER_SRC="${ROOT_DIR}/target/${TARGET_TRIPLE}/release/launcher-app.exe"
APP_PAYLOAD_DIR="${ROOT_DIR}/packaging/windows/payload/app"
DATA_PAYLOAD_DIR="${ROOT_DIR}/packaging/windows/payload/data"

mkdir -p "${STAGE_DIR}/app" "${STAGE_DIR}/data" "${DIST_DIR}"
rm -rf "${STAGE_DIR}/app" "${STAGE_DIR}/data"
mkdir -p "${STAGE_DIR}/app" "${STAGE_DIR}/data"

echo "[1/4] build launcher"
cargo xwin build --release --target "${TARGET_TRIPLE}" -p launcher-app

if [[ ! -f "${LAUNCHER_SRC}" ]]; then
  echo "missing launcher build output: ${LAUNCHER_SRC}" >&2
  exit 1
fi

if [[ ! -d "${APP_PAYLOAD_DIR}" ]]; then
  echo "missing app payload directory: ${APP_PAYLOAD_DIR}" >&2
  exit 1
fi

if [[ ! -d "${DATA_PAYLOAD_DIR}" ]]; then
  echo "missing data payload directory: ${DATA_PAYLOAD_DIR}" >&2
  exit 1
fi

echo "[2/4] stage payload"
cp "${LAUNCHER_SRC}" "${STAGE_DIR}/${LAUNCHER_NAME}"
cp "${ROOT_DIR}/manifest.json" "${STAGE_DIR}/manifest.json"
cp -R "${APP_PAYLOAD_DIR}/." "${STAGE_DIR}/app/"
cp -R "${DATA_PAYLOAD_DIR}/." "${STAGE_DIR}/data/"

echo "[3/4] package with NSIS"
makensis \
  -DPRODUCT_VERSION=0.1.0 \
  -DSTAGE_DIR="${STAGE_DIR}" \
  -X"OutFile ${DIST_DIR}/OpenClaw-Setup.exe" \
  "${ROOT_DIR}/packaging/windows/openclaw-installer.nsi"

echo "[4/4] done"
echo "installer: ${DIST_DIR}/OpenClaw-Setup.exe"
