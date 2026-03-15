#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_TRIPLE="x86_64-pc-windows-msvc"
BUILD_DIR="${ROOT_DIR}/.build/windows-x64"
STAGE_DIR="${BUILD_DIR}/payload"
DIST_DIR="${BUILD_DIR}/dist"
LAUNCHER_NAME="OpenClaw Launcher.exe"
DRY_RUN="${DRY_RUN:-0}"
OPENCLAW_RUNTIME_SOURCE="translated"
OPENCLAW_RUNTIME_PACKAGE="@qingchencloud/openclaw-zh"
OPENCLAW_RUNTIME_DISPLAY_NAME="OpenClawChineseTranslation"
OPENCLAW_RUNTIME_REPO_OWNER="1186258278"
OPENCLAW_RUNTIME_REPO_NAME="OpenClawChineseTranslation"
OPENCLAW_RUNTIME_VERSION=""
OPENCLAW_RUNTIME_RELEASE_TAG=""
OPENCLAW_RUNTIME_RELEASE_URL=""
GENERATED_MANIFEST_PATH="${BUILD_DIR}/manifest.generated.json"
INSTALLER_REPOSITORY_URL="https://github.com/kitlabs-app/openclaw-installer"

LAUNCHER_SRC="${ROOT_DIR}/target/${TARGET_TRIPLE}/release/launcher-app.exe"
APP_PAYLOAD_DIR="${ROOT_DIR}/packaging/windows/payload/app"
DATA_PAYLOAD_DIR="${ROOT_DIR}/packaging/windows/payload/data"
NSIS_SCRIPT="${ROOT_DIR}/packaging/windows/openclaw-installer.nsi"
PAYLOAD_PRUNE_SCRIPT="${ROOT_DIR}/scripts/prune-windows-payload.sh"

usage() {
  cat <<'EOF'
Usage: scripts/build-win-x64-git-bash.sh [--runtime-source translated|upstream]

This script packages the already-staged payload under packaging/windows/payload.
EOF
}

run() {
  echo "+ $*"
  if [[ "${DRY_RUN}" != "1" ]]; then
    "$@"
  fi
}

normalize_runtime_source() {
  local raw="$1"
  case "${raw}" in
    translated|zh|chinese)
      printf 'translated\n'
      ;;
    upstream|native|official)
      printf 'upstream\n'
      ;;
    *)
      echo "unsupported runtime source: ${raw}" >&2
      exit 1
      ;;
  esac
}

