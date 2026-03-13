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

require_file "${PAYLOAD_ROOT}/app/node/node.exe"
require_file "${PAYLOAD_ROOT}/app/openclaw/openclaw.mjs"
require_file "${PAYLOAD_ROOT}/app/openclaw/package.json"
require_file "${PAYLOAD_ROOT}/app/openclaw/dist/index.js"
require_file "${PAYLOAD_ROOT}/data/config/npmrc"
require_file "${ROOT_DIR}/manifest.json"
require_dir "${PAYLOAD_ROOT}/app/openclaw/assets"
require_dir "${PAYLOAD_ROOT}/app/openclaw/extensions"
require_dir "${PAYLOAD_ROOT}/app/openclaw/skills"

if ! grep -Fq 'registry=https://registry.npmmirror.com/' "${PAYLOAD_ROOT}/data/config/npmrc"; then
  echo "npmrc missing npmmirror registry: ${PAYLOAD_ROOT}/data/config/npmrc" >&2
  exit 1
fi

echo "Payload verification passed for ${PAYLOAD_ROOT}."
