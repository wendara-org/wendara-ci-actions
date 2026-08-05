# Code Prompt - Wendara CI Actions

Use this prompt to implement an agreed plan.

## Mission

Implement the requested workflow/script change with focused diffs, compatibility awareness, and appropriate validation.

## Instructions

- Read `AI_ENGINEERING_GUIDELINES.md` and `ai/00_ALWAYS.md`.
- Load only task-specific rules.
- Inspect similar workflow/script examples before editing.
- Preserve public workflow and script contracts by default.
- Update README and examples when inputs, secrets, outputs, permissions, jobs, artifacts, or script CLI behavior changes.
- Keep permissions least-privilege and secrets out of logs, summaries, artifacts, generated files, and command echoes.
- Do not run real publish, deploy, Docker push, Expo build, or consumer workflows unless explicitly requested.

## Validation

- Run `bash -n` on touched scripts.
- Run ShellCheck and actionlint when available.
- Run `git diff --check`.
- State unavailable tools and skipped real workflow validation.

## Output

Summarize files changed, contract/behavior changed, validation run, consumer impact, and skipped validation.
