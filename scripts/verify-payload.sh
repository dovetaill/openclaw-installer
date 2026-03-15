#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD_ROOT="${1:-${ROOT_DIR}/packaging/windows/payload}"

if [[ ! -d "${PAYLOAD_ROOT}" ]]; then
  echo "SKIP: payload root not staged at ${PAYLOAD_ROOT}" >&2
  echo "SKIP: stage app/node/node.exe, app/openclaw/openclaw.mjs and data/config/npmrc before packaging" >&2
  exit 0
fi

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "missing payload file: ${path}" >&2
    exit 1
  fi
}

require_dir() {
  local path="$1"
  if [[ ! -d "${path}" ]]; then
    echo "missing payload directory: ${path}" >&2
    exit 1
  fi
}

require_one_of() {
  local label="$1"
  shift

  for candidate in "$@"; do
    if [[ -f "${candidate}" ]]; then
      return 0
    fi
  done

  echo "missing payload file set (${label}): $*" >&2
  exit 1
}

verify_openclaw_bootstrap() {
  if ! command -v node >/dev/null 2>&1; then
    echo "SKIP: host node not found; skipping embedded OpenClaw bootstrap smoke check" >&2
    return 0
  fi

  local log_file
  log_file="$(mktemp)"

  if node "${PAYLOAD_ROOT}/app/openclaw/openclaw.mjs" --help >"${log_file}" 2>&1; then
    rm -f "${log_file}"
    return 0
  fi

  cat "${log_file}" >&2
  rm -f "${log_file}"
  echo "embedded OpenClaw bootstrap smoke check failed: ${PAYLOAD_ROOT}/app/openclaw/openclaw.mjs --help" >&2
  exit 1
}

require_file "${PAYLOAD_ROOT}/app/node/node.exe"
require_file "${PAYLOAD_ROOT}/app/openclaw/openclaw.mjs"
require_file "${PAYLOAD_ROOT}/app/openclaw/package.json"
require_file "${PAYLOAD_ROOT}/app/openclaw/dist/index.js"
require_dir "${PAYLOAD_ROOT}/app/openclaw/docs"
require_file "${PAYLOAD_ROOT}/app/openclaw/docs/start/getting-started.md"
require_file "${PAYLOAD_ROOT}/app/openclaw/docs/reference/templates/AGENTS.md"
require_one_of "openclaw entry" \
  "${PAYLOAD_ROOT}/app/openclaw/dist/entry.js" \
  "${PAYLOAD_ROOT}/app/openclaw/dist/entry.mjs"
require_file "${PAYLOAD_ROOT}/data/config/npmrc"
require_file "${ROOT_DIR}/manifest.json"
require_dir "${PAYLOAD_ROOT}/app/openclaw/assets"
require_dir "${PAYLOAD_ROOT}/app/openclaw/extensions"
require_dir "${PAYLOAD_ROOT}/app/openclaw/skills"
require_dir "${PAYLOAD_ROOT}/app/openclaw/node_modules"

if ! grep -Fq 'registry=https://registry.npmmirror.com/' "${PAYLOAD_ROOT}/data/config/npmrc"; then
  echo "npmrc missing npmmirror registry: ${PAYLOAD_ROOT}/data/config/npmrc" >&2
  exit 1
fi

verify_openclaw_bootstrap

echo "Payload verification passed for ${PAYLOAD_ROOT}."
