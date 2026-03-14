# OpenClaw Runtime Source Selection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Windows installer builds default to the translated OpenClaw runtime, allow an explicit upstream mode, and show the selected runtime release version in both the installer and launcher.

**Architecture:** Resolve runtime source metadata once in the build scripts, serialize it into `manifest.json`, and reuse that metadata in both NSIS and the launcher UI. Keep failure handling strict at build time so GitHub release version, npm package version, staged payload, and displayed version cannot drift.

**Tech Stack:** Bash, Python-in-shell helpers, NSIS, Rust, Slint, cargo test, shell smoke tests

---

### Task 1: Runtime Source Selection In Build Scripts

**Files:**
- Create: `tests/smoke/build-win-x64-runtime-source-check.sh`
- Modify: `scripts/build-win-x64.sh`
- Modify: `scripts/build-win-x64-git-bash.sh`
- Modify: `manifest.json`
- Modify: `tests/smoke/build-win-x64-linux-bootstrap-check.sh`
- Modify: `tests/smoke/build-win-x64-payload-guard-check.sh`

**Step 1: Write the failing smoke test**

Create `tests/smoke/build-win-x64-runtime-source-check.sh` with fixture-based assertions for:

```bash
grep -Fq 'runtime_source":"translated"' "${LOG_OR_MANIFEST}"
grep -Fq 'runtime_package":"@qingchencloud/openclaw-zh"' "${LOG_OR_MANIFEST}"
grep -Fq 'runtime_source":"upstream"' "${LOG_OR_MANIFEST}"
grep -Fq 'runtime_package":"openclaw"' "${LOG_OR_MANIFEST}"
```

The fixture should mock:

- GitHub release lookup for translated and upstream repos
- npm metadata lookup for translated and upstream packages
- payload staging and `manifest.json` copy

**Step 2: Run the smoke test to verify it fails**

Run: `bash tests/smoke/build-win-x64-runtime-source-check.sh`

Expected: FAIL because the build scripts do not yet understand runtime source selection or extended manifest metadata.

**Step 3: Implement minimal source resolution and manifest generation**

Update the build scripts so they:

```bash
parse_runtime_source_flag "$@"
resolve_selected_release_metadata
assert_release_matches_npm_latest
write_manifest_json_with_runtime_metadata
stage_manifest_from_generated_file
```

Implementation details:

- Default source is translated
- Add an explicit source flag for upstream mode
- Resolve GitHub latest release and npm latest version for the selected source
- Normalize release tags like `v2026.3.12-zh.2` to `2026.3.12-zh.2`
- Fail closed if GitHub and npm versions differ
- Generate the final staged manifest from resolved metadata instead of copying the static root manifest unchanged
- Update fixture-based smoke tests that currently assume `{ "version": "0.1.0" }`

**Step 4: Run the smoke tests to verify they pass**

Run:

```bash
bash tests/smoke/build-win-x64-runtime-source-check.sh
bash tests/smoke/build-win-x64-linux-bootstrap-check.sh
bash tests/smoke/build-win-x64-payload-guard-check.sh
```

Expected:

- All pass
- Default path asserts translated source
- Explicit source path asserts upstream source
- Generated manifest includes runtime metadata fields

**Step 5: Commit**

```bash
git add tests/smoke/build-win-x64-runtime-source-check.sh \
  scripts/build-win-x64.sh \
  scripts/build-win-x64-git-bash.sh \
  manifest.json \
  tests/smoke/build-win-x64-linux-bootstrap-check.sh \
  tests/smoke/build-win-x64-payload-guard-check.sh
git commit -m "feat: add runtime source selection to windows builds"
```

### Task 2: NSIS Branding And Runtime Version Display

**Files:**
- Modify: `packaging/windows/openclaw-installer.nsi`
- Modify: `packaging/windows/include/layout.nsh`
- Modify: `packaging/windows/include/uninstall.nsh`
- Modify: `tests/smoke/nsis-script-check.sh`
- Modify: `tests/smoke/nsis-linux-compile-check.sh`

**Step 1: Write the failing NSIS checks**

Extend `tests/smoke/nsis-script-check.sh` to assert:

```bash
assert_contains 'BrandingText[[:space:]]+"kitlabs\.app © 制作"'
assert_contains 'https://github\.com/kitlabs-app/openclaw-installer'
assert_contains 'runtime_display_name|PRODUCT_RUNTIME_VERSION'
assert_contains 'WriteRegStr HKCU ".+" "Publisher" "kitlabs\.app"'
```

Extend `tests/smoke/nsis-linux-compile-check.sh` so fixture defines include runtime display metadata and fail if the script still relies on hardcoded `0.1.0`.

**Step 2: Run the NSIS checks to verify they fail**

Run:

```bash
bash tests/smoke/nsis-script-check.sh
bash tests/smoke/nsis-linux-compile-check.sh
```

Expected: FAIL because the current NSIS script does not show runtime metadata, repo URL, or the new branding text.

**Step 3: Implement minimal NSIS metadata plumbing**

Update the NSIS layer so it accepts and uses build-provided runtime metadata:

```nsi
!define PRODUCT_PUBLISHER "kitlabs.app"
!define PRODUCT_RUNTIME_DISPLAY "OpenClawChineseTranslation v2026.3.12-zh.2"
BrandingText "kitlabs.app © 制作"
WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "DisplayVersion" "${PRODUCT_RUNTIME_VERSION}"
```

