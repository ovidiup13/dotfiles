# AGENTS.md

## Purpose

This repository is a cross-platform dotfiles and machine bootstrap setup.
Agents working here should optimize for safe, repeatable shell-script changes.

The main workflows are:
- bootstrap a new machine with `bootstrap`
- run the full installer with `./install`
- run macOS-only post-link skill sync with `./install --skills`
- manage symlinked files under `home/`

## Repository Layout

- `install` is the main entrypoint
- `bootstrap` installs prerequisites, clones or updates the repo, then runs `install`
- `.macos` handles macOS setup, Homebrew packages, runtimes, shell tooling, and skills sync
- `.ubuntu` handles Ubuntu package setup and shell prerequisites
- `scripts/lib/` contains shared helpers
- `scripts/install/` contains installer modules
- `packages/base/Brewfile` contains shared Homebrew packages
- `packages/macos/Brewfile` and `packages/macos/Brewfile.mas` contain macOS packages
- `packages/ubuntu/apt.txt` contains Ubuntu packages
- `packages/macos/skills.txt` contains exact skill mappings as `<source> <skill>`
- `home/` contains files that are symlinked into `$HOME`

## Agent Rules Discovery

At the time this file was written, no repository-local agent rule files were present:
- no `.github/copilot-instructions.md`
- no `.cursorrules`
- no `.cursor/rules/`

If any of those files are added later, treat them as higher-priority repository instructions and update this file.

## Build, Lint, and Test Commands

This repo does not have a formal test suite, Makefile, npm package, or CI-oriented lint target.
Validation is mostly shell syntax checking plus targeted smoke tests.

### Primary Commands

- Full install: `./install`
- macOS skills sync only: `./install --skills`
- Bootstrap flow: `./bootstrap`
- macOS setup directly: `./.macos`
- macOS post-link skills sync: `./.macos --post-link`
- Ubuntu setup directly: `./.ubuntu`

### Syntax Checks

Use `bash -n` for any shell file you edit.

- Main installer: `bash -n install`
- Bootstrap script: `bash -n bootstrap`
- macOS installer: `bash -n .macos`
- Ubuntu installer: `bash -n .ubuntu`
- Shared library: `bash -n scripts/lib/common.sh`
- Skills installer: `bash -n scripts/install/skills.sh`

### Single-File / Single-Target Validation

There is no single-test framework, so the closest equivalent is validating one script at a time.

- Validate one edited script: `bash -n path/to/file.sh`
- Smoke test one installer path: `./install --skills`
- Smoke test macOS post-link stage only: `./.macos --post-link`
- Smoke test Ubuntu path only: `./.ubuntu`

### Helpful Focused Checks

- Verify installed skills manifest behavior: `./install --skills`
- Verify skill manifest format manually: inspect `packages/macos/skills.txt`
- Verify apt package list changes: inspect `packages/ubuntu/apt.txt`
- Verify Brew package list changes: inspect `packages/base/Brewfile` and `packages/macos/Brewfile`

### Optional External Tools

If available on the machine, these are useful but not required by the repo itself:

- `shellcheck path/to/script.sh`
- `shfmt -w path/to/script.sh`

Do not assume they are installed unless you verify first.

## Style Guidelines

### General

- Prefer portable Bash over Bash tricks that reduce readability
- Keep scripts idempotent; rerunning `./install` should stay safe
- Favor small functions with one responsibility
- Reuse shared helpers from `scripts/lib/` instead of duplicating logic
- Preserve the current logging style with `log_step`, `log_info`, `log_warn`, `log_error`, and `log_success`
- Fail early with clear messages when prerequisites are missing

### Shebang and Safety Flags

- Use `#!/usr/bin/env bash`
- Use `set -euo pipefail` near the top of every script
- Keep those lines in new shell modules unless there is a strong reason not to

### Imports and Sourcing

