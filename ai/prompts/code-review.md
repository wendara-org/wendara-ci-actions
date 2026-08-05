# Code Review Prompt - Wendara CI Actions

Use this prompt for a local senior-engineer review of the current branch or working tree.

## Mission

Review changed CI/CD workflows and scripts for correctness, task alignment, public contract compatibility, security,
permissions, secret handling, release/publish/deploy safety, documentation, and validation. Produce findings only when
they are actionable and grounded in the diff or provided task context.

## Scope

- Review local changes only: `git diff` and, when useful, `git diff --staged`.
- If the user names a base branch, compare against that base with `git merge-base`.
- Task context is required unless the user explicitly says there is no task.
- If the user provides a ClickUp task id/link and the assistant has ClickUp MCP access, read the task through MCP.
- If ClickUp is not available, ask the user to paste the task summary and acceptance criteria.
- Do not review unrelated pre-existing code unless the diff makes the issue worse.
- Do not post to GitHub, create files, or archive review output.
- Do not run tests, workflows, publish, deploy, formatters, or linters unless the user explicitly asks.

## Initial Task Gate

Before reviewing, make sure task context is established.

If the user has not provided a task id, task link, pasted task content, or explicit "no task" statement, pause and ask:

```text
Before I review, please provide the ClickUp task link/id or paste the task summary and acceptance criteria. If there is no task, say "no task".
Also tell me whether the task is up to date or possibly stale.
```

If the user says there is no task, continue and mark task alignment as skipped.

If task context is provided, ask or infer whether it is:

- `up-to-date`: treat acceptance criteria as review ground truth.
- `possibly stale`: use it as intent context, but do not raise blocking findings solely because the implementation
  differs from stale wording; list mismatches under Questions or P2 unless the user confirms they are still required.

When task freshness is not stated, ask once before reviewing. If the user does not answer and wants the review to
continue, assume `possibly stale`.

## Context Loading

1. Read `ai/00_ALWAYS.md`.
2. Load only task-specific rules:
   - workflow YAML: `ai/02_WORKFLOW_RULES.md`
   - Bash scripts: `ai/03_SCRIPT_RULES.md`
   - release/publish/deploy/consumers: `ai/04_RELEASE_AND_CONSUMER_RULES.md`
   - examples/validation: `ai/06_EXAMPLES.md`, `ai/07_VALIDATION_RULES.md`
3. Inspect one or two relevant workflows/scripts and README sections only when needed to verify a pattern.

## Review Checklist

- Workflow contract: `workflow_call` inputs, secrets, outputs, defaults, required flags, job ids, artifact names, and
  output names stay backward-compatible or include migration docs.
- Caller compatibility: impacts on backend, mobile, landing, and API definitions are checked when reusable behavior
  changes.
- Permissions: `contents: write`, `packages: write`, `pull-requests: write`, `issues: write`, `checks: write`, and
  `id-token: write` have concrete job needs and are scoped as tightly as practical.
- Secrets/tokens: no tokens, private keys, auth headers, `.npmrc.ci`, Gradle credentials, SSH keys, or sensitive deploy
  output are printed, uploaded, summarized, or interpolated unsafely in commands.
- Shell scripts: touched scripts use strict Bash, quoted variables, early argument/tool validation, stable stdout
  contracts, deterministic paths, and clear exit codes.
- API-first safety: semantic diff guard, version source of truth, metadata behavior, selective publish, Redoc previews,
  npm/Maven naming, and reviewdog annotations remain intact.
- Java/Node/mobile safety: working directory handling, cache keys, npm auth, Gradle credentials, Docker/Jib, optional
  integration tests, Expo token usage, and EAS build constraints remain intact.
- Release/deploy safety: snapshot/stable semantics, semantic-release outputs, main-to-develop sync PR, GHCR/npm/Maven
  publish, checksums, artifacts, deploy diagnostics, and rollback/success markers remain intact.
- Documentation: README tables/examples are updated when inputs, secrets, outputs, permissions, jobs, scripts, or
  consumer usage changes.
- Validation: report which checks should be run; do not claim they passed unless actually executed.

## Noise Filter

- Do not raise findings for purely mechanical formatting, lint, or optional tool preferences unless the diff changes
  YAML/script validation policy, executable behavior, CI gates, or the user explicitly asks to review validation policy.
- If `actionlint`, ShellCheck, formatting, or other local tools would be useful but are not required by the changed
  behavior, list them under Validation instead of Findings.
- Findings must point to a changed file/line or a clearly missing required artifact.
- Do not report theoretical issues without a concrete failure mode.

## Finding Budget

- There is no total findings cap. Do not stop at 3 findings when more actionable issues exist.
- Include every valid `P0` and `P1` finding.
- Keep up to 10 highest-impact `P2` findings.
- Keep up to 12 useful nits for naming, spelling, wording, or local readability.
- If additional low-impact `P2` findings or nits are omitted, add: `N additional minor observations omitted after noise filter.`

## Testing Findings Policy

Raise `P1` for missing or weak validation when the diff changes meaningful executable behavior:

- Workflow YAML changes need actionlint when available and manual contract review.
- Shell script changes need `bash -n`; ShellCheck is expected when available.
- Release, publish, deploy, package, or sync changes need explicit validation notes because real workflows are usually
  not run locally.
- README-only changes do not need workflow execution unless they alter documented policy in a way that affects consumers.

## Output

Lead with findings ordered by severity. If there are no findings, say so clearly.

Use this format:

```markdown
## Findings

- [P1] Short title
  `path/to/file.yml:123` - Explain the issue, CI/consumer consequence, and concrete fix.

## Nits

- `path/to/file.sh:123` - Naming, spelling, wording, or small consistency fix.

## Questions

- Any blocking ambiguity or missing context.

## Validation

- Checks reviewed or recommended.
```

Severity guide:

- `P0`: secret leak, unsafe deploy/publish, widespread CI outage, or destructive release risk.
- `P1`: broken reusable contract, permission/security issue, broken publish/deploy/release behavior, or missing required
  validation.
- `P2`: maintainability, documentation, compatibility, diagnostics, or validation issue with real impact.
- `Nit`: naming, spelling, wording, formatting, or local readability issue.
