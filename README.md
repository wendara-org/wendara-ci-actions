# Wendara CI Actions

Reusable GitHub Actions **workflows** and **helper scripts** for Wendara’s engineering stack.

- **One place** to codify CI/CD standards.
- **Contract‑first** automation for OpenAPI (lint, semantic diff guard, changelog, Redoc, selective publish).
- **Backend** pipelines for Java 21 + Gradle + Spring Boot + **Jib**.
- **Web/Mobile** pipelines for Node/TypeScript (React, Next.js, React Native).
- **Post‑release sync** from `main` back to `develop`.

---

## Table of Contents

- [Purpose](#purpose)
- [Folder Structure](#folder-structure)
- [Conventions & Assumptions](#conventions--assumptions)
- [Reusable Workflows](#reusable-workflows)
  - [API‑first (`reusable-api-contracts.yml`)](#api-first-reusable-api-contractsyml)
  - [Contract Validation Only (`reusable-verify-contracts.yml`)](#contract-validation-only-reusable-verify-contractsyml)
  - [Backend (`reusable-backend.yml`)](#backend-reusable-backendyml)
  - [Node Apps (`reusable-node-app.yml`)](#node-apps-reusable-node-appyml)
- [Helper Scripts](#helper-scripts)
- [Reviewdog & PR annotations](#reviewdog--pr-annotations)
- [How Versioning, Publishing & Changelog Work](#how-versioning-publishing--changelog-work)
- [Post‑release Sync (main → develop)](#postrelease-sync-main--develop)
- [Redoc Previews](#redoc-previews)
- [Using These Workflows Across Repos](#using-these-workflows-across-repos)
- [Requirements](#requirements)
- [Troubleshooting](#troubleshooting)

---

## Purpose

Centralize and reuse CI/CD logic across Wendara repositories while enforcing consistent quality gates:

- **OpenAPI**: YAML sanity, lint, **semantic diff guard** (breaking change detection), **changelog generation**, **Redoc
  ** previews, and **selective publishing** (only changed APIs).
- **Backend**: Java 21 + Gradle quality gates, unit tests & coverage, image build with **Jib**, OWASP security check.
- **Web/Mobile**: Type checks, ESLint, unit tests, optional build.

---

## Folder Structure

```
wendara-ci-actions/
├─ .editorconfig
├─ .gitattributes
├─ .commitlintrc.json
├─ README.md
├─ scripts/
│  ├─ clean-ghcr-snapshots.sh            # Clean old GHCR snapshot versions
│  ├─ read-version.sh                    # Resolve semantic-release version
│  ├─ api-first/
│  │  ├─ api-oasdiff-guard.sh            # OpenAPI semantic diff guard
│  │  ├─ oasdiff-changelog.sh            # Generate changelog entries from diff
│  │  ├─ redoc-build.sh                  # Build Redoc preview from spec
│  │  └─ verify-all-specs.sh             # Validate all specs in repo
│  ├─ java/
│  │  ├─ gradle-quality.sh               # checkstyle, pmd, spotbugs, jacoco
│  │  ├─ run-java-unit-tests.sh          # Run unit tests
│  │  ├─ start-java-integration-env.sh   # Start docker compose env
│  │  ├─ run-java-integration-tests.sh   # Run integration tests
│  │  └─ stop-java-integration-env.sh    # Stop docker compose env
│  └─ node/
│     └─ node-quality.sh                 # tsc --noEmit, eslint, tests
└─ .github/
   └─ workflows/
      ├─ reusable-api-contracts.yml       # API-first validation and publish
      ├─ reusable-verify-contracts.yml    # Validate all OpenAPI specs
      ├─ reusable-backend.yml             # Backend CI (Gradle, tests, release)
      ├─ reusable-node-app.yml            # Node CI (TS, ESLint, tests)
      └─ reusable-manual-post-release.yml # Manual rerun of docker/sync after release
```

---

## Conventions & Assumptions

- **Branches**: `develop` (integration) and `main` (stable).
- **API layout** in consumer repos (e.g., `wendara-api-definitions`):
  - `apis/<transport>/<apiName>/<major>/openapi.yaml`
  - Optional **per‑API** `metadata.yml`
  - Optional **root** `metadata.yml` for publishing whitelist
- **Version source of truth**: `info.version` inside each `openapi.yaml`
- **Version flavor**: `develop` → `x.y.z-SNAPSHOT`, `main` → `x.y.z` stable
- **Conventional Commits** enforced across all repos

---

## Reusable Workflows

### API‑first (`reusable-api-contracts.yml`)

End‑to‑end automation for OpenAPI contracts: lint → semantic guard → changelog → Redoc previews → selective publish →
sync PR.

**What it does**

1. Detects changed specs (`openapi.yaml`) and related per‑API `metadata.yml`; also reacts to changes in **root**
   `metadata.yml`.
2. **Validates** YAML and runs **Redocly lint** using the consumer’s `.redocly.yaml` (if present).
3. Runs **semantic diff guard** (Tufin `oasdiff`) and fails PRs on breaking changes unless the **major** version was
   bumped.
4. Generates **changelog entries** (MAJOR/MINOR/PATCH).
5. Optionally builds **Redoc HTML previews** and uploads them as artifacts.
6. **Publishes only changed APIs**:

- on `develop`: **SNAPSHOT** artifacts
- on `main`: **stable** artifacts

7. After stable publish on `main`, opens a **PR main → develop** to keep branches in sync.

**Inputs**

| Name                  | Type    | Default | Description                                                      |
|-----------------------|---------|---------|------------------------------------------------------------------|
| `java_version`        | string  | `21`    | Java toolchain for Gradle tasks.                                 |
| `node_version`        | string  | `22`    | Node.js version for Redoc build, lint tools.                     |
| `run_redoc`           | boolean | `true`  | Build Redoc HTML previews.                                       |
| `publish_enabled`     | boolean | `false` | If true, publishes artifacts (set to `true` on `push`, not PR).  |
| `require_listed_only` | boolean | `true`  | If true, only APIs listed in root `metadata.yml` are considered. |

**Secrets**

| Secret           | Purpose                                                 |
|------------------|---------------------------------------------------------|
| `PACKAGES_TOKEN` | Token with `packages:write` (typically `GITHUB_TOKEN`). |

**Consumer example** (`wendara-api-definitions/.github/workflows/ci.yml`):

```yaml
name: API Contracts · CI

on:
  push:
    branches: [ develop, main ]
    paths:
      - "apis/*/*/*/openapi.yaml"
      - "apis/*/*/*/metadata.yml"
      - "metadata.yml"
      - ".redocly.yaml"
      - "build.gradle.kts"
      - "settings.gradle.kts"
  pull_request:
    branches: [ develop, main ]
    paths:
      - "apis/*/*/*/openapi.yaml"
      - "apis/*/*/*/metadata.yml"
      - "metadata.yml"
      - ".redocly.yaml"
  workflow_dispatch:

permissions:
  contents: write
  packages: write
  pull-requests: write

concurrency:
  group: contracts-${{ github.ref }}
  cancel-in-progress: false

jobs:
  api:
    uses: wendara-org/wendara-ci-actions/.github/workflows/reusable-api-contracts.yml@main
    with:
      java_version: "21"
      node_version: "22"
      run_redoc: true
      publish_enabled: ${{ github.event_name == 'push' }}
      require_listed_only: true
    secrets:
      PACKAGES_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

### Contract Validation Only (`reusable-verify-contracts.yml`)

Standalone reusable workflow to **validate all OpenAPI specs** across a repository — regardless of whether they
changed — without publishing anything. Useful for PRs and early feedback.

**What it does**

1. Scans the repo for OpenAPI specs (`openapi.yaml`) using standard layout.
2. Validates each spec using **Redocly CLI lint**.
3. Validates that `info.version` exists and follows **semver**.
4. Annotates PRs with inline errors using **reviewdog**.
5. Runs on every PR or manually via `workflow_dispatch`. Does **not** publish artifacts.

**Requirements**

- `REVIEWDOG_GITHUB_API_TOKEN` must be set to `${{ secrets.GITHUB_TOKEN }}` to allow inline annotations.
- The script `.wendara-ci-actions/scripts/verify-all-specs.sh` must be present and executable.
- The reusable workflow must `checkout` the `ci-actions` repo to access scripts.

**Consumer example** (`wendara-api-definitions/.github/workflows/verify-contracts.yml`):

```yaml
name: Verify All Contracts

on:
  pull_request:
    branches: [ develop, main ]
  workflow_dispatch:

permissions:
  contents: read
  pull-requests: write

jobs:
  verify:
    uses: wendara-org/wendara-ci-actions/.github/workflows/reusable-verify-contracts.yml@main
    with:
      node_version: "20"
```

---

### Backend (`reusable-backend.yml`)

End‑to‑end CI pipeline for Java 21 + Gradle + Spring Boot with quality checks, image publishing and sync PR.

**What it does**

1. Runs Java quality gates: `checkstyle`, `pmd`, `spotbugs`, and `jacoco` coverage.
2. Executes **unit tests** and **integration tests** using Docker Compose.
3. Uses **semantic-release** to resolve the version and auto-tag commits.
4. Builds and pushes a **Docker image** using **Jib**, versioned with the release.
5. On `develop`: keeps **SNAPSHOT** Docker images.
6. On `main`: publishes **stable** Docker images and creates a **sync PR** to `develop`.
7. Runs an **OWASP Dependency Check** on `main` after release.
8. Cleans up old GHCR **snapshot** images to save space.

**Inputs**

| Name              | Type   | Required | Description                                                                |
|-------------------|--------|----------|----------------------------------------------------------------------------|
| `release-channel` | string | ✅        | `develop` or `main`. Controls version flavor, Docker publishing, and sync. |
| `package-name`    | string | ✅        | GHCR package name (e.g. `wendara-backend`). Used for Docker and cleanup.   |

**Secrets**

| Secret         | Purpose                                             |
|----------------|-----------------------------------------------------|
| `GITHUB_TOKEN` | Used for semantic-release, GHCR push, and sync PRs. |

**Jobs**

| Job                 | Description                                                          |
|---------------------|----------------------------------------------------------------------|
| `quality-checks`    | Runs code quality tools (`checkstyle`, `pmd`, `spotbugs`, `jacoco`). |
| `unit-tests`        | Runs unit tests.                                                     |
| `integration-tests` | Starts Docker Compose env, runs integration tests, and stops it.     |
| `release`           | Runs `semantic-release` to resolve version and tag commits.          |
| `docker`            | Builds and pushes Docker image via Jib. Requires valid version.      |
| `clean-snapshots`   | Removes old snapshot Docker tags, keeping the latest N.              |
| `sync-pr`           | On `main`, creates PR to sync changes back to `develop`.             |
| `owasp-check`       | Runs OWASP Dependency Check after stable release (`main` only).      |

**Example usage** (`wendara-backend/.github/workflows/ci.yml`):

```yaml
name: Backend · CI

on:
  push:
    branches: [ develop, main ]
  pull_request:
    branches: [ develop, main ]
  workflow_dispatch:

permissions:
  contents: write
  packages: write
  pull-requests: write

jobs:
  backend:
    uses: wendara-org/wendara-ci-actions/.github/workflows/reusable-backend.yml@main
    with:
      release-channel: ${{ github.ref_name }}
      package-name: wendara-backend
```

---

### Node Apps (`reusable-node-app.yml`)

Reusable pipeline for Node/TS apps (web or mobile):

- Type checks (`tsc --noEmit`)
- ESLint
- Unit tests
- Optional production build

---

## Helper Scripts

- `clean-ghcr-snapshots.sh` — Delete old snapshot images, keeping latest N + current
- `read-version.sh` — Read the latest version from release commit
- `api-first/api-oasdiff-guard.sh` — Guard against breaking changes
- `api-first/oasdiff-changelog.sh` — Build changelog entries
- `api-first/redoc-build.sh` — Generate Redoc previews
- `api-first/verify-all-specs.sh` — Validate all specs across the repo
- `java/gradle-quality.sh` — Run all Gradle quality tools
- `java/run-java-unit-tests.sh` — Run unit tests
- `java/start-java-integration-env.sh` / `stop-java-integration-env.sh` — Start/stop test infra
- `java/run-java-integration-tests.sh` — Run integration tests
- `node/node-quality.sh` — Type check, lint, and test TS/Node apps

---

## Reviewdog & PR annotations

All workflows use [`reviewdog`](https://github.com/reviewdog/reviewdog) to annotate PRs inline on GitHub.

Include this in your job’s env:

```yaml
env:
  REVIEWDOG_GITHUB_API_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

> Already included in `reusable-api-contracts.yml`, `reusable-verify-contracts.yml`, and all helper scripts (
`verify-all-specs.sh`, `gradle-quality.sh`, `node-quality.sh`).


---

## How Versioning, Publishing & Changelog Work in API First

- **Source of truth**: `info.version` in each `openapi.yaml`.
- **Branch → flavor**:
  - `develop` → publish as `x.y.z-SNAPSHOT`
  - `main` → publish as `x.y.z` (stable)
- **Selective publish**: only specs detected as changed (or whose per‑API `metadata.yml` changed) are built & published.
- **Root whitelist** (optional): if `require_listed_only: true`, only APIs listed in the **root** `metadata.yml` are
  eligible.
- **Changelog**: automatically generated via `oasdiff changelog` + Conventional Commits, attached as CI artifact or
  released note.

## How Versioning, Publishing & Changelog Work in Java Backend

- `semantic-release` runs on every push to `main` or `develop`
- `main` produces stable version (`1.0.0`), `develop` produces snapshot (`1.0.0-SNAPSHOT`)
- If version is valid, release is committed and pushed
- Docker image uses the resolved version
- Snapshot cleanup deletes older GHCR versions except latest N
- Sync PR created from `main` to `develop` to align branches

---

## Post‑release Sync (main → develop)

After a successful **stable** publish on `main`, the API workflow opens an automated PR to sync `main` back into
`develop` (branch alignment). If there are no changes, the step no‑ops.

> Version `x.y.z` sync main → develop

Branch auto-deleted after merge.

---

## Redoc Previews

If `run_redoc: true`, the API workflow builds one **HTML preview per changed API** and uploads it as a CI artifact, so
reviewers can inspect docs without running anything locally.

---

## Using These Workflows Across Repos

| Repo                             | Workflow                     |
|----------------------------------|------------------------------|
| `wendara-api-definitions`        | `reusable-api-contracts.yml` |
| `wendara-backend`                | `reusable-backend.yml`       |
| `wendara-web` / `wendara-mobile` | `reusable-node-app.yml`      |

Use `@main` while iterating, and switch to tag or SHA for production stability.

---

## Requirements

- **Permissions**: `GITHUB_TOKEN` (or PAT) with `packages:write` to publish artifacts/images; `pull-requests: write` for
  sync PR.
- **Runners**: Linux runners with Docker available (used by `oasdiff` container). Java and Node are set up by the
  reusable workflow.

- Repos must follow folder conventions per type (API, backend, frontend)
- `GITHUB_TOKEN` must have `packages:write` and `pull-requests: write`
- Docker must be available on runner (for Compose, Jib, OWASP)
- Node and Java are auto-installed in workflows
- Consumer repo: follow the API layout, provide `.redocly.yaml` (recommended), optional `metadata.yml` (root and/or
  per‑API).
- Use `Conventional Commits` for changelog support enforced via `.commitlintrc.json`.

---

## Troubleshooting

| Problem                          | Solution                                                                                                                                       |
|----------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| **Diff guard fails**             | Bump **major** (`v1` → `v2`) and/or increase `info.version` appropriately, then re‑run.                                                        |
| **Redoc artifact missing**       | Ensure `run_redoc: true` and a valid `.redocly.yaml` in the consumer repo root.                                                                |
| **Nothing published**            | Check `publish_enabled`, verify that `openapi.yaml` (or per‑API `metadata.yml`) actually changed and that the API is whitelisted (if enabled). |
| **Changelog not generated**      | Ensure you are using **Conventional Commits** and that `oasdiff changelog` ran successfully.                                                   |
| **Sync PR not created**          | Happens if no commits landed in `main`                                                                                                         |
| **Version empty in docker step** | Ensure `semantic-release` ran successfully                                                                                                     |
| **OWASP step skipped**           | Runs only on `main`, after release, and only if version was found                                                                              |
| **Image not pushed (backend)**   | Confirm `run_jib: true`, `image_name` set, and registry secrets configured.                                                                    |
