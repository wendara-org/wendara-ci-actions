# Workflow Rules

Use this file for `.github/workflows/*.yml` changes.

## Public Contract

- Treat `workflow_call` inputs, secrets, outputs, defaults, required flags, job ids, output names, and artifact names as
  public API.
- Preserve existing callers unless the change is explicitly breaking and migration steps are documented.
- Keep README inputs/secrets/outputs/job tables and consumer examples aligned with workflow YAML.
- Prefer additive inputs with safe defaults over changing existing behavior.

## Permissions and Tokens

- Use least privilege. Prefer `contents: read` unless a job pushes commits, creates releases, publishes packages, or
  opens PRs.
- Justify `contents: write`, `packages: write`, `pull-requests: write`, `issues: write`, `checks: write`, or `id-token:
  write`.
- Keep write permissions job-scoped when possible.
- Prefer passing secrets through `env` over direct interpolation in shell commands.
- Never expose tokens, `.npmrc.ci`, Gradle credentials, SSH keys, package tokens, or auth headers in logs, summaries, or
  artifacts.

## Job Behavior

- Keep concurrency intentional. Do not cancel release/publish jobs unless the workflow is designed for it.
- Preserve checkout depth where semantic-release, tags, changelog, or diff logic needs history.
- Keep ci-actions checkout paths stable when scripts are invoked from caller repositories.
- Keep optional behavior optional, such as integration tests only when a script exists.
- Upload artifacts with stable names and no secrets.
- Keep summaries useful but free of sensitive data.

## External Actions

- Prefer pinned major versions already used in the repo.
- Do not introduce untrusted third-party actions without review.
- Document new external tool requirements in README.
