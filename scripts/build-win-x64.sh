#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_TRIPLE="x86_64-pc-windows-msvc"
BUILD_DIR="${ROOT_DIR}/.build/windows-x64"
STAGE_DIR="${BUILD_DIR}/payload"
DIST_DIR="${BUILD_DIR}/dist"
DOWNLOAD_DIR="${BUILD_DIR}/downloads"
WORK_DIR="${BUILD_DIR}/work"
XWIN_CACHE_DIR="${BUILD_DIR}/xwin-cache"
NPM_CACHE_DIR="${BUILD_DIR}/npm-cache"
LAUNCHER_NAME="OpenClaw Launcher.exe"
DRY_RUN="${DRY_RUN:-0}"
DEFAULT_NPMRC_CONTENTS="registry=https://registry.npmmirror.com/"
OPENCLAW_NPM_REGISTRY="${OPENCLAW_NPM_REGISTRY:-https://registry.npmmirror.com}"
GITHUB_API_BASE_URL="${GITHUB_API_BASE_URL:-https://api.github.com}"
NODE_INDEX_URL="${NODE_INDEX_URL:-https://nodejs.org/dist/index.json}"
NODE_DIST_BASE_URL="${NODE_DIST_BASE_URL:-https://nodejs.org/dist}"
OPENCLAW_TARGET_OS="${OPENCLAW_TARGET_OS:-win32}"
OPENCLAW_TARGET_CPU="${OPENCLAW_TARGET_CPU:-x64}"
OPENCLAW_NODE_ENGINE=""
OPENCLAW_RUNTIME_SOURCE="translated"
OPENCLAW_RUNTIME_PACKAGE="@qingchencloud/openclaw-zh"
OPENCLAW_RUNTIME_DISPLAY_NAME="OpenClawChineseTranslation"
OPENCLAW_RUNTIME_REPO_OWNER="1186258278"
OPENCLAW_RUNTIME_REPO_NAME="OpenClawChineseTranslation"
OPENCLAW_RUNTIME_VERSION=""
OPENCLAW_RUNTIME_RELEASE_TAG=""
OPENCLAW_RUNTIME_RELEASE_URL=""
GENERATED_MANIFEST_PATH="${BUILD_DIR}/manifest.generated.json"

LAUNCHER_SRC="${ROOT_DIR}/target/${TARGET_TRIPLE}/release/launcher-app.exe"
APP_PAYLOAD_DIR="${ROOT_DIR}/packaging/windows/payload/app"
APP_NODE_DIR="${APP_PAYLOAD_DIR}/node"
APP_OPENCLAW_DIR="${APP_PAYLOAD_DIR}/openclaw"
DATA_PAYLOAD_DIR="${ROOT_DIR}/packaging/windows/payload/data"
DATA_CONFIG_DIR="${DATA_PAYLOAD_DIR}/config"
NPMRC_PATH="${DATA_CONFIG_DIR}/npmrc"
PAYLOAD_VERIFY_SCRIPT="${ROOT_DIR}/scripts/verify-payload.sh"

usage() {
  cat <<'EOF'
Usage: scripts/build-win-x64.sh [--runtime-source translated|upstream]

Defaults:
  --runtime-source translated
EOF
}

run() {
  echo "+ $*"
  if [[ "${DRY_RUN}" != "1" ]]; then
    "$@"
  fi
}

download_file() {
  local url="$1"
  local output="$2"
  run mkdir -p "$(dirname "${output}")"
  run curl --retry 3 --retry-delay 1 -fsSL "${url}" -o "${output}"
}

