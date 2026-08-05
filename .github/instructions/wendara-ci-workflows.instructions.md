---
applyTo: ".github/workflows/**/*.yml,.github/workflows/**/*.yaml"
---

# Wendara CI Workflow Instructions

- Treat `workflow_call` inputs, secrets, outputs, defaults, required flags, job ids, and artifact names as public
  contracts.
- Prefer backward-compatible additions with safe defaults.
- Update README tables/examples when workflow contracts, permissions, jobs, artifacts, or consumer usage changes.
- Use least-privilege permissions and job-level scoping when practical.
- Justify write permissions such as `contents`, `packages`, `pull-requests`, `issues`, `checks`, or `id-token`.
- Pass secrets through environment variables where possible; do not echo or upload secrets.
- Preserve ci-actions checkout paths used by caller repositories.
- Preserve semantic-release, snapshot/stable, sync PR, GHCR/npm/Maven publish, Redoc, reviewdog, deploy diagnostics, and
  Expo/EAS behavior unless explicitly changing them.
- Do not run real publish/deploy/build workflows unless explicitly requested.