Implementation details:

- Keep installer filename as `OpenClaw-Setup.exe`
- Show runtime display text in the UI
- Show installer repository URL in the UI
- Set uninstall `Publisher` to `kitlabs.app`
- Set uninstall `DisplayVersion` to the packaged runtime version
- Accept values from build-script defines instead of duplicating runtime inference in NSIS

**Step 4: Run the NSIS checks to verify they pass**

Run:

```bash
bash tests/smoke/nsis-script-check.sh
bash tests/smoke/nsis-linux-compile-check.sh
```

Expected:

- Script smoke checks pass
- Linux NSIS compile smoke check produces an installer successfully with the new defines

**Step 5: Commit**

```bash
git add packaging/windows/openclaw-installer.nsi \
  packaging/windows/include/layout.nsh \
  packaging/windows/include/uninstall.nsh \
  tests/smoke/nsis-script-check.sh \
  tests/smoke/nsis-linux-compile-check.sh
git commit -m "feat: brand installer with runtime metadata"
```

### Task 3: Launcher Manifest Loading And Version Display

**Files:**
- Modify: `crates/runtime-config/src/manifest.rs`
- Create: `crates/runtime-config/tests/manifest_tests.rs`
- Modify: `crates/launcher-app/src/app.rs`
- Modify: `crates/launcher-app/src/browser.rs`
- Modify: `crates/launcher-app/ui/main-window.slint`
- Create: `crates/launcher-app/tests/manifest_display_tests.rs`

**Step 1: Write the failing Rust tests**

Add `crates/runtime-config/tests/manifest_tests.rs` covering:

```rust
assert_eq!(manifest.runtime_source, "translated");
assert_eq!(manifest.runtime_version, "2026.3.12-zh.2");
assert_eq!(manifest.runtime_display(), "OpenClawChineseTranslation v2026.3.12-zh.2");
```

Add `crates/launcher-app/tests/manifest_display_tests.rs` covering:

```rust
assert_eq!(ui_runtime_label(&manifest), "Runtime: OpenClaw v2026.3.13");
assert_eq!(ui_runtime_label_from_missing_manifest(), "Runtime: unknown");
assert_eq!(installer_repo_url(), "https://github.com/kitlabs-app/openclaw-installer");
```

Prefer extracting pure helpers for manifest loading and display formatting so the tests do not need full UI process startup.

**Step 2: Run the Rust tests to verify they fail**

Run:

```bash
cargo test -p runtime-config --test manifest_tests -- --nocapture
cargo test -p launcher-app --test manifest_display_tests -- --nocapture
```

Expected: FAIL because manifest metadata fields, formatting helpers, and installer repo action do not exist yet.

**Step 3: Implement minimal manifest loading and UI display**

Add manifest loading and display helpers:

```rust
impl PayloadManifest {
    fn from_install_root(root: &Path) -> Result<Self, String> { ... }
    fn runtime_display(&self) -> String { ... }
}

fn runtime_label(manifest: Option<&PayloadManifest>) -> String {
    match manifest {
        Some(manifest) => format!("Runtime: {}", manifest.runtime_display()),
        None => "Runtime: unknown".into(),
    }
}
```

Update launcher UI so it:

- Reads the manifest from the install root
- Sets the window title and heading with runtime display text
- Shows a runtime label
- Shows the installer repository URL
- Adds a button or action to open `https://github.com/kitlabs-app/openclaw-installer`
- Falls back to `Runtime: unknown` if manifest loading fails

**Step 4: Run the Rust tests to verify they pass**

Run:

```bash
cargo test -p runtime-config --test manifest_tests -- --nocapture
cargo test -p launcher-app --test manifest_display_tests -- --nocapture
cargo test
```

Expected:

- New focused tests pass
- Existing launcher and runtime-config tests stay green

**Step 5: Commit**

```bash
git add crates/runtime-config/src/manifest.rs \
  crates/runtime-config/tests/manifest_tests.rs \
  crates/launcher-app/src/app.rs \
  crates/launcher-app/src/browser.rs \
  crates/launcher-app/ui/main-window.slint \
  crates/launcher-app/tests/manifest_display_tests.rs
git commit -m "feat: show packaged runtime version in launcher"
```

### Task 4: Final Verification

**Files:**
- Modify: any files touched above if verification exposes gaps

**Step 1: Run the full verification suite**

Run:

```bash
bash tests/smoke/build-win-x64-runtime-source-check.sh
bash tests/smoke/build-win-x64-linux-bootstrap-check.sh
bash tests/smoke/build-win-x64-payload-guard-check.sh
bash tests/smoke/nsis-script-check.sh
bash tests/smoke/nsis-linux-compile-check.sh
cargo test
```

Expected:

- All smoke tests pass
- All Rust tests pass
- No remaining hardcoded installer runtime version assumptions

**Step 2: Review requirements against the design doc**

Check each approved requirement against:

- `docs/plans/2026-03-14-openclaw-runtime-source-selection-design.md`
- Installer runtime display
- Launcher runtime display
- Default translated source behavior
- Explicit upstream source behavior
- `kitlabs.app © 制作`
- `https://github.com/kitlabs-app/openclaw-installer`

Expected: every approved requirement is matched by code and verification evidence.

**Step 3: Commit any final verification fixes**

```bash
git add <files-fixed-during-verification>
git commit -m "test: finalize runtime source selection verification"
```
