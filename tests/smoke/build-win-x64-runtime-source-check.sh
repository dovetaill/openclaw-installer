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

OPENCLAW_REGISTRY_URL="https://mirror.example/npm"
TRANSLATED_PACKAGE="@qingchencloud/openclaw-zh"
UPSTREAM_PACKAGE="openclaw"
TRANSLATED_RELEASE_URL="https://api.github.com/repos/1186258278/OpenClawChineseTranslation/releases/latest"
UPSTREAM_RELEASE_URL="https://api.github.com/repos/openclaw/openclaw/releases/latest"
NODE_INDEX_URL="https://mirror.example/node/index.json"
NODE_DIST_BASE_URL="https://mirror.example/node/dist"
NODE_ZIP_URL="${NODE_DIST_BASE_URL}/v24.14.0/node-v24.14.0-win-x64.zip"

create_package_fixture() {
  local fixture_root="$1"
  local version="$2"
  local package_name="$3"
  local tarball_path="$4"

  mkdir -p \
    "${fixture_root}/package/dist" \
    "${fixture_root}/package/assets" \
    "${fixture_root}/package/extensions" \
    "${fixture_root}/package/skills/demo"

  cat > "${fixture_root}/package/openclaw.mjs" <<'EOF'
#!/usr/bin/env node
if (process.argv.includes('--help')) {
  console.log('openclaw help')
}
EOF

  cat > "${fixture_root}/package/package.json" <<EOF
{"name":"${package_name}","version":"${version}","engines":{"node":">=22.16.0"},"dependencies":{"chalk":"^5.6.2"}}
EOF

  printf 'export const entry = true;\n' > "${fixture_root}/package/dist/entry.js"
  printf 'export const boot = true;\n' > "${fixture_root}/package/dist/index.js"
  printf 'asset\n' > "${fixture_root}/package/assets/icon.txt"
  printf 'extension\n' > "${fixture_root}/package/extensions/example.txt"
  printf '# demo skill\n' > "${fixture_root}/package/skills/demo/SKILL.md"

  tar -czf "${tarball_path}" -C "${fixture_root}" package
}

run_case() {
  local case_name="$1"
  local runtime_arg="$2"
  local expected_source="$3"
  local expected_package="$4"
  local expected_version="$5"
  local expected_release_tag="$6"
  local metadata_url="$7"
  local tarball_url="$8"

  local case_root="${TMP_DIR}/${case_name}"
  local mock_root="${case_root}/workspace"
  local mock_bin="${case_root}/bin"
  local fixture_dir="${case_root}/fixtures"
  local runtime_fixture="${fixture_dir}/runtime"
  local log_file="${case_root}/build.log"
  local install_marker="${case_root}/cargo-xwin-installed"
  local expected_xwin_cache_dir="${mock_root}/.build/windows-x64/xwin-cache"
  local manifest_path="${mock_root}/.build/windows-x64/payload/manifest.json"

  mkdir -p \
    "${mock_root}/scripts" \
    "${mock_root}/packaging/windows" \
    "${mock_root}/target/x86_64-pc-windows-msvc/release" \
    "${mock_bin}" \
    "${fixture_dir}" \
    "${runtime_fixture}"

  cp "${SOURCE_SCRIPT}" "${mock_root}/scripts/build-win-x64.sh"
  cp "${VERIFY_SCRIPT}" "${mock_root}/scripts/verify-payload.sh"
  chmod +x "${mock_root}/scripts/build-win-x64.sh" "${mock_root}/scripts/verify-payload.sh"

  printf '{ "version": "0.1.0" }\n' > "${mock_root}/manifest.json"
  printf 'launcher-binary\n' > "${mock_root}/target/x86_64-pc-windows-msvc/release/launcher-app.exe"
  printf 'nsis\n' > "${mock_root}/packaging/windows/openclaw-installer.nsi"

  create_package_fixture "${runtime_fixture}" "${expected_version}" "${expected_package}" "${fixture_dir}/runtime.tgz"

  mkdir -p "${fixture_dir}/node/node-v24.14.0-win-x64"
  printf 'node-binary\n' > "${fixture_dir}/node/node-v24.14.0-win-x64/node.exe"
  printf 'npm shim\n' > "${fixture_dir}/node/node-v24.14.0-win-x64/npm.cmd"
  printf 'npx shim\n' > "${fixture_dir}/node/node-v24.14.0-win-x64/npx.cmd"
  (cd "${fixture_dir}/node" && zip -qr "${fixture_dir}/node.zip" node-v24.14.0-win-x64)

  cat > "${fixture_dir}/npm-metadata.json" <<EOF
{
  "dist-tags": {
    "latest": "${expected_version}"
  },
  "versions": {
    "${expected_version}": {
      "dist": {
        "tarball": "${tarball_url}"
      },
      "engines": {
        "node": ">=22.16.0"
      }
    }
  }
}
EOF

  cat > "${fixture_dir}/release.json" <<EOF
{
  "tag_name": "${expected_release_tag}",
  "html_url": "https://github.com/example/release/${expected_release_tag}"
}
EOF

  cat > "${fixture_dir}/node-index.json" <<'EOF'
[
  {
    "version": "v24.14.0",
    "lts": "Krypton",
    "files": ["win-x64-zip"]
  }
]
EOF

  cat > "${mock_bin}/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail

fixture_dir="${fixture_dir}"
output=""
url=""

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
  "${metadata_url}") src="\${fixture_dir}/npm-metadata.json" ;;
  "${tarball_url}") src="\${fixture_dir}/runtime.tgz" ;;
  "${NODE_INDEX_URL}") src="\${fixture_dir}/node-index.json" ;;
  "${NODE_ZIP_URL}") src="\${fixture_dir}/node.zip" ;;
  "${TRANSLATED_RELEASE_URL}"|"${UPSTREAM_RELEASE_URL}") src="\${fixture_dir}/release.json" ;;
  *)
    echo "unexpected curl url: \${url}" >&2
    exit 1
    ;;