require_downloaded_path() {
  local path="$1"
  if [[ ! -e "${path}" ]]; then
    echo "downloaded payload missing required path: ${path}" >&2
    exit 1
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

resolve_openclaw_npm_release() {
  local metadata_path="$1"
  python3 - "$metadata_path" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    data = json.load(handle)

latest = data["dist-tags"]["latest"]
version = data["versions"][latest]
tarball = version["dist"]["tarball"]
node_engine = version.get("engines", {}).get("node", "")

print(latest)
print(tarball)
print(node_engine)
PY
}

resolve_github_latest_release() {
  local metadata_path="$1"
  python3 - "$metadata_path" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    data = json.load(handle)

tag_name = str(data.get("tag_name", "")).strip()
html_url = str(data.get("html_url", "")).strip()

if not tag_name:
    raise SystemExit("latest release response missing tag_name")

if not html_url:
    raise SystemExit("latest release response missing html_url")

normalized = tag_name[1:] if tag_name.startswith("v") else tag_name

print(tag_name)
print(html_url)
print(normalized)
PY
}

resolve_node_zip() {
  local index_path="$1"
  local engine_constraint="$2"
  local base_url="$3"
  python3 - "$index_path" "$engine_constraint" "$base_url" <<'PY'
import json
import re
import sys

index_path, engine_constraint, base_url = sys.argv[1:4]

with open(index_path, 'r', encoding='utf-8') as handle:
    releases = json.load(handle)

constraint = engine_constraint.strip() or ">=0.0.0"
comparators = []

for token in constraint.split():
    match = re.fullmatch(r'(>=|<=|>|<|=)?v?(\d+)\.(\d+)\.(\d+)', token)
    if not match:
        continue
    op = match.group(1) or "="
    version = tuple(int(match.group(index)) for index in range(2, 5))
    comparators.append((op, version))

if not comparators:
    raise SystemExit(f"unsupported Node engine constraint: {constraint}")

def compare(left, right):
    if left < right:
        return -1
    if left > right:
        return 1
    return 0

def satisfies(version):
    for op, reference in comparators:
        result = compare(version, reference)
        if op == ">=" and result < 0:
            return False
        if op == ">" and result <= 0:
            return False
        if op == "<=" and result > 0:
            return False
        if op == "<" and result >= 0:
            return False
        if op == "=" and result != 0:
            return False
    return True

for item in releases:
    if not item.get("lts"):
        continue
    if "win-x64-zip" not in item.get("files", []):
        continue
    version_text = item["version"]
    version_tuple = tuple(int(part) for part in version_text.lstrip("v").split("."))
    if not satisfies(version_tuple):
        continue
    print(version_text)
    print(f"{base_url.rstrip('/')}/{version_text}/node-{version_text}-win-x64.zip")
    raise SystemExit(0)

raise SystemExit(f"no Windows x64 LTS Node release satisfies {constraint}")
PY
}

prepare_openclaw_payload() {
  local metadata_path="${DOWNLOAD_DIR}/openclaw-npm.json"
  local release_path="${DOWNLOAD_DIR}/openclaw-release.json"
  local openclaw_tarball="${DOWNLOAD_DIR}/openclaw.tgz"
  local extract_root="${WORK_DIR}/openclaw"
  local install_root="${WORK_DIR}/openclaw-install"
  local package_root="${extract_root}/package"
  local dependencies_root="${install_root}/node_modules"
  local tarball_url
  local version
  local release_api_url="${GITHUB_API_BASE_URL%/}/repos/${OPENCLAW_RUNTIME_REPO_OWNER}/${OPENCLAW_RUNTIME_REPO_NAME}/releases/latest"

  download_file "${OPENCLAW_NPM_REGISTRY%/}/${OPENCLAW_RUNTIME_PACKAGE}" "${metadata_path}"
  mapfile -t openclaw_meta < <(resolve_openclaw_npm_release "${metadata_path}")
  version="${openclaw_meta[0]}"
  tarball_url="${openclaw_meta[1]}"
  OPENCLAW_NODE_ENGINE="${openclaw_meta[2]}"
  OPENCLAW_RUNTIME_VERSION="${version}"

  download_file "${release_api_url}" "${release_path}"
  mapfile -t release_meta < <(resolve_github_latest_release "${release_path}")
  OPENCLAW_RUNTIME_RELEASE_TAG="${release_meta[0]}"
  OPENCLAW_RUNTIME_RELEASE_URL="${release_meta[1]}"

  if [[ "${OPENCLAW_RUNTIME_VERSION}" != "${release_meta[2]}" ]]; then
    echo "GitHub latest release ${OPENCLAW_RUNTIME_RELEASE_TAG} does not match npm latest ${OPENCLAW_RUNTIME_VERSION} for ${OPENCLAW_RUNTIME_PACKAGE}" >&2
    exit 1
  fi

  echo "syncing ${OPENCLAW_RUNTIME_DISPLAY_NAME} npm package ${version}"
  download_file "${tarball_url}" "${openclaw_tarball}"

  run rm -rf "${extract_root}" "${APP_OPENCLAW_DIR}"
  run mkdir -p "${extract_root}" "${APP_OPENCLAW_DIR}"
  run tar -xzf "${openclaw_tarball}" -C "${extract_root}"

  if [[ ! -d "${package_root}" ]]; then
    echo "downloaded OpenClaw package is missing package/ root" >&2
    exit 1
  fi

  require_downloaded_path "${package_root}/openclaw.mjs"
  require_downloaded_path "${package_root}/package.json"
  require_downloaded_path "${package_root}/dist"
  require_downloaded_path "${package_root}/assets"
  require_downloaded_path "${package_root}/extensions"
  require_downloaded_path "${package_root}/skills"

  hydrate_openclaw_dependencies "${openclaw_tarball}" "${install_root}"

  run cp "${package_root}/openclaw.mjs" "${APP_OPENCLAW_DIR}/openclaw.mjs"
  run cp "${package_root}/package.json" "${APP_OPENCLAW_DIR}/package.json"
  run cp -R "${package_root}/dist" "${APP_OPENCLAW_DIR}/dist"
  run cp -R "${package_root}/assets" "${APP_OPENCLAW_DIR}/assets"
  run cp -R "${package_root}/extensions" "${APP_OPENCLAW_DIR}/extensions"
  run cp -R "${package_root}/skills" "${APP_OPENCLAW_DIR}/skills"

  if [[ -d "${dependencies_root}/openclaw" ]]; then
    run rm -rf "${dependencies_root}/openclaw"
  fi

  require_downloaded_path "${dependencies_root}"
  run cp -R "${dependencies_root}" "${APP_OPENCLAW_DIR}/node_modules"
}

prepare_node_payload() {
  local node_engine="$1"
  local node_index_path="${DOWNLOAD_DIR}/node-index.json"
  local node_zip_path="${DOWNLOAD_DIR}/node-win-x64.zip"
  local extract_root="${WORK_DIR}/node"
  local release_dir
  local version
  local zip_url

  download_file "${NODE_INDEX_URL}" "${node_index_path}"
  mapfile -t node_release < <(resolve_node_zip "${node_index_path}" "${node_engine}" "${NODE_DIST_BASE_URL}")
  version="${node_release[0]}"
  zip_url="${node_release[1]}"

  echo "syncing Windows Node ${version} for ${node_engine}"
  download_file "${zip_url}" "${node_zip_path}"

  run rm -rf "${extract_root}" "${APP_NODE_DIR}"
  run mkdir -p "${extract_root}" "${APP_NODE_DIR}"
  run unzip -q "${node_zip_path}" -d "${extract_root}"

  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "+ extract ${version} into ${APP_NODE_DIR}"
    return 0
  fi

  release_dir="$(find "${extract_root}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [[ -z "${release_dir}" ]]; then
    echo "downloaded Node zip did not contain an extracted root directory" >&2
    exit 1
  fi

  require_downloaded_path "${release_dir}/node.exe"

  run cp -R "${release_dir}/." "${APP_NODE_DIR}/"
}

prepare_runtime_payload() {
  echo "[1/5] sync runtime payload"
  configure_runtime_source

  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "+ curl latest ${OPENCLAW_RUNTIME_PACKAGE} npm metadata from ${OPENCLAW_NPM_REGISTRY%/}/${OPENCLAW_RUNTIME_PACKAGE}"
    echo "+ curl latest GitHub release metadata for ${OPENCLAW_RUNTIME_REPO_OWNER}/${OPENCLAW_RUNTIME_REPO_NAME}"
    echo "+ download latest ${OPENCLAW_RUNTIME_PACKAGE} npm tarball"
    echo "+ install ${OPENCLAW_RUNTIME_PACKAGE} production dependencies for ${OPENCLAW_TARGET_OS}/${OPENCLAW_TARGET_CPU}"
    echo "+ download latest matching Windows Node x64 LTS zip from ${NODE_DIST_BASE_URL}"
    echo "+ refresh payload/app/openclaw and payload/app/node"
    return 0
  fi

  prepare_openclaw_payload
  prepare_node_payload "${OPENCLAW_NODE_ENGINE}"
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

ensure_npm() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    return 0
  fi

  if command -v npm >/dev/null 2>&1; then
    return 0
  fi

  echo "npm not found; install a host Node.js + npm runtime to vendor OpenClaw dependencies" >&2
  exit 1
}

hydrate_openclaw_dependencies() {
  local openclaw_tarball="$1"
  local install_root="$2"

  ensure_npm
  run rm -rf "${install_root}"
  run mkdir -p "${install_root}"
  run env \
    NPM_CONFIG_CACHE="${NPM_CACHE_DIR}" \
    NPM_CONFIG_REGISTRY="${OPENCLAW_NPM_REGISTRY}" \
    npm install \
    --omit=dev \
    --no-package-lock \
    --no-audit \
    --no-fund \
    --os="${OPENCLAW_TARGET_OS}" \
    --cpu="${OPENCLAW_TARGET_CPU}" \
    --prefix "${install_root}" \
    "${openclaw_tarball}"
}

ensure_cargo_xwin() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    return 0
  fi

  if cargo xwin --version >/dev/null 2>&1; then
    return 0
  fi

  echo "cargo-xwin not found; installing cargo-xwin for Linux cross-build"
  run cargo install cargo-xwin --locked
}

