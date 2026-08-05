# Always-On AI Rules - Wendara CI Actions

Load this file before any non-trivial AI-assisted work.

## Core Rules

- This repo contains reusable CI/CD contracts used by multiple Wendara repos. Treat compatibility as a primary concern.
- Do not change `workflow_call` inputs, secrets, outputs, defaults, permissions, artifact names, job ids, or script CLI
  args without checking consumers and README examples.
- Use least-privilege permissions. Prefer job-level permissions when only one job needs write access.
- Never log, echo, persist, upload, or summarize secrets, tokens, private keys, auth headers, `.npmrc.ci`, Gradle
  credentials, SSH keys, or sensitive deploy output.
- Preserve semantic-release, snapshot/stable publishing, main-to-develop sync PRs, GHCR/npm/Maven publish, Redoc,
  reviewdog, checksums, and deploy diagnostics unless explicitly changing them.
- Keep Bash scripts strict, quoted, deterministic, and explicit about required tools.
- Do not run real publish, deploy, Docker push, Expo build, or consumer workflows unless explicitly requested.

## Context Loading

- Load only the rule files relevant to the task.
- For workflow YAML changes, load `ai/02_WORKFLOW_RULES.md`.
- For Bash script changes, load `ai/03_SCRIPT_RULES.md`.
- For release, publish, deploy, mobile build, or consumer compatibility changes, load
  `ai/04_RELEASE_AND_CONSUMER_RULES.md`.
- For validation, load `ai/07_VALIDATION_RULES.md`.

## Validation

- Prefer static validation: `bash -n`, ShellCheck when available, actionlint when available, and manual contract review.
- State clearly when tools are unavailable or when real workflows were not executed.
