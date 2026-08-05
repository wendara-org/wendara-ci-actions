# AI Engineering Guidelines - Wendara CI Actions

This document is the entry point for AI-assisted work in Wendara CI Actions. It applies to Codex, GitHub Copilot,
Claude, and other coding assistants.

It complements the repository documentation. If there is a conflict, the official docs and human direction prevail.

## Source of Truth

- [README](README.md)
- Reusable workflows in `.github/workflows/`
- Helper scripts in `scripts/`
- Consumer workflow examples in backend, mobile, landing, and API definitions repositories

## How AI Should Load Context

1. Read [Always-On AI Rules](ai/00_ALWAYS.md) first.
2. Load only the task-specific rule files needed for the current work.
3. Before changing a reusable contract, inspect the workflow, README section, and at least one consumer example.
4. Do not load the full `ai/` folder by default.

Task-specific rules:

- Repository context: [Context](ai/01_CONTEXT.md)
- Workflow contracts: [Workflow Rules](ai/02_WORKFLOW_RULES.md)
- Bash scripts: [Script Rules](ai/03_SCRIPT_RULES.md)
- Release and consumers: [Release and Consumer Rules](ai/04_RELEASE_AND_CONSUMER_RULES.md)
- Prompt patterns: [Prompt Patterns](ai/05_PROMPT_PATTERNS.md)
- Examples: [Examples](ai/06_EXAMPLES.md)
- Validation: [Validation Rules](ai/07_VALIDATION_RULES.md)

Reusable prompt templates live in [ai/prompts](ai/prompts). They are versioned prompts, not universal slash commands.
Whether `/explore`, `/plan`, `/code`, or `/code-review` works depends on the tool.

## Non-Negotiable Principles

- Treat `workflow_call` inputs, secrets, outputs, defaults, permissions, job ids, artifact names, and script CLI args as
  public contracts.
- Preserve compatibility for Wendara consumer repos unless a breaking migration is explicit and documented.
- Use least-privilege permissions and scoped tokens.
- Never print, persist, or upload secrets, tokens, private keys, auth headers, `.npmrc.ci`, Gradle credentials, SSH keys,
  or deploy logs containing sensitive values.
- Do not weaken release, publish, deploy, reviewdog, semantic diff, checksum, or sync-PR behavior without explicit
  approval.
- Keep workflows deterministic and debuggable with clear summaries, artifacts, and failure modes.
- Do not run real publish/deploy/build workflows unless explicitly requested.

## Definition of Done

A non-trivial AI-assisted change is complete only when:

- workflow/script contracts and README examples are updated together;
- permission and secret changes are justified;
- caller compatibility is checked or migration steps are documented;
- touched scripts pass `bash -n`, and ShellCheck is run when available;
- touched workflows are checked with actionlint when available;
- skipped validations or unavailable tools are stated clearly.

This repository is AI-assisted, not AI-driven. Human CI/CD ownership always prevails.
