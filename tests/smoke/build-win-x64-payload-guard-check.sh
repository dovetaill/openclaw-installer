#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SCRIPT="${ROOT_DIR}/scripts/build-win-x64.sh"
VERIFY_SCRIPT="${ROOT_DIR}/scripts/verify-payload.sh"

if [[ ! -f "${SOURCE_SCRIPT}" ]]; then
  echo "missing source script: ${SOURCE_SCRIPT}" >&2
  exit 1
fi

if [[ ! -f "${VERIFY_SCRIPT}" ]]; then
  echo "missing payload verifier: ${VERIFY_SCRIPT}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

MOCK_ROOT="${TMP_DIR}/workspace"
MOCK_BIN="${TMP_DIR}/bin"
FIXTURE_DIR="${TMP_DIR}/fixtures"
LOG_FILE="${TMP_DIR}/build.log"
OPENCLAW_REGISTRY_URL="https://mirror.example/npm"
OPENCLAW_PACKAGE="@qingchencloud/openclaw-zh"
OPENCLAW_META_URL="${OPENCLAW_REGISTRY_URL}/${OPENCLAW_PACKAGE}"
OPENCLAW_TARBALL_URL="https://mirror.example/tarballs/openclaw-zh-2026.3.12-zh.2.tgz"
OPENCLAW_RELEASE_URL="https://api.github.com/repos/1186258278/OpenClawChineseTranslation/releases/latest"
NODE_INDEX_URL="https://mirror.example/node/index.json"
NODE_DIST_BASE_URL="https://mirror.example/node/dist"
NODE_ZIP_URL="${NODE_DIST_BASE_URL}/v24.14.0/node-v24.14.0-win-x64.zip"

mkdir -p \
  "${MOCK_ROOT}/scripts" \
  "${MOCK_ROOT}/packaging/windows" \
  "${MOCK_ROOT}/target/x86_64-pc-windows-msvc/release" \
  "${MOCK_BIN}" \
  "${FIXTURE_DIR}"

cp "${SOURCE_SCRIPT}" "${MOCK_ROOT}/scripts/build-win-x64.sh"
cp "${VERIFY_SCRIPT}" "${MOCK_ROOT}/scripts/verify-payload.sh"
chmod +x "${MOCK_ROOT}/scripts/build-win-x64.sh" "${MOCK_ROOT}/scripts/verify-payload.sh"

printf '{ "version": "0.1.0" }\n' > "${MOCK_ROOT}/manifest.json"
printf 'launcher-binary\n' > "${MOCK_ROOT}/target/x86_64-pc-windows-msvc/release/launcher-app.exe"
printf 'nsis\n' > "${MOCK_ROOT}/packaging/windows/openclaw-installer.nsi"

mkdir -p "${FIXTURE_DIR}/openclaw/package/dist" "${FIXTURE_DIR}/openclaw/package/assets" "${FIXTURE_DIR}/openclaw/package/extensions" "${FIXTURE_DIR}/openclaw/package/skills/demo"
printf '{"name":"@qingchencloud/openclaw-zh","version":"2026.3.12-zh.2","engines":{"node":">=22.16.0"},"dependencies":{"chalk":"^5.6.2"}}\n' > "${FIXTURE_DIR}/openclaw/package/package.json"
printf 'export const entry = true;\n' > "${FIXTURE_DIR}/openclaw/package/dist/entry.js"
printf 'export const boot = true;\n' > "${FIXTURE_DIR}/openclaw/package/dist/index.js"
printf 'asset\n' > "${FIXTURE_DIR}/openclaw/package/assets/icon.txt"
printf 'extension\n' > "${FIXTURE_DIR}/openclaw/package/extensions/example.txt"
printf '# demo skill\n' > "${FIXTURE_DIR}/openclaw/package/skills/demo/SKILL.md"
tar -czf "${FIXTURE_DIR}/openclaw.tgz" -C "${FIXTURE_DIR}/openclaw" package

mkdir -p "${FIXTURE_DIR}/node/node-v24.14.0-win-x64"
printf 'node-binary\n' > "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/node.exe"
printf 'npm shim\n' > "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/npm.cmd"
printf 'npx shim\n' > "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/npx.cmd"
(cd "${FIXTURE_DIR}/node" && zip -qr "${FIXTURE_DIR}/node.zip" node-v24.14.0-win-x64)