- Compute repo root with the existing pattern based on `CDPATH='' cd -- "$(dirname -- ...)"`
- Source shared files with `.` not `source`, matching repository style
- Group sourced dependencies near the top of the file after `REPO_ROOT`
- Source only what the script actually uses

### Functions

- Use `snake_case` for function names
- Keep public installer functions descriptive, e.g. `install_macos_runtimes`
- Declare `local` variables at the top of functions where practical
- Prefer returning via exit status for checks and `printf` for simple value output
- Avoid overly clever pipelines when a loop is clearer

### Variables and Quoting

- Use uppercase only for exported environment/config variables like `REPO_ROOT`, `GOENV_ROOT`, or `DOTFILES_GIT_NAME`
- Use lowercase for local variables and function-scoped state
- Quote variable expansions unless unquoted splitting is explicitly intended
- Quote command substitutions when assigning strings
- Use braces for nontrivial expansions like `${VAR:-default}` and `${source#prefix}`
- Prefer `$(...)` over backticks

### Conditionals and Control Flow

- Use `case` for platform branching, matching current code style
- Prefer `[ ... ]` tests, which are used consistently across the repo
- Keep happy-path code near the top when possible
- Exit with `log_error` before `exit 1` for fatal paths
- Use guard clauses to reduce nesting

### Command Usage

- Check for tool presence with `command_exists` when that helper is available
- For privileged operations, rely on the existing sudo helpers instead of embedding ad hoc sudo refresh logic
- Avoid destructive commands unless the workflow clearly requires them
- Suppress noisy command output only when the script already follows that pattern

### Naming Conventions

- Function names: `snake_case`
- Local variables: `snake_case`
- Exported config/env variables: `UPPER_SNAKE_CASE`
- Files under `scripts/install/`: descriptive by domain, e.g. `git.sh`, `skills.sh`, `shell.sh`

### Error Handling

- Prefer explicit prerequisite checks before running platform-specific commands
- Emit actionable errors, not generic failures
- Use warnings for optional steps that can be skipped safely
- Keep noninteractive installs working; fall back to env vars when prompting is not possible
- Preserve existing behavior that prevents running installers as root

### Output and UX

- Keep user-facing messages short and consistent
- Use `log_step` for major phases
- Use `log_info` for individual actions
- Use `log_warn` for recoverable skips
- Use `log_success` only when an operation completed successfully

## File-Specific Guidance

### `packages/macos/skills.txt`

- Each non-comment line must be exactly `<source> <skill>`
- Do not reintroduce wildcard installs such as `--skill '*'`
- Keep entries unique and deterministic
- If a source is private or flaky, prefer removing it over leaving the installer broken

### `home/`

- Anything added under `home/` will be symlinked into `$HOME`
- Be careful with sensitive defaults and machine-specific values
- Prefer composable shell fragments under `home/.config/shell/` over duplicating logic across shells

### Package Lists

- Keep package manifests simple, one package declaration per line where applicable
- Preserve comment style and ordering unless there is a reason to regroup
- Avoid adding packages unless they are clearly used by the install flow or shell environment

## Change Expectations for Agents

- Make the smallest safe change that solves the task
- Do not replace existing patterns with a different shell style without a reason
- Validate every edited shell script with `bash -n`
- When behavior changes, mention the exact command a human can run to verify it
- If adding a new workflow, document it here and in `README.md` when appropriate

## Recommended Verification After Common Changes

- Installer logic change: `bash -n install && bash -n .macos && bash -n .ubuntu`
- Skills logic change: `bash -n scripts/install/skills.sh && ./install --skills`
- Bootstrap logic change: `bash -n bootstrap`
- Symlink behavior change: `bash -n scripts/lib/symlink.sh` and inspect `home/` targets carefully

## What Not to Assume

- Do not assume npm, Python test runners, or Go tooling are part of the repo workflow
- Do not assume ShellCheck or shfmt are installed
- Do not assume private GitHub repositories referenced by manifests are accessible
- Do not assume a CI system will catch shell syntax issues for you