ensure_data_payload_layout() {
  run mkdir -p "${DATA_CONFIG_DIR}"

  if [[ "${DRY_RUN}" == "1" ]]; then
    echo "+ seed default npmrc at ${NPMRC_PATH} when missing"
    return 0
  fi

  if [[ -f "${NPMRC_PATH}" ]]; then
    return 0
  fi

  echo "payload data config missing; seeding default npmrc at ${NPMRC_PATH}"
  printf '%s\n' "${DEFAULT_NPMRC_CONTENTS}" > "${NPMRC_PATH}"
}

ensure_makensis() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    return 0
  fi

  if command -v makensis >/dev/null 2>&1; then
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "makensis not found and apt-get is unavailable; install NSIS manually" >&2
    exit 1
  fi

  echo "makensis not found; installing nsis for Linux packaging"
  if [[ "${EUID}" -eq 0 ]]; then
    run apt-get update
    run apt-get install -y nsis
  elif command -v sudo >/dev/null 2>&1; then
    run sudo apt-get update
    run sudo apt-get install -y nsis
  else
    echo "makensis not found and sudo is unavailable; install NSIS manually" >&2
    exit 1
  fi

  hash -r

  if ! command -v makensis >/dev/null 2>&1; then
    echo "nsis install completed but makensis is still unavailable" >&2
    exit 1
  fi
}

