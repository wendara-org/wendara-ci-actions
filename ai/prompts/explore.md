# Explore Prompt - Wendara CI Actions

Use this prompt to investigate a task without editing files.

## Mission

Understand the current workflow/script behavior, public contracts, consumer impact, permission/secret surface, and
validation needs before planning or coding.

## Instructions

- Read `AI_ENGINEERING_GUIDELINES.md` and `ai/00_ALWAYS.md`.
- Load only task-specific rules:
  - workflow YAML: `ai/02_WORKFLOW_RULES.md`
  - Bash scripts: `ai/03_SCRIPT_RULES.md`
  - release/publish/deploy/consumers: `ai/04_RELEASE_AND_CONSUMER_RULES.md`
  - validation: `ai/07_VALIDATION_RULES.md`
- Inspect the smallest useful set of workflows, scripts, README sections, and consumer examples.
- Do not edit files or run mutating workflows/scripts.

## Output

Return current behavior, public contracts, affected consumers, permission/secret risks, compatibility risks, validation
needs, open questions, and recommended next step.