configure_runtime_source() {
  case "${OPENCLAW_RUNTIME_SOURCE}" in
    translated)
      OPENCLAW_RUNTIME_PACKAGE="@qingchencloud/openclaw-zh"
      OPENCLAW_RUNTIME_DISPLAY_NAME="OpenClawChineseTranslation"
      OPENCLAW_RUNTIME_REPO_OWNER="1186258278"
      OPENCLAW_RUNTIME_REPO_NAME="OpenClawChineseTranslation"
      ;;
    upstream)
      OPENCLAW_RUNTIME_PACKAGE="openclaw"
      OPENCLAW_RUNTIME_DISPLAY_NAME="OpenClaw"
      OPENCLAW_RUNTIME_REPO_OWNER="openclaw"
      OPENCLAW_RUNTIME_REPO_NAME="openclaw"
      ;;
    *)
      echo "runtime source not configured: ${OPENCLAW_RUNTIME_SOURCE}" >&2
      exit 1
      ;;
  esac
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --runtime-source)
        if [[ $# -lt 2 ]]; then
          echo "--runtime-source requires a value" >&2
          exit 1
        fi
        OPENCLAW_RUNTIME_SOURCE="$(normalize_runtime_source "$2")"
        shift 2
        ;;
      --runtime-source=*)
        OPENCLAW_RUNTIME_SOURCE="$(normalize_runtime_source "${1#*=}")"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
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

resolve_payload_runtime_metadata() {
  local package_json="${APP_PAYLOAD_DIR}/openclaw/package.json"

  if [[ ! -f "${package_json}" ]]; then
    echo "missing payload package metadata: ${package_json}" >&2
    exit 1
  fi

  mapfile -t payload_meta < <(python3 - "${package_json}" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    data = json.load(handle)

print(str(data.get("name", "")).strip())
print(str(data.get("version", "")).strip())
PY
)

  local payload_name="${payload_meta[0]}"
  local payload_version="${payload_meta[1]}"

  if [[ -z "${payload_name}" || -z "${payload_version}" ]]; then
    echo "payload package metadata is incomplete: ${package_json}" >&2
    exit 1
  fi

  if [[ "${payload_name}" != "${OPENCLAW_RUNTIME_PACKAGE}" ]]; then
    echo "staged payload package ${payload_name} does not match selected runtime source ${OPENCLAW_RUNTIME_SOURCE} (${OPENCLAW_RUNTIME_PACKAGE})" >&2
    exit 1
  fi

  OPENCLAW_RUNTIME_VERSION="${payload_version}"
  OPENCLAW_RUNTIME_RELEASE_TAG="v${payload_version}"
  OPENCLAW_RUNTIME_RELEASE_URL="https://github.com/${OPENCLAW_RUNTIME_REPO_OWNER}/${OPENCLAW_RUNTIME_REPO_NAME}/releases/tag/${OPENCLAW_RUNTIME_RELEASE_TAG}"
}

generate_manifest() {
  python3 - \
    "${ROOT_DIR}/manifest.json" \
    "${GENERATED_MANIFEST_PATH}" \
    "${OPENCLAW_RUNTIME_SOURCE}" \
    "${OPENCLAW_RUNTIME_PACKAGE}" \
    "${OPENCLAW_RUNTIME_VERSION}" \
    "${OPENCLAW_RUNTIME_RELEASE_TAG}" \
    "${OPENCLAW_RUNTIME_RELEASE_URL}" \
    "${OPENCLAW_RUNTIME_DISPLAY_NAME}" <<'PY'
import json
import sys

(
    template_path,
    output_path,
    runtime_source,
    runtime_package,
    runtime_version,
    runtime_release_tag,
    runtime_release_url,
    runtime_display_name,
) = sys.argv[1:9]

with open(template_path, 'r', encoding='utf-8') as handle:
    data = json.load(handle)

installer_version = str(data.get("installer_version") or data.get("version") or "0.1.0")
node_version = str(data.get("node_version") or "")
entries = data.get("entries") or []

result = dict(data)
result["version"] = installer_version
result["installer_version"] = installer_version
result["node_version"] = node_version
result["runtime_source"] = runtime_source
result["runtime_package"] = runtime_package
result["runtime_version"] = runtime_version
result["runtime_release_tag"] = runtime_release_tag
result["runtime_release_url"] = runtime_release_url
display_version = f"{runtime_display_name} v{runtime_version}".strip() if runtime_version else runtime_display_name
result["runtime_display_name"] = runtime_display_name
result["runtime_display_version"] = display_version
result["entries"] = entries

with open(output_path, 'w', encoding='utf-8') as handle:
    json.dump(result, handle, indent=2)
    handle.write("\n")
PY
}

prune_payload() {
  if [[ ! -x "${PAYLOAD_PRUNE_SCRIPT}" ]]; then
    echo "missing executable payload pruner: ${PAYLOAD_PRUNE_SCRIPT}" >&2
    exit 1
  fi

  run bash "${PAYLOAD_PRUNE_SCRIPT}" "${ROOT_DIR}/packaging/windows/payload"
}

main() {
  parse_args "$@"
  ensure_git_bash
  configure_runtime_source

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

  prune_payload

  echo "[2/4] stage payload"
  resolve_payload_runtime_metadata
  generate_manifest
  run cp "${LAUNCHER_SRC}" "${STAGE_DIR}/${LAUNCHER_NAME}"
  run cp "${GENERATED_MANIFEST_PATH}" "${STAGE_DIR}/manifest.json"
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
    -DPRODUCT_RUNTIME_VERSION="${OPENCLAW_RUNTIME_VERSION}" \
    -DPRODUCT_RUNTIME_DISPLAY_VERSION="${OPENCLAW_RUNTIME_DISPLAY_NAME} v${OPENCLAW_RUNTIME_VERSION}" \
    -DINSTALLER_REPOSITORY_URL="${INSTALLER_REPOSITORY_URL}" \
    -DSTAGE_DIR="${stage_dir_win}" \
    -X"OutFile ${dist_dir_win}/OpenClaw-Setup.exe" \
    "${nsis_script_win}"

  echo "[4/4] done"
  echo "installer: ${DIST_DIR}/OpenClaw-Setup.exe"
}

main "$@"
