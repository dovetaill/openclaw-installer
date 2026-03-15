# OpenClaw Windows Payload Pruning Design

## Background

The current Windows installer packages a payload with roughly 38,000 files and about 727 MB of staged content.

Most of the installation slowdown comes from `app/openclaw/node_modules`, which contains more than 32,000 small files. On Windows, NSIS extraction of many small files is slow, and endpoint security tools often scan each extracted file, which amplifies the delay.

The requested behavior changes are:

- Keep the current NSIS installer flow and offline installation model
- Keep installation complete at install time, with no first-launch expansion or preparation work
- Reduce the number of packaged files by removing content that is clearly not needed at runtime
- Preserve runtime behavior for the packaged OpenClaw application and the embedded Node runtime

## Goals

1. Reduce Windows installer extraction time by pruning obviously non-runtime payload files before packaging
2. Keep the installed directory complete immediately after installation
3. Apply the same pruning rules to both Linux-driven packaging and Git Bash packaging flows
4. Preserve the current payload layout, launcher startup flow, and NSIS install semantics

## Non-Goals

- Changing the installer technology away from NSIS
- Moving extraction cost to first launch
- Rebuilding or rebundling OpenClaw upstream dependencies
- Introducing aggressive dependency tree shaking based on guessed runtime reachability
- Removing functional OpenClaw integrations or narrowing supported runtime features

## Options Considered

### Option A: Conservative file-pattern pruning during build

After payload hydration, remove only files and directories that are strongly associated with development, typing, documentation, tests, and examples.

Pros:

- Low risk because it avoids touching JS entrypoints, JSON metadata, native binaries, or runtime assets
- Keeps install semantics unchanged
- Can be shared by both packaging scripts
- Directly reduces the small-file count that hurts Windows extraction time

Cons:

- Does not minimize payload as aggressively as dependency-aware pruning

### Option B: Package-level whitelist pruning

Keep only files reachable from each dependency's `main` or `exports` graph plus known runtime assets.

Pros:

- Potentially much larger size and file-count reduction

Cons:

- High risk because OpenClaw and some dependencies use dynamic imports, runtime path lookups, plugins, and native bindings
- Difficult to verify safely in one change

### Option C: Archive the runtime payload inside the installer and expand after install

Ship fewer top-level installer entries by packaging the runtime into one or more archives and extract them after installation or on first launch.

Pros:

- Large reduction in installer-side file count

Cons:

- Violates the requirement that installation finishes with the full file set already present
- Simply moves the same cost to another phase

## Decision

Adopt Option A.

The build process will prune only clearly non-runtime files before NSIS packages the payload. The pruning logic will live in one shared script so Linux packaging and Git Bash packaging stay aligned.

## Pruning Rules

The pruning pass will target two payload roots:

- `packaging/windows/payload/app/openclaw/node_modules`
- `packaging/windows/payload/app/node/node_modules`

Files to remove:

- `*.d.ts`
- `*.map`
- `*.md`
- `*.markdown`

Directories to remove when found under `node_modules`:

- `test`
- `tests`
- `__tests__`
- `man`
- `example`
- `examples`
- `tap-snapshots`
- `.github`

Additional Node runtime cleanup:

- `npm/docs`
- `npm/man`
- `npm/tap-snapshots`

## Preservation Rules

The pruning pass must not remove files that may be runtime inputs:

- `package.json`
- `*.js`
- `*.mjs`
- `*.cjs`
- `*.json`
- `*.node`
- `*.dll`
- `*.exe`
- `*.cmd`
- `*.ps1`
- `*.wasm`
- `node_modules/.bin`
- license and notice files
- JavaScript files nested under paths like `dist/doc/*.js`
- OpenClaw payload directories such as `dist`, `assets`, `docs`, `extensions`, and `skills`

The packaged `OpenClaw` runtime must keep the full `package/docs` tree. Runtime code resolves paths under `packageRoot/docs`, including `docs/reference/templates`, so pruning must never remove staged application docs outside `node_modules`.

This keeps the change scoped to obviously non-runtime content and avoids guessing about dynamic module loading.

## Build Flow

The pruning step happens after payload hydration and before payload verification.

Linux packaging flow:

1. Download and hydrate runtime payload
2. Download and extract embedded Windows Node runtime
3. Run shared payload pruning script
4. Verify payload
5. Stage payload and package with NSIS

Git Bash packaging flow:

1. Validate staged payload exists
2. Run shared payload pruning script against staged payload
3. Resolve runtime metadata
4. Stage payload and package with NSIS

Running the pruning step in both flows avoids drift between Linux-generated payloads and locally staged Windows payloads.

## Failure Handling

The pruning script should fail closed when:

- The expected payload roots do not exist in a context where they should
- The pruning command itself fails

The verifier should continue to enforce required runtime files after pruning, so a bad pruning rule fails during build rather than producing a broken installer.

## Testing Strategy

Required coverage:

- Smoke test that seeds removable files into fixture payloads and asserts they are removed after build
- Smoke test that seeds required runtime files and asserts they remain
- Continued `verify-payload.sh` execution to confirm `openclaw.mjs --help` still works after pruning
- Coverage for both Linux build flow and Git Bash packaging flow, or shared-script coverage plus one packaging-flow integration assertion

## Implementation Notes

- Prefer a dedicated shared script for pruning instead of duplicating `find` logic in multiple build scripts
- Keep the prune rules explicit and auditable
- Log the pruning step in build output so it is visible when diagnosing packaging regressions