verify_payload() {
  if [[ ! -x "${PAYLOAD_VERIFY_SCRIPT}" ]]; then
    echo "missing executable payload verifier: ${PAYLOAD_VERIFY_SCRIPT}" >&2
    exit 1
  fi

  run bash "${PAYLOAD_VERIFY_SCRIPT}" "${ROOT_DIR}/packaging/windows/payload"
}

main() {
  parse_args "$@"
  mkdir -p "${STAGE_DIR}/app" "${STAGE_DIR}/data" "${DIST_DIR}" "${DOWNLOAD_DIR}" "${WORK_DIR}" "${XWIN_CACHE_DIR}" "${NPM_CACHE_DIR}"
  if [[ "${DRY_RUN}" != "1" ]]; then
    rm -rf "${STAGE_DIR}/app" "${STAGE_DIR}/data"
    mkdir -p "${STAGE_DIR}/app" "${STAGE_DIR}/data"
  fi

  prepare_runtime_payload

  echo "[2/5] build launcher"
  ensure_cargo_xwin
  run env XWIN_CACHE_DIR="${XWIN_CACHE_DIR}" cargo xwin build --release --target "${TARGET_TRIPLE}" -p launcher-app
  ensure_data_payload_layout
  verify_payload

  if [[ "${DRY_RUN}" != "1" && ! -f "${LAUNCHER_SRC}" ]]; then
    echo "missing launcher build output: ${LAUNCHER_SRC}" >&2
    exit 1
  fi

  if [[ "${DRY_RUN}" != "1" && ! -d "${APP_PAYLOAD_DIR}" ]]; then
    echo "missing app payload directory: ${APP_PAYLOAD_DIR}" >&2
    exit 1
  fi

  echo "[3/5] stage payload"
  generate_manifest
  run cp "${LAUNCHER_SRC}" "${STAGE_DIR}/${LAUNCHER_NAME}"
  run cp "${GENERATED_MANIFEST_PATH}" "${STAGE_DIR}/manifest.json"
  run cp -R "${APP_PAYLOAD_DIR}/." "${STAGE_DIR}/app/"
  run cp -R "${DATA_PAYLOAD_DIR}/." "${STAGE_DIR}/data/"

  echo "[4/5] package with NSIS"
  ensure_makensis
  run makensis \
    -DPRODUCT_VERSION=0.1.0 \
    -DSTAGE_DIR="${STAGE_DIR}" \
    -DOUTPUT_FILE="${DIST_DIR}/OpenClaw-Setup.exe" \
    "${ROOT_DIR}/packaging/windows/openclaw-installer.nsi"

  echo "[5/5] done"
  echo "installer: ${DIST_DIR}/OpenClaw-Setup.exe"
}

main "$@"
