# GitHub Actions CI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add lightweight GitHub Actions CI for every push and pull request, plus a separate manual workflow that packages the Windows installer and uploads `OpenClaw-Setup.exe`.

**Architecture:** Split automation into two workflows so frequent code pushes only run fast verification, while packaging remains opt-in through `workflow_dispatch`. Reuse the existing shell entrypoints in `scripts/` and `tests/smoke/` so local verification and GitHub Actions stay aligned.

**Tech Stack:** GitHub Actions, Bash smoke scripts, Rust toolchain, Node.js, NSIS

---

### Task 1: Add lightweight CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`
- Reference: `scripts/smoke-launcher.sh`
- Reference: `tests/smoke/nsis-script-check.sh`
- Reference: `tests/smoke/build-win-x64-linux-bootstrap-check.sh`
- Reference: `tests/smoke/build-win-x64-runtime-source-check.sh`
- Reference: `tests/smoke/build-win-x64-payload-guard-check.sh`
- Reference: `tests/smoke/build-win-x64-prune-check.sh`

**Step 1: Define push and pull_request triggers**

Run the workflow for normal branch pushes and PR validation only.

**Step 2: Install the minimum host dependencies**

Provision the Rust toolchain plus shell utilities required by the smoke scripts.

**Step 3: Reuse repository smoke commands**

Execute the existing launcher and packaging smoke scripts directly instead of duplicating checks in YAML.

### Task 2: Add manual packaging workflow

**Files:**
- Create: `.github/workflows/package.yml`
- Reference: `scripts/build-win-x64.sh`

**Step 1: Define workflow_dispatch input**

Expose a `runtime_source` choice so maintainers can build either `translated` or `upstream` payloads on demand.

**Step 2: Prepare the packaging environment**

Install Rust, Node.js, NSIS, zip, and unzip on Ubuntu so the existing build script can run unchanged.

**Step 3: Build and upload the installer artifact**

Run `bash scripts/build-win-x64.sh --runtime-source <value>` and upload `.build/windows-x64/dist/OpenClaw-Setup.exe` as a retained Actions artifact.

### Task 3: Verify and commit

**Files:**
- Reference: `.github/workflows/ci.yml`
- Reference: `.github/workflows/package.yml`

**Step 1: Validate workflow syntax and repo checks**

Run lightweight local verification that the YAML parses and that the referenced smoke scripts still execute in the current tree.

**Step 2: Review staged changes only**

Stage only the new workflow and plan files so unrelated working tree edits remain untouched.

**Step 3: Commit**

```bash
git add .github/workflows/ci.yml .github/workflows/package.yml docs/plans/2026-03-16-github-actions-ci-implementation-plan.md
git commit -m "ci: add github actions workflows"
```
