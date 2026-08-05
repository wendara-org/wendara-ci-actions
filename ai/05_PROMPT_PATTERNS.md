# Prompt Patterns - Wendara CI Actions

Use these snippets to keep AI work focused.

## Explore

Investigate without editing files. Read `AI_ENGINEERING_GUIDELINES.md` and `ai/00_ALWAYS.md`, then load only workflow,
script, release, or validation rules relevant to the task. Report affected contracts, consumers, permissions, secrets,
scripts, docs, risks, and validation.

## Plan

Create a decision-complete plan. Include affected workflows/scripts, public contract changes, caller compatibility,
permission/secret impact, documentation updates, validation commands, assumptions, and migration needs.

## Code

Implement the agreed plan with minimal diffs. Preserve compatibility by default. Update workflow YAML, scripts, README,
and examples together when contracts change. Do not run real publish/deploy/build workflows unless explicitly requested.

## Review

Use `ai/prompts/code-review.md`. Provide ClickUp task context or explicitly say `no task`, and state whether the task is
`up-to-date` or `possibly stale`.

## Output Size Control

Prefer targeted file references and concise summaries. Do not paste full workflows or long logs into chat unless needed.
