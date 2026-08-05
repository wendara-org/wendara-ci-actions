# Claude Instructions - Wendara CI Actions

Start with `AGENTS.md`, `AI_ENGINEERING_GUIDELINES.md`, and `ai/00_ALWAYS.md`.

Load only task-specific rules from `ai/`:

- context: `ai/01_CONTEXT.md`
- workflow YAML: `ai/02_WORKFLOW_RULES.md`
- Bash scripts: `ai/03_SCRIPT_RULES.md`
- release/publish/deploy/consumers: `ai/04_RELEASE_AND_CONSUMER_RULES.md`
- examples: `ai/06_EXAMPLES.md`
- validation: `ai/07_VALIDATION_RULES.md`

Do not load the entire `ai/` folder by default. Prefer targeted workflow/script reads and one or two consumer examples.

For local code review, use `ai/prompts/code-review.md`. Ask for ClickUp task context or explicit "no task", and ask
whether the task is up-to-date or possibly stale.
