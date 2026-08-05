# Plan Prompt - Wendara CI Actions

Use this prompt after exploration and before implementation.

## Mission

Create a decision-complete implementation plan for the requested CI/CD workflow or script change.

## Instructions

- Read `AI_ENGINEERING_GUIDELINES.md` and `ai/00_ALWAYS.md`.
- Load only task-specific rules and examples.
- Identify affected workflows, scripts, public contracts, README sections, and consumer repositories.
- Explicitly cover inputs, secrets, outputs, defaults, permissions, artifacts, release behavior, migration needs, and
  validation.
- Prefer backward-compatible additions over breaking changes.
- Do not propose real publish/deploy execution unless explicitly requested.

## Output

Return a concise plan with summary, implementation changes, validation commands, compatibility/migration notes, and
assumptions.
