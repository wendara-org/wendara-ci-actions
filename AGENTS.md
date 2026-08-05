# Repository Guidelines

## Project Structure & Module Organization

Wendara CI Actions centralizes reusable GitHub Actions workflows and helper scripts. Reusable workflows live in
`.github/workflows/`. Composite/custom action docs live in `.github/actions/`. Helper scripts live in `scripts/`:
`api-first` for OpenAPI automation, `java` for backend Gradle/Jib flows, and `web` for Node web artifact packaging.

## Build, Test, and Development Commands

- `find scripts -name '*.sh' -print0 | xargs -0 -n1 bash -n`: syntax-check shell scripts.
- `find scripts -name '*.sh' -print0 | xargs -0 shellcheck`: lint shell scripts when ShellCheck is installed.
- `actionlint .github/workflows/*.yml`: validate GitHub workflow syntax when actionlint is installed.
- Manual review: compare `workflow_call` inputs, secrets, outputs, permissions, and README examples.

There is no package manager gate in this repo. Do not add `package.json` only for AI rules.

## Coding Style & Naming Conventions

Use clear YAML names, stable job ids, and explicit `workflow_call` descriptions. Bash scripts should use
`set -euo pipefail`, quoted variables, early argument validation, explicit dependency checks, deterministic output paths,
and clear exit codes. Keep comments and logs in English. Never print tokens, secrets, private keys, or auth headers.

## Testing Guidelines

Validate the smallest affected surface. For scripts, run `bash -n` and ShellCheck if available. For workflows, run
actionlint if available and manually verify caller contracts. Do not run real publish, deploy, Docker push, Expo build,
or consumer workflows unless explicitly requested.

## Code Review Rules

### Reusable workflow contracts

- Flag breaking changes to `workflow_call` inputs, secrets, outputs, defaults, job outputs, artifact names, or documented
  caller examples unless a migration path is documented.
  Safe path: preserve compatibility or document required consumer updates for backend, mobile, landing, and API
  definitions.

### Permissions and secrets

- Flag broad `permissions` or token use without a concrete job need, and any secret exposure through logs, artifacts,
  command interpolation, summaries, or generated files.
  Safe path: use minimal job-level permissions, pass secrets via env, and avoid echoing sensitive values.

### Release and publish safety

- Flag changes that can break snapshot/stable versioning, semantic-release, main-to-develop sync PRs, GHCR/npm/Maven
  publish, checksums, deploy diagnostics, reviewdog annotations, or selective API publishing.
  Safe path: preserve release contracts and update README plus consumers when behavior changes.

### Review noise control

- Do not flag mechanical formatting or optional tool preferences unless YAML/script validation policy, CI behavior, or
  executable code changed.
  Safe path: mention optional `actionlint` or `shellcheck` under Validation, not Findings.

## Commit & Pull Request Guidelines

Use Conventional Commits, for example `fix(workflows): preserve node web release output`. PRs should describe impacted
workflows/scripts, caller compatibility, permissions/secrets changes, validation run, and any migration required.

## Agent-Specific Instructions

For AI-assisted work, read `AI_ENGINEERING_GUIDELINES.md` and `ai/00_ALWAYS.md` first. Load only task-specific rules.
Reusable modes live in `ai/prompts/`. For reviews, ask for ClickUp context or explicit "no task", plus task freshness.

## Context & Token Usage

Keep context focused. Prefer targeted workflow/script reads and one or two consumer examples over broad file dumps. Load
workflow, script, release, or validation rules only when the task touches those areas.
