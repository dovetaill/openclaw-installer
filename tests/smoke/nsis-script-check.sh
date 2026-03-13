#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="packaging/windows/openclaw-installer.nsi"
SCRIPT_GLOB="packaging/windows/openclaw-installer.nsi packaging/windows/include/*.nsh"

if [[ ! -f "${SCRIPT_PATH}" ]]; then
  echo "missing NSIS script: ${SCRIPT_PATH}" >&2
  exit 1
fi

assert_contains() {
  local pattern="$1"
  if ! grep -Eq "${pattern}" ${SCRIPT_GLOB}; then
    echo "expected pattern not found: ${pattern}" >&2
    exit 1
  fi
}

assert_not_contains() {
  local pattern="$1"
  if grep -Eq "${pattern}" ${SCRIPT_GLOB}; then
    echo "forbidden pattern found: ${pattern}" >&2
    exit 1
  fi
}

assert_contains 'WriteReg(Str|ExpandStr)[[:space:]]+HKCU[[:space:]]+"(\$\{PRODUCT_UNINSTALL_KEY\}|Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\OpenClaw)"'
assert_contains 'CreateShortCut[[:space:]]+"(\$\{DESKTOP_SHORTCUT\}|\$DESKTOP\\OpenClaw Launcher\.lnk)"'
assert_contains 'CreateShortCut[[:space:]]+"(\$\{START_MENU_SHORTCUT\}|\$SMPROGRAMS\\OpenClaw\\OpenClaw Launcher\.lnk)"'

assert_not_contains 'WriteReg(Expand)?Str[[:space:]]+HK(LM|CU)[[:space:]]+".*Environment.*PATH"'
assert_not_contains 'EnVar::'
assert_not_contains 'sc(\.exe)?[[:space:]]+(create|start)'
assert_not_contains 'SimpleSC::'
assert_not_contains 'schtasks(\.exe)?'

echo "NSIS script smoke checks passed."
