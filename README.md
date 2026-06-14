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
  - [API‑first (`reusable-api-contracts.yml`)](#apifirst-reusable-api-contractsyml)
  - [Contract Validation Only (`reusable-verify-contracts.yml`)](#contract-validation-only-reusable-verify-contractsyml)
  - [Java Backend (`reusable-java-backend.yml`)](#java-backend-reusable-java-backendyml)
  - [Backend Deploy (`reusable-backend-deploy.yml`)](#backend-deploy-reusable-backend-deployyml)
  - [Node Web Apps (`reusable-node-web.yml`)](#node-web-apps-reusable-node-webyml)
  - [Node Mobile Apps (`reusable-node-mobile.yml`)](#node-mobile-apps-reusable-node-mobileyml)
  - [Manual API Release (`reusable-manual-api-release.yml`)](#manual-api-release-reusable-manual-api-releaseyml)
- [Helper Scripts](#helper-scripts)
- [Reviewdog & PR annotations](#reviewdog--pr-annotations)
- [API First - How Versioning, Publishing & Changelog Work](#how-versioning-publishing--changelog-work-in-api-first)
- [Backend - How Versioning, Publishing & Changelog Work](#how-versioning-publishing--changelog-work-in-java-backend)
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
│  ├─ clean-ghcr-snapshots.sh              # Clean old GHCR snapshot versions
│  ├─ read-gradle-version.sh               # Resolve gradle version (env → code/gradle.properties → latest tag)
│  ├─ read-version-node.sh                  # Resolve package.json version
│  ├─ bump-gradle-version.sh               # Update code/gradle.properties (used by semantic-release)
│  ├─ api-first/
│  │  ├─ api-oasdiff-guard.sh              # OpenAPI semantic diff guard
│  │  ├─ oasdiff-changelog.sh              # Generate changelog entries from diff
│  │  ├─ redoc-build.sh                    # Build Redoc preview from spec
│  │  └─ verify-all-specs.sh               # Validate all specs in repo
│  ├─ java/
│  │  ├─ gradle-quality.sh                 # checkstyle, pmd, spotbugs (no tests here)
│  │  ├─ run-java-unit-tests.sh            # Run unit tests + coverage (Jacoco)
│  │  ├─ start-java-integration-env.sh     # Start Docker Compose (Mongo pinned + healthcheck)
│  │  ├─ run-java-integration-tests.sh     # Run integration tests
│  │  └─ stop-java-integration-env.sh      # Stop Docker Compose
│  ├─ web/
│  │  ├─ build-web-dist.sh                 # Build web dist output
│  │  └─ package-web-dist.sh               # Package dist into versioned tgz + sha256
└─ .github/
   └─ workflows/
      ├─ reusable-api-contracts.yml
      ├─ reusable-verify-contracts.yml
      ├─ reusable-java-backend.yml              # Java backend CI (Gradle, tests, semantic-release, Jib)
      ├─ reusable-node-web.yml
      ├─ reusable-node-mobile.yml
      ├─ mobile-build.yml
      └─ reusable-manual-post-release.yml
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

7. **Now also generates and publishes corresponding npm package versions for each changed API contract** (in addition to
   other artifact types), ensuring npm consumers can access the latest contract versions automatically.
8. After stable publish on `main`, opens a **PR main → develop** to keep branches in sync.

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
      node_version: "24"
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
      node_version: "24"
```

---

### Java Backend (`reusable-java-backend.yml`)

End‑to‑end CI pipeline for Java 21 + Gradle + Spring Boot with quality checks, image publishing, sync PR, and a final
pipeline summary.

**What it does**

1. Runs Java quality gates (static): `checkstyle`, `pmd` and `spotbugs`.
2. Executes **unit tests** + **coverage** and generates **Jacoco Coverage Report**.
3. **integration tests** brings up Docker Compose, runs ITs, and tears down.
4. Uses **semantic-release** to resolve the version and auto-tag commits.
5. Builds and pushes a **Docker image** using **Jib**, versioned with the release.
6. On `develop`: keeps **SNAPSHOT** Docker images.
7. On `main`: publishes **stable** Docker images and creates a **sync PR** to `develop`.
8. Runs an **OWASP Dependency Check** on `main` after release.
9. Cleans up old GHCR **snapshot** images to save space.
10. Prints a **pipeline summary** at the end of the workflow (only on release builds).

The quality gate job is now kept separate from unit and integration tests, so the three can run in parallel and only join again at `release`.

**Inputs**

| Name              | Type   | Required | Description                                                                |
|-------------------|--------|----------|----------------------------------------------------------------------------|
| `release-channel` | string | ✅        | `develop` or `main`. Controls version flavor, Docker publishing, and sync. |
| `package-name`    | string | ✅        | GHCR package name (e.g. `wendara-backend`). Used for Docker and cleanup.   |

**Secrets**

| Secret         | Purpose                                             |
|----------------|-----------------------------------------------------|
| `GITHUB_TOKEN` | Used for semantic-release, GHCR push, and sync PRs. |

**Outputs (`workflow_call`)**

| Output             | Description                                        |
|--------------------|----------------------------------------------------|
| `published`        | `true` when semantic-release published a version.  |
| `released_version` | Released version/tag used for Docker image publish. |
| `pre_version`      | Version detected before semantic-release.          |
| `post_version`     | Version detected after semantic-release.           |

**Jobs**

| Job                 | Description                                                        |
|---------------------|--------------------------------------------------------------------|
| `quality-checks`    | Runs static analysis only (`checkstyle`, `pmd`, `spotbugs`).       |
| `unit-tests`        | Runs unit tests and generates Jacoco coverage.                     |
| `integration-tests` | Starts Docker Compose env, runs integration tests, and stops it.   |
| `release`           | Publishes release artifacts and sets version/tag.                  |
| `docker`            | Builds and pushes Docker image to GHCR.                            |
| `clean-snapshots`   | Cleans old GHCR snapshots (develop only).                          |
| `sync-pr`           | Creates a PR to sync main → develop after release.                 |
| `owasp-check`       | Runs OWASP Dependency Check and uploads report.                    |
| `summary`           | Prints a summary of the pipeline results (only on release builds). |

> **Note:** The `summary` job only runs on release builds (push to develop/main or workflow_call), not on pull requests.
> This ensures the summary reflects the full pipeline and published artifacts.

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
    uses: wendara-org/wendara-ci-actions/.github/workflows/reusable-java-backend.yml@main
    with:
      release-channel: ${{ github.ref_name }}
      package-name: wendara-backend
```

### Backend Deploy (`reusable-backend-deploy.yml`)

Reusable deploy workflow for backend environments over SSH (current target: `dev` on DigitalOcean).

**What it does**

1. Resolves target settings by environment (`dev` or `prod`).
2. Validates environment variables from GitHub Environment and SSH key availability.
3. Connects via SSH, validates that the remote deploy script exists and is executable.
4. Executes remote deploy script with selected image tag.
5. Captures full remote output as log artifact and publishes a diagnostics summary.
6. Fails this workflow if remote deployment fails.

**Inputs**

| Name              | Type   | Required | Description                                 |
|-------------------|--------|----------|---------------------------------------------|
| `target-environment` | string | no (default `dev`) | Target environment: `dev` or `prod`. |
| `release-channel` | string | yes      | Current channel. `dev` deploy uses `develop`. |
| `image-tag`       | string | yes      | Docker image tag to deploy.                 |
| `package-name`    | string | yes      | GHCR package name (e.g. `wendara-backend`). |

**Secrets**

| Secret                | Purpose                      |
|-----------------------|------------------------------|
| `DEV_SSH_PRIVATE_KEY` | SSH private key for droplet. |
| `PROD_SSH_PRIVATE_KEY` | SSH private key for prod host. |
| `GHCR_TOKEN`          | Token used by remote deploy for GHCR login. |

**Environment variables (`environment: dev`)**

| Variable        | Purpose                     |
|-----------------|-----------------------------|
| `DEV_SSH_HOST`  | Droplet host/IP.            |
| `DEV_SSH_USER`  | SSH user for deploy.        |
| `PROD_SSH_HOST` | PROD host/IP.               |
| `PROD_SSH_USER` | SSH user for prod deploy.   |
| `GHCR_USERNAME` | GHCR username for login.    |

**Diagnostics produced by the workflow**

- Console output of the remote deploy script is streamed in real time.
- A log artifact is uploaded as `backend-deploy-log-<environment>-<tag>`.
- `GITHUB_STEP_SUMMARY` includes:
  - remote exit code,
  - rollback detection (`[ROLLBACK]` marker),
  - success marker detection (`Deploy successful:` marker).

**Example caller orchestration (recommended)**

Use two independent jobs in `wendara-backend/.github/workflows/ci.yml`: one for CI/release and one for deploy.

```yaml
jobs:
  backend_ci:
    uses: wendara-org/wendara-ci-actions/.github/workflows/reusable-java-backend.yml@main
    with:
      release-channel: ${{ github.ref_name }}
      package-name: wendara-backend
    secrets:
      GPR_USER: ${{ secrets.GPR_USER }}
      GPR_TOKEN: ${{ secrets.GPR_TOKEN }}

  deploy_dev:
    needs: backend_ci
    if: >
      github.event_name == 'push' &&
      github.ref == 'refs/heads/develop' &&
      needs.backend_ci.outputs.published == 'true'
    uses: wendara-org/wendara-ci-actions/.github/workflows/reusable-backend-deploy.yml@main
    with:
      target-environment: dev
      release-channel: develop
      image-tag: ${{ needs.backend_ci.outputs.released_version }}
      package-name: wendara-backend
    secrets:
      DEV_SSH_PRIVATE_KEY: ${{ secrets.DEV_SSH_PRIVATE_KEY }}
      PROD_SSH_PRIVATE_KEY: ${{ secrets.PROD_SSH_PRIVATE_KEY }}
      GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}
```

---

### Node Web Apps (`reusable-node-web.yml`)

Reusable CI pipeline for **Node.js** web apps (React, Vite, Next.js static build) with artifact packaging.

**What it does**

1. Runs code quality checks:

- `npm run lint`
- `npm test`
- (Optional) `npm run test:integration` if script exists

2. Builds web output (`npm run build`) and validates `dist/`.
3. Packages output as `dist-<version>.tgz` + `.sha256` artifact.
4. Runs semantic-release on `develop`/`main`.
5. Cleans old prereleases on `develop`.
6. Syncs `main` back to `develop` after stable release.

**Inputs**

| Name                | Type   | Default | Description                                  |
|---------------------|--------|---------|----------------------------------------------|
| `release-channel`   | string |         | `develop` or `main`. Empty disables release. |
| `node-version`      | string | `24`    | Node.js version for setup.                   |
| `working-directory` | string | `.`     | Directory where `package.json` lives.        |
| `dist-directory`    | string | `dist`  | Build output directory to package.           |
| `keep-prereleases`  | number | `10`    | How many prereleases to keep on develop.     |

**Secrets**

| Secret      | Purpose                                  |
|-------------|------------------------------------------|
| `GPR_USER`  | Optional user for GitHub Packages auth.  |
| `GPR_TOKEN` | Optional token for GitHub Packages auth. |

**Jobs**

| Job                 | Description                                                  |
|---------------------|--------------------------------------------------------------|
| `lint`              | Runs `npm run lint`.                                         |
| `unit-tests`        | Runs `npm test`.                                             |
| `integration-tests` | Runs `npm run test:integration` if script exists.            |
| `build`             | Builds `dist` and uploads `dist-<version>.tgz` + checksum.   |
| `release`           | Runs semantic-release for versioning/tags (on develop/main). |
| `snapshot-cleanup`  | Cleans up old prereleases (develop only).                    |
| `sync-pr`           | Creates PR to sync main → develop after release (main only). |

**Example usage** (`wendara-landing/.github/workflows/ci.yml`):

```yaml
name: Landing · CI

on:
  push:
    branches: [ develop, main ]
  pull_request:
    branches: [ develop, main ]
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write
  issues: write
  checks: write

jobs:
  landing:
    uses: wendara-org/wendara-ci-actions/.github/workflows/reusable-node-web.yml@main
    with:
      working-directory: "."
      dist-directory: "dist"
      release-channel: ${{ github.event_name == 'push' && github.ref_name || '' }}
    secrets:
      GPR_USER: ${{ secrets.GPR_USER }}
      GPR_TOKEN: ${{ secrets.GPR_TOKEN }}
```

---

### Node Mobile Apps (`reusable-node-mobile.yml`)

Reusable CI pipeline for **React Native** and other Node.js-based mobile apps. Supports linting, type checking,
unit/integration tests, semantic release, snapshot cleanup, and main→develop sync PRs.

**What it does**

1. Runs code quality checks:

- `npm run lint`
- `npm run typecheck`
- `npm test` (unit tests)
- (Optional) `npm run test:integration` if script exists

2. (Optional) Runs semantic-release for versioning and tagging on `develop`/`main`.
3. Cleans up old prereleases on `develop` (configurable count).
4. After stable release on `main`, opens a PR to sync `main` → `develop`.

**Inputs**

| Name                | Type   | Default | Description                                  |
|---------------------|--------|---------|----------------------------------------------|
| `release-channel`   | string |         | `develop` or `main`. Empty disables release. |
| `node-version`      | string | `24`    | Node.js version for setup.                   |
| `working-directory` | string | `.`     | Directory where `package.json` lives.        |
| `keep-prereleases`  | number | `10`    | How many prereleases to keep on develop.     |

**Secrets**

| Secret       | Purpose                                 |
|--------------|-----------------------------------------|
| `GPR_USER`   | GitHub Packages user (for npm publish). |
| `GPR_TOKEN`  | GitHub Packages token.                  |
| `EXPO_TOKEN` | Expo EAS token (optional, for EAS).     |

**Jobs**

| Job                 | Description                                                  |
|---------------------|--------------------------------------------------------------|
| `lint`              | Runs `npm run lint`.                                         |
| `typecheck`         | Runs `npm run typecheck`.                                    |
| `unit-tests`        | Runs `npm test`.                                             |
| `integration-tests` | Runs `npm run test:integration` if script exists.            |
| `release`           | Runs semantic-release for versioning/tags (on develop/main). |
| `snapshot-cleanup`  | Cleans up old prereleases (develop only).                    |
| `sync-pr`           | Creates PR to sync main → develop after release (main only). |

**Example usage** (`wendara-mobile/.github/workflows/ci.yml`):

```yaml
name: Mobile · CI

on:
  push:
    branches: [ develop, main ]
  pull_request:
    branches: [ develop, main ]
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write
  issues: write
  checks: write

concurrency:
  group: wendara-mobile-${{ github.ref }}
  cancel-in-progress: true

jobs:
  mobile:
    uses: wendara-org/wendara-ci-actions/.github/workflows/reusable-node-mobile.yml@main
    with:
      node-version: "24"
      working-directory: "."
      release-channel: ${{ github.event_name == 'push' && github.ref_name || '' }}
      run-build: false
    secrets:
      GPR_USER: ${{ secrets.GPR_USER }}
      GPR_TOKEN: ${{ secrets.GPR_TOKEN }}
      EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}
```

---

### Mobile Manual Build (`mobile-build.yml`)

Manual workflow to trigger a mobile build for a specific tag and platform using Expo EAS. Intended for on-demand
builds (e.g., QA, release candidates).

**What it does**

1. Allows manual trigger with inputs: tag, platform (android/ios/all), and EAS profile (dev/prod).
2. Validates tag format and enforces prod policy (no prerelease tags for prod).
3. Checks out the repo at the specified tag.
4. Installs dependencies and verifies build inputs.
5. Runs EAS build for Android and/or iOS as requested.
6. Summarizes build results and provides artifact links.

**Inputs**

| Name          | Type   | Required | Description                            |
|---------------|--------|----------|----------------------------------------|
| `tag`         | string | yes      | Git tag to build (e.g., v1.2.3).       |
| `platform`    | choice | yes      | Target platform: android, ios, or all. |
| `eas-profile` | choice | yes      | EAS build profile: dev or prod.        |

**Secrets**

| Secret       | Purpose                    |
|--------------|----------------------------|
| `EXPO_TOKEN` | Expo EAS token for builds. |

**Jobs**

| Job   | Description                                  |
|-------|----------------------------------------------|
| build | Runs the EAS build for the selected options. |

**Example usage** (manual trigger):

- Go to the Actions tab in GitHub.
- Select "Mobile · Build".
- Click "Run workflow" and fill in the required inputs.

---

### Manual API Release (`reusable-manual-api-release.yml`)

Reusable workflow for manually publishing (backfilling) API contract artifacts to GitHub Packages (Maven and npm).
Intended for cases where historical or missing releases need to be published without triggering the full automated
pipeline.

**What it does**

1. Allows manual or workflow_call-driven publishing of a specific API contract version to Maven, npm, or both.
2. Resolves the target OpenAPI spec via the root `metadata.yml` using the provided API id, transport, and version.
3. Reads the canonical version from the spec's `info.version` (source of truth).
4. Publishes the contract as a Maven artifact (zip) and/or npm package to GitHub Packages, using the same conventions as
   the automated workflow.
5. Skips publishing if the artifact or package already exists (idempotent, logs skip).
6. Only runs on `main` branch (guarded at runtime).

**Inputs**

| Name          | Type   | Required | Default | Description                                         |
|---------------|--------|----------|---------|-----------------------------------------------------|
| `api_id`      | string | yes      |         | API id as in root `metadata.yml` (e.g., `auth`).    |
| `transport`   | string | yes      |         | Transport as in root `metadata.yml` (e.g., `rest`). |
| `api_version` | string | yes      |         | API version folder (e.g., `v1`).                    |
| `channel`     | string | no       | RELEASE | Release channel: `SNAPSHOT` or `RELEASE`.           |
| `target`      | string | no       | both    | Publishing target: `maven`, `npm`, or `both`.       |

**Secrets**

| Secret           | Purpose                                                               |
|------------------|-----------------------------------------------------------------------|
| `PACKAGES_TOKEN` | Token with `packages:write` (optional, falls back to `github.token`). |

**Jobs**

| Job              | Description                                                                   |
|------------------|-------------------------------------------------------------------------------|
| `manual_release` | Publishes the specified API contract to Maven and/or npm, skipping if exists. |

**Example usage** (`wendara-api-definitions/.github/workflows/manual-api-release.yml`):

```yaml
name: Manual API Release

on:
  workflow_dispatch:
    inputs:
      api_id:
        description: "API id as in root metadata.yml (e.g., auth)"
        required: true
        type: string
      transport:
        description: "Transport as in root metadata.yml (e.g., rest)"
        required: true
        type: string
      api_version:
        description: "API version folder (e.g., v1)"
        required: true
        type: string
      channel:
        description: "Release channel (SNAPSHOT|RELEASE). Backfill should use RELEASE."
        required: false
        default: "RELEASE"
        type: choice
        options: [ "RELEASE", "SNAPSHOT" ]
      target:
        description: "Publishing target"
        required: false
        default: "both"
        type: choice
        options: [ "both", "maven", "npm" ]

permissions:
  contents: read
  packages: write

jobs:
  manual_release:
    uses: wendara-org/wendara-ci-actions/.github/workflows/reusable-manual-api-release.yml@main
    with:
      api_id: "auth"
      transport: "rest"
      api_version: "v1"
      channel: "RELEASE"
      target: "both"
    secrets:
      PACKAGES_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Environment Variables**

The workflow defines the following environment variables for registry endpoints and package naming:

| Variable         | Example Value                                                      | Purpose                                                |
|------------------|--------------------------------------------------------------------|--------------------------------------------------------|
| `MAVEN_REPO_URL` | `https://maven.pkg.github.com/wendara-org/wendara-api-definitions` | GitHub Packages Maven registry for contract artifacts. |
| `NPM_REGISTRY`   | `https://npm.pkg.github.com`                                       | GitHub Packages npm registry for contract packages.    |
| `NPM_SCOPE`      | `@wendara-org`                                                     | npm scope for contract packages.                       |

These are used by the publishing steps and scripts to ensure all artifacts are routed to the correct registry and scope,
and to avoid hardcoding URLs in multiple places.

> **Note:** This workflow is intended for manual or backfill use only. For automated contract publishing on push/PR, use
`reusable-api-contracts.yml`.

---

## Helper Scripts

All helper scripts are located under `scripts/` and grouped by domain:

### API-first (`scripts/api-first/`)

| Script                 | Purpose                                                                               |
|------------------------|---------------------------------------------------------------------------------------|
| `api-oasdiff-guard.sh` | Runs `oasdiff` to detect **breaking changes** and classify diffs (MAJOR/MINOR/PATCH). |
| `oasdiff-changelog.sh` | Generates changelog entries from the semantic diff.                                   |
| `redoc-build.sh`       | Builds a static Redoc HTML preview for a given `openapi.yaml`.                        |
| `verify-all-specs.sh`  | Validates all OpenAPI specs in the repo (structure, semver, lint).                    |

### Java (`scripts/java/`)

| Script                          | Purpose                                                    |
|---------------------------------|------------------------------------------------------------|
| `gradle-quality.sh`             | Runs `checkstyle`, `pmd` and `spotbugs`                    |
| `run-java-unit-tests.sh`        | Executes unit tests via Gradle.                            |
| `start-java-integration-env.sh` | Starts integration test environment (e.g. Docker Compose). |
| `run-java-integration-tests.sh` | Runs integration tests.                                    |
| `stop-java-integration-env.sh`  | Tears down integration test environment.                   |

### Utilities (`scripts/`)

| Script                    | Purpose                                                                                           |
|---------------------------|---------------------------------------------------------------------------------------------------|
| `read-gradle-version.sh`  | Reads the current release version from `env, code/gradle.properties, latest tag` (in that order). |
| `bump-gradle-version.sh`  | Writes a version string to `code/gradle.properties` and optionally commits the change.            |
| `clean-ghcr-snapshots.sh` | Deletes old GHCR Docker image snapshots (retains latest N).                                       |

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
- **npm versioning**: for each changed API contract, a corresponding npm package version is generated and published to
  the npm registry, matching the contract versioning strategy above. This allows npm consumers to always retrieve the
  latest contract definitions via npm.

## How Versioning, Publishing & Changelog Work in Java Backend

**Repo layout (assumed):**

* Gradle project under `code/` (`code/build.gradle.kts`, `code/gradle.properties` with `version = ...`).
* Changelog under `docs/CHANGELOG.md`.
* `package.json` (and optional `.releaserc*.json`) at the **repo root** (siblings of `code/` and `docs/`).

**Branch behavior (semantic-release at repo root, Node 24):**

* **develop** → computes a **pre-release** (e.g., `v1.2.0-develop.1`).
  ➜ Does **not** modify `code/gradle.properties` or `docs/CHANGELOG.md`.
  ➜ Publishes a GitHub pre-release (tag only, no changelog commit).
* **main** → computes a **stable** release (e.g., `v1.2.0`).
  ➜ Updates **`code/gradle.properties`** (via `scripts/bump-gradle-version.sh`).
  ➜ Updates **`docs/CHANGELOG.md`**, creates **tag** and **GitHub Release**.
  ➜ Triggers **sync PR** (main → develop).

**How downstream jobs resolve the version** (`scripts/read-gradle-version.sh`):

1. `VERSION` env var (if provided by the workflow/step).
2. `code/gradle.properties` (`version = ...`) — source of truth on **main**.
3. Latest Git tag (leading `v` stripped) — used for **develop** pre-releases.

> Tip: pass the channel to the resolver so it prefers tags on `develop`:

```yaml
- uses: actions/checkout@v6
  with: { fetch-depth: 0 } # ensure tags are available
- name: Resolve VERSION
  id: ver
  env:
    RELEASE_CHANNEL: ${{ inputs.release-channel }}  # "develop" or "main"
  run: echo "version=$(./scripts/read-gradle-version.sh)" >> "$GITHUB_OUTPUT"
```

**Where the Gradle bump happens (main only):**

* `@semantic-release/exec` runs `scripts/bump-gradle-version.sh ${nextRelease.version}` during **prepare** on `main`.
* `@semantic-release/changelog` updates `docs/CHANGELOG.md`.
* `@semantic-release/git` commits both files; `@semantic-release/github` creates the Release.

**Docker/Jib:**

* The `docker` job uses the resolved version (from the step above) and runs:

  ```bash
  ./gradlew jib --no-daemon -Pversion="${{ steps.ver.outputs.version }}"
  ```

  Images are pushed to GHCR and tagged with the computed version (pre-release on `develop`, stable on `main`).

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

| Repo                      | Workflow                     |
|---------------------------|------------------------------|
| `wendara-api-definitions` | `reusable-api-contracts.yml` |
| `wendara-backend`         | `reusable-java-backend.yml`  |
| `wendara-landing`         | `reusable-node-web.yml`      |
| `wendara-mobile`          | `reusable-node-mobile.yml`   |
| `wendara-mobile`          | `mobile-build.yml`           |

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

| Problem                              | Solution                                                                                                                                              |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Diff guard fails (API)**           | Bump **major** (`v1` → `v2`) and/or increase `info.version` appropriately, then re-run.                                                               |
| **Redoc artifact missing (API)**     | Ensure `run_redoc: true` and a valid `.redocly.yaml` in the consumer repo root.                                                                       |
| **Nothing published (API)**          | Check `publish_enabled`; verify the spec actually changed and that the API is whitelisted (if enabled).                                               |
| **Changelog not generated (API)**    | Ensure you use **Conventional Commits** and that the changelog step ran successfully.                                                                 |
| **Coverage ran twice**               | By design, coverage now runs **only** in `unit-tests`. `quality-checks` is **static-only** (Checkstyle/PMD/SpotBugs).                                 |
| **Compose up but ITs flaky**         | Pin Mongo image (e.g., `mongo:7.0`) and add a **healthcheck**; wait for **healthy** before running ITs.                                               |
| **Version empty in docker step**     | Ensure the `release` job completed, `actions/checkout` used `fetch-depth: 0`, and `read-gradle-version.sh` can see `code/gradle.properties` or a tag. |
| **Changelog not updated on develop** | Intentional. Only **main** updates `docs/CHANGELOG.md` and creates a GitHub Release.                                                                  |
| **OWASP step skipped**               | Runs only on **main**, after release, and only if a version was resolved (report-only).                                                               |
| **Sync PR not created**              | Happens if no new commits landed on `main` or the release did not produce a new tag.                                                                  |
| **Gradle version not bumped (main)** | Check `scripts/bump-gradle-version.sh` exists and is executable; verify `@semantic-release/exec` is configured in the **main** config.                |
| **Git tags not found**               | Use `actions/checkout@v6` with `fetch-depth: 0` (or fetch tags before calling `read-gradle-version.sh`).                                              |
| **Image not pushed (backend)**       | Confirm GHCR login, `packages: write` permission, and Jib params (`-Pversion=...`) are set correctly.                                                 |
