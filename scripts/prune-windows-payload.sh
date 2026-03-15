#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD_ROOT="${1:-${ROOT_DIR}/packaging/windows/payload}"

count_files() {
  local root="$1"
  if [[ ! -d "${root}" ]]; then
    printf '0\n'
    return 0
  fi

  find "${root}" -type f | wc -l | tr -d ' '
}

prune_file_patterns() {
  local root="$1"
  if [[ ! -d "${root}" ]]; then
    return 0
  fi

  find "${root}" -type f \
    \( \
      -name '*.d.ts' -o \
      -name '*.map' -o \
      -iname '*.md' -o \
      -iname '*.markdown' \
    \) \
    -delete
}

prune_named_directories() {
  local root="$1"
  if [[ ! -d "${root}" ]]; then
    return 0
  fi

  find "${root}" -depth -type d \
    \( \
      -name test -o \
      -name tests -o \
      -name __tests__ -o \
      -name man -o \
      -name example -o \
      -name examples -o \
      -name tap-snapshots -o \
      -name .github \
    \) \
    -exec rm -rf {} +
}

prune_embedded_npm_extras() {
  local npm_root="$1"
  if [[ ! -d "${npm_root}" ]]; then
    return 0
  fi

  rm -rf \
    "${npm_root}/docs" \
    "${npm_root}/man" \
    "${npm_root}/tap-snapshots"
}

prune_root() {
  local label="$1"
  local root="$2"
  local before
  local after

  if [[ ! -d "${root}" ]]; then
    echo "SKIP: ${label} missing at ${root}"
    return 0
  fi

  before="$(count_files "${root}")"
  prune_file_patterns "${root}"
  prune_named_directories "${root}"
  after="$(count_files "${root}")"
  echo "pruned ${label}: ${before} -> ${after} files"
}

prune_root "openclaw node_modules" "${PAYLOAD_ROOT}/app/openclaw/node_modules"
prune_root "embedded node node_modules" "${PAYLOAD_ROOT}/app/node/node_modules"
prune_embedded_npm_extras "${PAYLOAD_ROOT}/app/node/node_modules/npm"