cat > "${FIXTURE_DIR}/openclaw-npm.json" <<EOF
{
  "dist-tags": {
    "latest": "2026.3.12-zh.2"
  },
  "versions": {
    "2026.3.12-zh.2": {
      "dist": {
        "tarball": "${OPENCLAW_TARBALL_URL}"
      },
      "engines": {
        "node": ">=22.16.0"
      }
    }
  }
}
EOF

cat > "${FIXTURE_DIR}/openclaw-release.json" <<'EOF'
{
  "tag_name": "v2026.3.12-zh.2",
  "html_url": "https://github.com/1186258278/OpenClawChineseTranslation/releases/tag/v2026.3.12-zh.2"
}
EOF

cat > "${FIXTURE_DIR}/node-index.json" <<'EOF'
[
  {
    "version": "v24.14.0",
    "lts": "Krypton",
    "files": ["win-x64-zip"]
  }
]
EOF

cat > "${MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail

fixture_dir="${FIXTURE_DIR}"
output=""

while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o)
      output="\$2"
      shift 2
      ;;
    *)
      url="\$1"
      shift
      ;;
  esac
done

if [[ -z "\${output}" ]]; then
  echo "mock curl requires -o" >&2
  exit 1
fi

case "\${url}" in
  "${OPENCLAW_META_URL}") src="\${fixture_dir}/openclaw-npm.json" ;;
  "${OPENCLAW_TARBALL_URL}") src="\${fixture_dir}/openclaw.tgz" ;;
  "${OPENCLAW_RELEASE_URL}") src="\${fixture_dir}/openclaw-release.json" ;;
  "${NODE_INDEX_URL}") src="\${fixture_dir}/node-index.json" ;;
  "${NODE_ZIP_URL}") src="\${fixture_dir}/node.zip" ;;
  *)
    echo "unexpected curl url: \${url}" >&2
    exit 1
    ;;
esac

cp "\${src}" "\${output}"
EOF
chmod +x "${MOCK_BIN}/curl"

cat > "${MOCK_BIN}/cargo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "xwin" && "${2:-}" == "--version" ]]; then
  echo "cargo-xwin 0.0.0"
  exit 0
fi
if [[ "${1:-}" == "xwin" && "${2:-}" == "build" ]]; then
  exit 0
fi
echo "unexpected cargo invocation: $*" >&2
exit 1
EOF
chmod +x "${MOCK_BIN}/cargo"

cat > "${MOCK_BIN}/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

prefix=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      prefix="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "${prefix}" ]]; then
  echo "mock npm requires --prefix" >&2
  exit 1
fi

mkdir -p "${prefix}/node_modules/chalk"
printf '{"name":"chalk","version":"5.6.2"}\n' > "${prefix}/node_modules/chalk/package.json"
exit 0
EOF
chmod +x "${MOCK_BIN}/npm"

cat > "${MOCK_BIN}/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "apt-get should not run when payload validation fails first" >&2
exit 1
EOF
chmod +x "${MOCK_BIN}/apt-get"

cat > "${MOCK_BIN}/makensis" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "makensis should not run when payload validation fails first" >&2
exit 1
EOF
chmod +x "${MOCK_BIN}/makensis"

set +e
PATH="${MOCK_BIN}:${PATH}" \
  OPENCLAW_NPM_REGISTRY="${OPENCLAW_REGISTRY_URL}" \
  NODE_INDEX_URL="${NODE_INDEX_URL}" \
  NODE_DIST_BASE_URL="${NODE_DIST_BASE_URL}" \
  bash "${MOCK_ROOT}/scripts/build-win-x64.sh" >"${LOG_FILE}" 2>&1
status=$?
set -e

if [[ "${status}" -eq 0 ]]; then
  echo "expected build script to fail when app payload is incomplete" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

grep -Fq 'downloaded payload missing required path:' "${LOG_FILE}" || {
  echo "expected downloaded payload validation error before NSIS packaging" >&2
  cat "${LOG_FILE}" >&2
  exit 1
}

grep -Fq '/package/openclaw.mjs' "${LOG_FILE}" || {
  echo "expected missing OpenClaw entrypoint path in download validation error" >&2
  cat "${LOG_FILE}" >&2
  exit 1
}

echo "Linux payload guard smoke check passed."
