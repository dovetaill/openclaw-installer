# OpenClaw Windows Payload Pruning Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce Windows installer extraction time by pruning clearly non-runtime payload files before NSIS packaging while keeping installation fully complete at install time.

**Architecture:** Add one shared payload-pruning shell script that removes explicit development artifacts and markdown clutter from vendored `node_modules`, then invoke it from both Linux and Git Bash packaging flows before payload verification and staging. Preserve the full staged `package/docs` tree for the application itself, and verify behavior with fixture-based smoke tests that prove removable files disappear while required runtime files remain.

**Tech Stack:** Bash, Python-in-shell helpers, shell smoke tests, NSIS packaging flow

---

### Task 1: Add Failing Smoke Coverage For Payload Pruning

**Files:**
- Create: `tests/smoke/build-win-x64-prune-check.sh`
- Modify: `tests/smoke/build-win-x64-linux-bootstrap-check.sh`

**Step 1: Write the failing smoke test**

Create `tests/smoke/build-win-x64-prune-check.sh` with a fixture that seeds removable payload clutter:

```bash
mkdir -p "${prefix}/node_modules/chalk/docs" "${prefix}/node_modules/chalk/dist/doc" "${prefix}/node_modules/chalk/tests"
printf 'types\n' > "${prefix}/node_modules/chalk/index.d.ts"
printf 'map\n' > "${prefix}/node_modules/chalk/index.js.map"
printf 'readme\n' > "${prefix}/node_modules/chalk/README.md"
printf 'guide\n' > "${prefix}/node_modules/chalk/docs/guide.md"
printf 'runtime\n' > "${prefix}/node_modules/chalk/dist/doc/runtime.js"
printf 'keep\n' > "${prefix}/node_modules/chalk/package.json"
```

Add assertions after the build:

```bash
test ! -f "${payload_root}/app/openclaw/node_modules/chalk/index.d.ts"
test ! -f "${payload_root}/app/openclaw/node_modules/chalk/index.js.map"
test ! -f "${payload_root}/app/openclaw/node_modules/chalk/README.md"
test ! -f "${payload_root}/app/openclaw/node_modules/chalk/docs/guide.md"
test -f "${payload_root}/app/openclaw/node_modules/chalk/dist/doc/runtime.js"
test -f "${payload_root}/app/openclaw/node_modules/chalk/package.json"
```

Also seed removable files under embedded Node `node_modules/npm/docs`, `npm/man`, and `npm/tap-snapshots` and assert they are removed.

**Step 2: Run the smoke test to verify it fails**

Run:

```bash
bash tests/smoke/build-win-x64-prune-check.sh
```

Expected: FAIL because no pruning step exists yet, so the fixture's extra files still remain in the payload.

**Step 3: Keep bootstrap smoke aligned**

Update `tests/smoke/build-win-x64-linux-bootstrap-check.sh` fixture setup so it still passes after pruning, stages the full `package/docs` tree, and asserts required runtime files remain in both `docs` and `node_modules`.

**Step 4: Run smoke tests again to confirm only the new prune coverage fails**

Run:

```bash
bash tests/smoke/build-win-x64-prune-check.sh
bash tests/smoke/build-win-x64-linux-bootstrap-check.sh
```

Expected:

- `build-win-x64-prune-check.sh` fails because prune rules are not implemented
- `build-win-x64-linux-bootstrap-check.sh` still passes

**Step 5: Commit**

```bash
git add tests/smoke/build-win-x64-prune-check.sh \
  tests/smoke/build-win-x64-linux-bootstrap-check.sh
git commit -m "test: cover windows payload pruning"
```

### Task 2: Implement Shared Payload Pruning

**Files:**
- Create: `scripts/prune-windows-payload.sh`
- Modify: `scripts/build-win-x64.sh`
- Modify: `scripts/build-win-x64-git-bash.sh`

**Step 1: Implement the shared prune script**

Create `scripts/prune-windows-payload.sh` that:

```bash
require_dir "${payload_root}/app/openclaw/node_modules"
prune_patterns "${payload_root}/app/openclaw/node_modules"
prune_patterns "${payload_root}/app/node/node_modules"
prune_node_npm_docs "${payload_root}/app/node/node_modules/npm"
```

Implementation details:

- Accept payload root as an argument
- Return success when optional target directories are absent
- Remove only explicit file patterns and directory names from the approved design
- Leave `.bin`, runtime JS, package metadata, and native binaries untouched
- Avoid blanket deletion of `doc` or `docs` directories so runtime JS under paths like `dist/doc/*.js` survives
- Print a short summary line for each pruned root

**Step 2: Wire pruning into Linux build flow**

Update `scripts/build-win-x64.sh` so it runs:

```bash
bash "${ROOT_DIR}/scripts/prune-windows-payload.sh" "${ROOT_DIR}/packaging/windows/payload"
bash "${PAYLOAD_VERIFY_SCRIPT}" "${ROOT_DIR}/packaging/windows/payload"
```

Also update the payload staging step to copy the full `package/docs` tree into `app/openclaw/docs`.

The prune step must happen after payload hydration and before verification/staging.

**Step 3: Wire pruning into Git Bash packaging flow**

Update `scripts/build-win-x64-git-bash.sh` so it runs the same shared prune script against `packaging/windows/payload` before staging into `.build/windows-x64/payload`.

**Step 4: Run the smoke tests to verify they pass**

Run:

```bash
bash tests/smoke/build-win-x64-prune-check.sh
bash tests/smoke/build-win-x64-linux-bootstrap-check.sh
bash tests/smoke/build-win-x64-payload-guard-check.sh
bash tests/smoke/build-win-x64-runtime-source-check.sh
```

Expected:

- Prune-specific smoke test passes
- Existing Linux packaging smoke tests continue to pass
- Runtime-source smoke test is unaffected

**Step 5: Commit**

```bash
git add scripts/prune-windows-payload.sh \
  scripts/build-win-x64.sh \
  scripts/build-win-x64-git-bash.sh \
  tests/smoke/build-win-x64-prune-check.sh \
  tests/smoke/build-win-x64-linux-bootstrap-check.sh
git commit -m "feat: prune windows installer payload"
```

### Task 3: Verify The Real Workspace Payload Behavior

**Files:**
- Reference: `scripts/verify-payload.sh`
- Reference: `packaging/windows/payload/`

**Step 1: Run payload verification on the current workspace**

Run:

```bash
bash scripts/prune-windows-payload.sh packaging/windows/payload
bash scripts/verify-payload.sh packaging/windows/payload
```

Expected:

- Prune script completes without deleting required runtime files
- Payload verification passes

**Step 2: Measure the resulting payload footprint**

Run:

```bash
find packaging/windows/payload -type f | wc -l
du -sh packaging/windows/payload
```

Expected: Both values are lower than the pre-prune payload state, with the largest reduction in `app/openclaw/node_modules`.

**Step 3: Commit**

```bash
git add scripts/prune-windows-payload.sh \
  scripts/build-win-x64.sh \
  scripts/build-win-x64-git-bash.sh \
  tests/smoke/build-win-x64-prune-check.sh \
  tests/smoke/build-win-x64-linux-bootstrap-check.sh
git commit -m "chore: verify pruned windows payload"
```
