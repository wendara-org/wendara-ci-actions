# Wendara CI Actions

Reusable GitHub Actions **workflows** and **helper scripts** for Wendara’s engineering stack.

- **One place** to codify CI/CD standards.
- **Contract‑first** automation for OpenAPI (lint, semantic diff guard, changelog, Redoc, selective publish).
- **Backend** pipelines for Java 21 + Gradle + Spring Boot + **Jib**.
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
- [How Versioning, Publishing & Changelog Work](#how-versioning-publishing--changelog-work)
- [Post‑release Sync (main → develop)](#postrelease-sync-main--develop)
- [Redoc Previews](#redoc-previews)
- [Using These Workflows Across Repos](#using-these-workflows-across-repos)
- [Requirements](#requirements)
- [Troubleshooting](#troubleshooting)

---

## Purpose
Centralize and reuse CI/CD logic across Wendara repositories while enforcing consistent quality gates:

- **OpenAPI**: YAML sanity, lint, **semantic diff guard** (breaking change detection), **changelog generation**, **Redoc** previews, and **selective publishing** (only changed APIs).
- **Backend**: Java 21 + Gradle quality gates, unit tests & coverage, image build with **Jib**.
- **Web/Mobile**: Type checks, ESLint, unit tests, optional build.

---

## Folder Structure

```
wendara-ci-actions/
├─ .editorconfig                     # Shared editor defaults
├─ .gitattributes                    # LF normalization, linguist hints, etc.
├─ .commitlintrc.json                # Conventional commits configuration
├─ README.md                         # This document
├─ scripts/                          # Helper scripts used by workflows
│  ├─ api-oasdiff-guard.sh           # OpenAPI semantic diff guard & changelog
│  ├─ redoc-build.sh                 # Generate Redoc HTML preview for a spec
│  ├─ gradle-quality.sh              # checkstyle, pmd, spotbugs, jacoco (backend)
│  └─ node-quality.sh                # tsc --noEmit, eslint, tests (web/mobile)
└─ .github/
   └─ workflows/
      ├─ reusable-api-contracts.yml  # API-first reusable (lint, guard, changelog, publish, Redoc, sync PR)
      ├─ reusable-backend.yml        # Backend reusable (Java/Gradle/Spring Boot/Jib)
      └─ reusable-node-app.yml       # Node reusable (React/Next.js/RN)
```

---

## Conventions & Assumptions
- **Branches**: `develop` (integration) and `main` (stable).
- **API layout** in consumer repos (e.g., `wendara-api-definitions`):
  - `apis/<transport>/<apiName>/<major>/openapi.yaml`  (e.g., `apis/rest/emotion-journal/v1/openapi.yaml`)
  - Optional **per‑API** `metadata.yml` next to the spec (artifact overrides, `publish` flag).
  - Optional **root** `metadata.yml` at repo root (acts as a **whitelist** of publishable APIs via `definition-path`).
- **Version source of truth**: `info.version` inside each `openapi.yaml`.
- **Publish flavor** by branch: `develop` → `x.y.z-SNAPSHOT`, `main` → `x.y.z` stable.
- **Conventional Commits** are required: they ensure consistent commit history and power automatic changelog generation.

---

## Reusable Workflows

### API‑first (`reusable-api-contracts.yml`)
End‑to‑end automation for OpenAPI contracts: lint → semantic guard → changelog → Redoc previews → selective publish → sync PR.

**What it does**
1. Detects changed specs (`openapi.yaml`) and related per‑API `metadata.yml`; also reacts to changes in **root** `metadata.yml`.
2. **Validates** YAML and runs **Redocly lint** using the consumer’s `.redocly.yaml` (if present).
3. Runs **semantic diff guard** (Tufin `oasdiff`) and fails PRs on breaking changes unless the **major** version was bumped.
4. Generates **changelog entries** (MAJOR/MINOR/PATCH).
5. Optionally builds **Redoc HTML previews** and uploads them as artifacts.
6. **Publishes only changed APIs**:
- on `develop`: **SNAPSHOT** artifacts
- on `main`: **stable** artifacts
7. After stable publish on `main`, opens a **PR main → develop** to keep branches in sync.

**Inputs**

| Name                 | Type    | Default | Description |
|----------------------|---------|---------|-------------|
| `java_version`       | string  | `21`    | Java toolchain for Gradle tasks. |
| `node_version`       | string  | `22`    | Node.js version for Redoc build, lint tools. |
| `run_redoc`          | boolean | `true`  | Build Redoc HTML previews. |
| `publish_enabled`    | boolean | `false` | If true, publishes artifacts (set to `true` on `push`, not PR). |
| `require_listed_only`| boolean | `true`  | If true, only APIs listed in root `metadata.yml` are considered. |

**Secrets**

| Secret            | Purpose |
|-------------------|---------|
| `PACKAGES_TOKEN`  | Token with `packages:write` (typically `GITHUB_TOKEN`). |

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
Standalone reusable workflow to **validate all OpenAPI specs** across a repository — regardless of whether they changed — without publishing anything. Useful for PRs and early feedback.

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


### Backend (`reusable-backend.yml`)
CI for Java 21 + Gradle + Spring Boot with quality gates and **Jib** image build.

**What it includes**
- `./scripts/gradle-quality.sh`: `checkstyle`, `pmd`, `spotbugs`, tests, `jacoco` report.
- Jib build & push (no Docker daemon required).

---

### Node Apps (`reusable-node-app.yml`)
CI for React / Next.js / React Native (TypeScript by default).

**What it includes**
- `./scripts/node-quality.sh`: `tsc --noEmit`, `eslint`, unit tests.
- Optional production build (`run_build: true`).

---

## Helper Scripts
- **`scripts/api-oasdiff-guard.sh`** — Runs Tufin `oasdiff` in Docker to classify changes (**MAJOR/MINOR/PATCH**) and generate changelog entries. Fails on **breaking** when version bump is insufficient.
- **`scripts/redoc-build.sh`** — Builds a static Redoc HTML from a given `openapi.yaml`. Respects the consumer repo’s `.redocly.yaml`.
- **`scripts/gradle-quality.sh`** — Aggregates Java quality checks and test coverage.
- **`scripts/node-quality.sh`** — Aggregates Node/TS checks and tests.

---

## Reviewdog & PR annotations

All reusable workflows and scripts that perform quality checks use [`reviewdog`](https://github.com/reviewdog/reviewdog) with:

```yaml
-reporter=github-pr-check
```

This means:

- Any linting or semantic error will appear directly in the GitHub PR UI as inline annotations.
- It requires the following job-level environment variable:

```yaml
env:
  REVIEWDOG_GITHUB_API_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

> Already included in `reusable-api-contracts.yml`, `reusable-verify-contracts.yml`, and all helper scripts (`verify-all-specs.sh`, `gradle-quality.sh`, `node-quality.sh`).


---

## How Versioning, Publishing & Changelog Work
- **Source of truth**: `info.version` in each `openapi.yaml`.
- **Branch → flavor**:
  - `develop` → publish as `x.y.z-SNAPSHOT`
  - `main` → publish as `x.y.z` (stable)
- **Selective publish**: only specs detected as changed (or whose per‑API `metadata.yml` changed) are built & published.
- **Root whitelist** (optional): if `require_listed_only: true`, only APIs listed in the **root** `metadata.yml` are eligible.
- **Changelog**: automatically generated via `oasdiff changelog` + Conventional Commits, attached as CI artifact or released note.

---

## Post‑release Sync (main → develop)
After a successful **stable** publish on `main`, the API workflow opens an automated PR to sync `main` back into `develop` (branch alignment). If there are no changes, the step no‑ops.

---

## Redoc Previews
If `run_redoc: true`, the API workflow builds one **HTML preview per changed API** and uploads it as a CI artifact, so reviewers can inspect docs without running anything locally.

---

## Using These Workflows Across Repos
- **API definitions** (`wendara-api-definitions`) → use **`reusable-api-contracts.yml`**.
- **Backend services** (Java/Spring Boot) → use **`reusable-backend.yml`**.
- **Web/Mobile** apps (React/Next.js/RN) → use **`reusable-node-app.yml`**.

> Pin a **tag** or **commit SHA** for stability in production repos. Using `@main` is acceptable while iterating.

---

## Requirements
- **Permissions**: `GITHUB_TOKEN` (or PAT) with `packages:write` to publish artifacts/images; `pull-requests: write` for sync PR.
- **Runners**: Linux runners with Docker available (used by `oasdiff` container). Java and Node are set up by the reusable workflow.
- **Consumer repo**: follow the API layout, provide `.redocly.yaml` (recommended), optional `metadata.yml` (root and/or per‑API).
- **Commit style**: Conventional Commits enforced via `.commitlintrc.json`.

---

## Troubleshooting
- **Diff guard failed (breaking change)**  
  Bump **major** (`v1` → `v2`) and/or increase `info.version` appropriately, then re‑run.
- **Nothing published on push**  
  Check `publish_enabled`, verify that `openapi.yaml` (or per‑API `metadata.yml`) actually changed and that the API is whitelisted (if enabled).
- **Redoc artifact missing**  
  Ensure `run_redoc: true` and a valid `.redocly.yaml` in the consumer repo root.
- **Changelog not generated**  
  Ensure you are using **Conventional Commits** and that `oasdiff changelog` ran successfully.
- **Image not pushed (backend)**  
  Confirm `run_jib: true`, `image_name` set, and registry secrets configured.
