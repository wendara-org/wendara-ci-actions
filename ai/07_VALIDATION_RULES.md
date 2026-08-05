# Validation Rules

Use this file before finishing changes.

## Documentation-Only AI Rule Changes

- Run `git diff --check`.
- Check Markdown links and referenced paths manually.
- Do not run real workflows, publish artifacts, deploy, or execute consumer workflows.

## Workflow Changes

- Run `actionlint .github/workflows/*.yml` when actionlint is installed.
- Manually review `workflow_call` inputs, secrets, outputs, defaults, permissions, job ids, artifact names, and README
  examples.
- Confirm changed permissions match real job needs.
- Confirm consumer repositories have a migration path for breaking changes.

## Script Changes

- Run `bash -n` on touched scripts, or `find scripts -name '*.sh' -print0 | xargs -0 -n1 bash -n` for all scripts.
- Run ShellCheck when installed.
- Validate script arguments, required tools, output lines consumed by workflows, and failure modes.
- Avoid executing scripts that publish, deploy, push images, call Expo EAS, or mutate package registries unless
  explicitly requested.

## Release/Deploy/Publish Changes

- Do not perform live publish/deploy validation by default.
- Review semantic-release, snapshot/stable, sync PR, GHCR/npm/Maven, checksums, artifacts, and deploy diagnostics
  manually.
- State which real workflow behavior was not executed.
