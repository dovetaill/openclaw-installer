#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SCRIPT="${ROOT_DIR}/scripts/build-win-x64.sh"
VERIFY_SCRIPT="${ROOT_DIR}/scripts/verify-payload.sh"
PRUNE_SCRIPT="${ROOT_DIR}/scripts/prune-windows-payload.sh"

if [[ ! -f "${SOURCE_SCRIPT}" ]]; then
  echo "missing source script: ${SOURCE_SCRIPT}" >&2
  exit 1
fi

if [[ ! -f "${VERIFY_SCRIPT}" ]]; then
  echo "missing payload verifier: ${VERIFY_SCRIPT}" >&2
  exit 1
fi

if [[ ! -f "${PRUNE_SCRIPT}" ]]; then
  echo "missing payload pruner: ${PRUNE_SCRIPT}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

MOCK_ROOT="${TMP_DIR}/workspace"
MOCK_BIN="${TMP_DIR}/bin"
FIXTURE_DIR="${TMP_DIR}/fixtures"
LOG_FILE="${TMP_DIR}/build.log"
INSTALL_MARKER="${TMP_DIR}/cargo-xwin-installed"
EXPECTED_XWIN_CACHE_DIR="${MOCK_ROOT}/.build/windows-x64/xwin-cache"
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
cp "${PRUNE_SCRIPT}" "${MOCK_ROOT}/scripts/prune-windows-payload.sh"
chmod +x "${MOCK_ROOT}/scripts/build-win-x64.sh" "${MOCK_ROOT}/scripts/verify-payload.sh" "${MOCK_ROOT}/scripts/prune-windows-payload.sh"

printf '{ "version": "0.1.0" }\n' > "${MOCK_ROOT}/manifest.json"
printf 'launcher-binary\n' > "${MOCK_ROOT}/target/x86_64-pc-windows-msvc/release/launcher-app.exe"
printf 'nsis\n' > "${MOCK_ROOT}/packaging/windows/openclaw-installer.nsi"

mkdir -p \
  "${FIXTURE_DIR}/openclaw/package/dist" \
  "${FIXTURE_DIR}/openclaw/package/assets" \
  "${FIXTURE_DIR}/openclaw/package/docs/start" \
  "${FIXTURE_DIR}/openclaw/package/docs/reference/templates" \
  "${FIXTURE_DIR}/openclaw/package/extensions" \
  "${FIXTURE_DIR}/openclaw/package/skills/demo"
cat > "${FIXTURE_DIR}/openclaw/package/openclaw.mjs" <<'EOF'
#!/usr/bin/env node
if (process.argv.includes('--help')) {
  console.log('openclaw help')
}
EOF
printf '{"name":"@qingchencloud/openclaw-zh","version":"2026.3.12-zh.2","engines":{"node":">=22.16.0"},"dependencies":{"chalk":"^5.6.2"}}\n' > "${FIXTURE_DIR}/openclaw/package/package.json"
printf 'export const entry = true;\n' > "${FIXTURE_DIR}/openclaw/package/dist/entry.js"
printf 'export const boot = true;\n' > "${FIXTURE_DIR}/openclaw/package/dist/index.js"
printf 'asset\n' > "${FIXTURE_DIR}/openclaw/package/assets/icon.txt"
printf '# getting started\n' > "${FIXTURE_DIR}/openclaw/package/docs/start/getting-started.md"
printf '# template\n' > "${FIXTURE_DIR}/openclaw/package/docs/reference/templates/AGENTS.md"
printf 'extension\n' > "${FIXTURE_DIR}/openclaw/package/extensions/example.txt"
printf '# demo skill\n' > "${FIXTURE_DIR}/openclaw/package/skills/demo/SKILL.md"
tar -czf "${FIXTURE_DIR}/openclaw.tgz" -C "${FIXTURE_DIR}/openclaw" package

mkdir -p "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/node_modules/npm/docs"
mkdir -p "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/node_modules/npm/man"
mkdir -p "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/node_modules/npm/tap-snapshots"
printf 'node-binary\n' > "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/node.exe"
printf 'npm shim\n' > "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/npm.cmd"
printf 'npx shim\n' > "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/npx.cmd"
printf 'docs\n' > "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/node_modules/npm/docs/readme.md"
printf 'man\n' > "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/node_modules/npm/man/npm.1"
printf 'snapshot\n' > "${FIXTURE_DIR}/node/node-v24.14.0-win-x64/node_modules/npm/tap-snapshots/test.txt"
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

cat > "${MOCK_BIN}/cargo" <<EOF
#!/usr/bin/env bash
set -euo pipefail

marker="${INSTALL_MARKER}"

if [[ "\${1:-}" == "xwin" && "\${2:-}" == "--version" ]]; then
  if [[ -f "\${marker}" ]]; then
    echo "cargo-xwin 0.0.0"
    exit 0
  fi
  echo "error: no such command: xwin" >&2
  exit 101
fi

if [[ "\${1:-}" == "install" && "\${2:-}" == "cargo-xwin" ]]; then
  touch "\${marker}"
  exit 0
fi

if [[ "\${1:-}" == "xwin" && "\${2:-}" == "build" ]]; then
  if [[ "\${XWIN_CACHE_DIR:-}" != "${EXPECTED_XWIN_CACHE_DIR}" ]]; then
    echo "unexpected XWIN_CACHE_DIR: \${XWIN_CACHE_DIR:-unset}" >&2
    exit 1
  fi
  if [[ -f "\${marker}" ]]; then
    exit 0
  fi
  echo "error: no such command: xwin" >&2
  exit 101