esac

cp "\${src}" "\${output}"
EOF
  chmod +x "${mock_bin}/curl"

  cat > "${mock_bin}/cargo" <<EOF
#!/usr/bin/env bash
set -euo pipefail

marker="${install_marker}"

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
  if [[ "\${XWIN_CACHE_DIR:-}" != "${expected_xwin_cache_dir}" ]]; then
    echo "unexpected XWIN_CACHE_DIR: \${XWIN_CACHE_DIR:-unset}" >&2
    exit 1
  fi
  exit 0
fi

echo "unexpected cargo invocation: \$*" >&2
exit 1
EOF
  chmod +x "${mock_bin}/cargo"

  cat > "${mock_bin}/npm" <<'EOF'
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
EOF
  chmod +x "${mock_bin}/npm"

  cat > "${mock_bin}/makensis" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
  chmod +x "${mock_bin}/makensis"

  cat > "${mock_bin}/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "apt-get should not be required in runtime source smoke checks" >&2
exit 1
EOF
  chmod +x "${mock_bin}/apt-get"

  if PATH="${mock_bin}:${PATH}" \
    OPENCLAW_NPM_REGISTRY="${OPENCLAW_REGISTRY_URL}" \
    NODE_INDEX_URL="${NODE_INDEX_URL}" \
    NODE_DIST_BASE_URL="${NODE_DIST_BASE_URL}" \
    bash "${mock_root}/scripts/build-win-x64.sh" ${runtime_arg} >"${log_file}" 2>&1; then
    :
  else
    cat "${log_file}" >&2
    exit 1
  fi

  if [[ ! -f "${manifest_path}" ]]; then
    echo "missing staged manifest for ${case_name}: ${manifest_path}" >&2
    cat "${log_file}" >&2
    exit 1
  fi

  grep -Fq "\"runtime_source\": \"${expected_source}\"" "${manifest_path}" || {
    echo "expected runtime_source ${expected_source} in staged manifest for ${case_name}" >&2
    cat "${manifest_path}" >&2
    exit 1
  }

  grep -Fq "\"runtime_package\": \"${expected_package}\"" "${manifest_path}" || {
    echo "expected runtime_package ${expected_package} in staged manifest for ${case_name}" >&2
    cat "${manifest_path}" >&2
    exit 1
  }

  grep -Fq "\"runtime_version\": \"${expected_version}\"" "${manifest_path}" || {
    echo "expected runtime_version ${expected_version} in staged manifest for ${case_name}" >&2
    cat "${manifest_path}" >&2
    exit 1
  }
}

run_case \
  translated-default \
  "" \
  translated \
  "${TRANSLATED_PACKAGE}" \
  2026.3.12-zh.2 \
  v2026.3.12-zh.2 \
  "${OPENCLAW_REGISTRY_URL}/${TRANSLATED_PACKAGE}" \
  "https://mirror.example/tarballs/openclaw-zh-2026.3.12-zh.2.tgz"

run_case \
  upstream-selected \
  "--runtime-source upstream" \
  upstream \
  "${UPSTREAM_PACKAGE}" \
  2026.3.13 \
  v2026.3.13 \
  "${OPENCLAW_REGISTRY_URL}/${UPSTREAM_PACKAGE}" \
  "https://mirror.example/tarballs/openclaw-2026.3.13.tgz"

echo "Runtime source selection smoke checks passed."
