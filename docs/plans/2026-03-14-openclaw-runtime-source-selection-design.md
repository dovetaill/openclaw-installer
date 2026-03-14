# OpenClaw Runtime Source Selection Design

## Background

The current Windows installer build defaults to the upstream `openclaw` npm package and hardcodes installer metadata such as `PRODUCT_VERSION=0.1.0`.

The requested behavior changes are:

- Default Windows builds should package the Chinese translation runtime from `1186258278/OpenClawChineseTranslation`
- An explicit build parameter should switch packaging back to the upstream `openclaw/openclaw` runtime
- Runtime selection must follow each repository's latest GitHub release, not a stale local constant
- `OpenClaw-Setup.exe` and `OpenClaw Launcher.exe` must display the packaged runtime release version
- NSIS branding text must show `kitlabs.app © 制作`
- The installer and launcher should expose the installer project URL `https://github.com/kitlabs-app/openclaw-installer`

As of March 14, 2026, the latest releases confirmed during design were:

- Upstream: `openclaw/openclaw` -> `v2026.3.13`
- Chinese translation: `1186258278/OpenClawChineseTranslation` -> `v2026.3.12-zh.2`

The matching npm `latest` dist-tags at the same time were:

- `openclaw@latest` -> `2026.3.13`
- `@qingchencloud/openclaw-zh@latest` -> `2026.3.12-zh.2`

## Goals

1. Make translated runtime packaging the default behavior for `scripts/build-win-x64.sh`
2. Add a build-time switch for upstream packaging
3. Keep GitHub release version, npm package version, staged payload, installer UI, and launcher UI aligned
4. Surface both the packaged runtime identity and the installer project's own branding
5. Preserve the existing installer shape, launcher architecture, and payload layout

## Non-Goals

- Renaming the installer output file from `OpenClaw-Setup.exe`
- Rewriting the launcher into a different UI framework
- Changing the current installation directory strategy
- Introducing an auto-update mechanism
- Adding support for additional runtime sources beyond upstream and translated builds

## Options Considered

### Option A: Single manifest as source of truth

Build-time source resolution writes all runtime metadata into `manifest.json`, and both NSIS packaging and the launcher read from that manifest.

Pros:

- One canonical metadata source for installer, launcher, diagnostics, and future tooling
- Avoids duplicated parsing logic across Bash, NSIS, and Rust
- Makes smoke tests straightforward because version and source are serialized once

Cons:

- Requires extending the manifest schema and its consumers

### Option B: Separate version plumbing in each layer

Resolve runtime metadata in Bash, pass some fields directly to NSIS defines, and independently load package metadata inside the launcher.

Pros:

- Smaller first diff in any single file

Cons:

- Creates drift risk between payload contents, installer metadata, launcher display, and uninstall registry values
- Harder to test and maintain

## Decision

Adopt Option A.

The build script will resolve runtime source metadata once, write it into `manifest.json`, and pass any required installer fields from that same resolved data. NSIS and the launcher will consume the manifest rather than infer runtime identity independently.

## Runtime Source Model

Two runtime source profiles are supported:

### Translated source (default)

- GitHub repository: `1186258278/OpenClawChineseTranslation`
- npm package: `@qingchencloud/openclaw-zh`
- Runtime display name: `OpenClawChineseTranslation`

### Upstream source (opt-in)

- GitHub repository: `openclaw/openclaw`
- npm package: `openclaw`
- Runtime display name: `OpenClaw`

## Build Behavior

`scripts/build-win-x64.sh` will accept a source selector, with translated mode as the default.

Expected behavior:

- Default invocation packages the translated runtime
- An explicit flag selects upstream packaging
- Build logic resolves the latest GitHub release for the selected repository
- Build logic resolves the npm `latest` version for the matching package
- The build proceeds only when the normalized GitHub release tag matches the npm `latest` version
- The payload is staged from the selected npm package
- The selected runtime metadata is written into the staged manifest and reused downstream

## Manifest Contract

The current manifest only contains the installer version and bundle entries. It will be extended to store runtime identity and source metadata.

Required fields:

- `installer_version`
- `node_version`
- `runtime_source`
- `runtime_package`
- `runtime_version`
- `runtime_release_tag`
- `runtime_release_url`
- `runtime_display_name`
- `entries`

Display expectations:

- Translated build example: `OpenClawChineseTranslation v2026.3.12-zh.2`
- Upstream build example: `OpenClaw v2026.3.13`

## Installer UI And Branding

`OpenClaw-Setup.exe` keeps its filename, but its visible metadata becomes runtime-aware.

Installer behavior:

- Product name remains `OpenClaw`
- Welcome and install flow should show the packaged runtime display string
- Branding text at the bottom of the installer becomes `kitlabs.app © 制作`
- Installer UI includes the repository URL `https://github.com/kitlabs-app/openclaw-installer`
- Uninstall registry publisher becomes `kitlabs.app`
- Uninstall registry display version becomes the packaged runtime version rather than the old hardcoded installer version

This separates the packaged runtime identity from the installer project's own branding:

- Runtime identity answers "what OpenClaw build is inside this installer"
- Installer branding answers "who built and distributed this installer"

## Launcher UI

The launcher must show the packaged runtime version taken from the manifest.

Launcher behavior:

- Window title includes the runtime display string
- Main heading includes the runtime display string
- UI exposes the installer repository URL
- UI provides a direct action to open the installer project page
- If the manifest cannot be read, launcher display falls back to `Runtime: unknown` without blocking normal launch behavior

## Failure Handling

Build-time failures should be explicit and fail closed.

The build must stop when:

- GitHub latest release lookup fails
- npm metadata lookup fails
- GitHub release tag cannot be normalized
- npm `latest` does not match the normalized GitHub release tag
- Required payload contents are missing after download or hydration

The launcher may degrade display-only metadata, but not silently invent version information.

## Testing Strategy

Testing should cover source selection, metadata propagation, and installer branding.

Required coverage:

- Smoke test for default translated build source
- Smoke test for explicit upstream source selection
- Smoke test for manifest fields written by the build script
- NSIS script check for branding text and repository URL
- Launcher tests for manifest parsing and version display fallback

## Implementation Notes

- Preserve existing payload verification and staging flow where possible
- Avoid embedding duplicated source constants in multiple languages if they can be serialized once from the build step
- Keep the user-facing naming stable: `OpenClaw-Setup.exe` and `OpenClaw Launcher.exe` stay unchanged
