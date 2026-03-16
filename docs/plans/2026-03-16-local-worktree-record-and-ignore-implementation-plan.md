# Local Worktree Record And Ignore Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Record the current local worktree state noted by Codex and ignore the generated `.build/` and `packaging/windows/payload/` directories.

**Architecture:** Keep the change small and explicit. Add one repository note that captures the Codex handoff context and current diff assessment, then add two root-scoped ignore rules so generated artifacts stop appearing in `git status` while tracked Rust source edits remain visible.

**Tech Stack:** Markdown, gitignore, git status, git diff

---

### Task 1: Add the worktree record note

**Files:**
- Create: `docs/notes/2026-03-16-local-worktree-record.md`
- Reference: `crates/launcher-app/src/diagnostics.rs`
- Reference: `crates/launcher-app/tests/diagnostics_tests.rs`
- Reference: `crates/process-supervisor/src/readiness.rs`
- Reference: `crates/runtime-config/src/env.rs`
- Reference: `crates/runtime-config/src/manifest.rs`
- Reference: `crates/runtime-config/tests/env_tests.rs`
- Reference: `crates/runtime-config/tests/manifest_tests.rs`

**Step 1: Write the note content**

List the seven modified Rust files, the two generated directories, and the current assessment that the Rust diffs are formatting-only.

**Step 2: Verify the note exists**

Run: `sed -n '1,220p' docs/notes/2026-03-16-local-worktree-record.md`
Expected: the note summarizes the Codex handoff warning and current local status.

### Task 2: Add narrow ignore rules

**Files:**
- Modify: `.gitignore`

**Step 1: Append ignore entries**

Add:

```gitignore
/.build/
/packaging/windows/payload/
```

**Step 2: Verify status changes**

Run: `git status --short`
Expected: `.build/` and `packaging/windows/payload/` disappear from the untracked list, while the seven Rust files remain modified.

### Task 3: Verify and commit

**Files:**
- Reference: `.gitignore`
- Reference: `docs/notes/2026-03-16-local-worktree-record.md`
- Reference: `docs/plans/2026-03-16-local-worktree-record-and-ignore-design.md`
- Reference: `docs/plans/2026-03-16-local-worktree-record-and-ignore-implementation-plan.md`

**Step 1: Run focused verification**

Run:

```bash
git diff --check -- .gitignore docs/notes/2026-03-16-local-worktree-record.md docs/plans/2026-03-16-local-worktree-record-and-ignore-design.md docs/plans/2026-03-16-local-worktree-record-and-ignore-implementation-plan.md
git status --short
```

Expected:

- no whitespace or merge-marker errors
- only the intended new docs and `.gitignore` change are staged for this task

**Step 2: Commit**

```bash
git add .gitignore \
  docs/notes/2026-03-16-local-worktree-record.md \
  docs/plans/2026-03-16-local-worktree-record-and-ignore-design.md \
  docs/plans/2026-03-16-local-worktree-record-and-ignore-implementation-plan.md
git commit -m "docs: record local worktree state"
```