fi

echo "unexpected cargo invocation: \$*" >&2
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

mkdir -p "${prefix}/node_modules/chalk/docs"
mkdir -p "${prefix}/node_modules/chalk/dist/doc"
mkdir -p "${prefix}/node_modules/chalk/tests"
mkdir -p "${prefix}/node_modules/chalk/examples"
mkdir -p "${prefix}/node_modules/chalk/.github"
printf '{"name":"chalk","version":"5.6.2"}\n' > "${prefix}/node_modules/chalk/package.json"
printf 'export {};\n' > "${prefix}/node_modules/chalk/index.d.ts"
printf '{}\n' > "${prefix}/node_modules/chalk/index.js.map"
printf '# readme\n' > "${prefix}/node_modules/chalk/README.md"
printf 'docs\n' > "${prefix}/node_modules/chalk/docs/guide.md"
printf 'runtime\n' > "${prefix}/node_modules/chalk/dist/doc/runtime.js"
printf 'tests\n' > "${prefix}/node_modules/chalk/tests/chalk.test.js"
printf 'example\n' > "${prefix}/node_modules/chalk/examples/demo.js"
printf 'ci\n' > "${prefix}/node_modules/chalk/.github/workflow.yml"
exit 0
EOF
chmod +x "${MOCK_BIN}/npm"

cat > "${MOCK_BIN}/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "apt-get should not be required in prune smoke checks" >&2
exit 1
EOF
chmod +x "${MOCK_BIN}/apt-get"

cat > "${MOCK_BIN}/makensis" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "${MOCK_BIN}/makensis"

if PATH="${MOCK_BIN}:${PATH}" \
  OPENCLAW_NPM_REGISTRY="${OPENCLAW_REGISTRY_URL}" \
  NODE_INDEX_URL="${NODE_INDEX_URL}" \
  NODE_DIST_BASE_URL="${NODE_DIST_BASE_URL}" \
  bash "${MOCK_ROOT}/scripts/build-win-x64.sh" >"${LOG_FILE}" 2>&1; then
  :
else
  cat "${LOG_FILE}" >&2
  exit 1
fi

PAYLOAD_ROOT="${MOCK_ROOT}/packaging/windows/payload"

if [[ -f "${PAYLOAD_ROOT}/app/openclaw/node_modules/chalk/index.d.ts" ]]; then
  echo "expected build script to prune TypeScript declaration files from vendored runtime dependencies" >&2
  exit 1
fi

if [[ -f "${PAYLOAD_ROOT}/app/openclaw/node_modules/chalk/index.js.map" ]]; then
  echo "expected build script to prune sourcemaps from vendored runtime dependencies" >&2
  exit 1
fi

if [[ -f "${PAYLOAD_ROOT}/app/openclaw/node_modules/chalk/README.md" ]]; then
  echo "expected build script to prune markdown docs from vendored runtime dependencies" >&2
  exit 1
fi

if [[ -f "${PAYLOAD_ROOT}/app/openclaw/node_modules/chalk/docs/guide.md" ]]; then
  echo "expected build script to prune markdown files inside vendored docs directories" >&2
  exit 1
fi

if [[ ! -f "${PAYLOAD_ROOT}/app/openclaw/node_modules/chalk/dist/doc/runtime.js" ]]; then
  echo "expected build script to preserve runtime JavaScript files inside doc directories" >&2
  exit 1
fi

if [[ -d "${PAYLOAD_ROOT}/app/openclaw/node_modules/chalk/tests" ]]; then
  echo "expected build script to prune tests directories from vendored runtime dependencies" >&2
  exit 1
fi

if [[ -d "${PAYLOAD_ROOT}/app/openclaw/node_modules/chalk/examples" ]]; then
  echo "expected build script to prune example directories from vendored runtime dependencies" >&2
  exit 1
fi

if [[ -d "${PAYLOAD_ROOT}/app/openclaw/node_modules/chalk/.github" ]]; then
  echo "expected build script to prune .github directories from vendored runtime dependencies" >&2
  exit 1
fi

if [[ ! -f "${PAYLOAD_ROOT}/app/openclaw/node_modules/chalk/package.json" ]]; then
  echo "expected runtime dependency metadata to remain after pruning" >&2
  exit 1
fi

if [[ -d "${PAYLOAD_ROOT}/app/node/node_modules/npm/docs" ]]; then
  echo "expected build script to prune embedded npm docs from the bundled Node runtime" >&2
  exit 1
fi

if [[ -d "${PAYLOAD_ROOT}/app/node/node_modules/npm/man" ]]; then
  echo "expected build script to prune embedded npm manpages from the bundled Node runtime" >&2
  exit 1
fi

if [[ -d "${PAYLOAD_ROOT}/app/node/node_modules/npm/tap-snapshots" ]]; then
  echo "expected build script to prune embedded npm snapshots from the bundled Node runtime" >&2
  exit 1
fi

if [[ ! -f "${PAYLOAD_ROOT}/app/node/node.exe" ]]; then
  echo "expected bundled node.exe to remain after pruning" >&2
  exit 1
fi

echo "Windows payload prune smoke check passed."
