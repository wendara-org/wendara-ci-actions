# Wendara CI Actions Context

Use this file when you need repository context beyond `ai/00_ALWAYS.md`.

## Purpose

`wendara-ci-actions` centralizes reusable GitHub Actions workflows and helper scripts for Wendara repositories. It is a
shared CI/CD platform, not an application runtime.

## Consumers

Primary consumers include:

- `wendara-backend`: Java/Gradle backend CI, Docker/Jib publish, deploy, sync PR.
- `wendara-api-definitions`: OpenAPI validation, semantic diff guard, Redoc, Maven/npm publishing.
- `wendara-mobile`: Node/mobile checks, semantic-release, Expo manual builds.
- `wendara-landing`: Node web checks, static build packaging, semantic-release.

## Repository Map

- `.github/workflows/`: reusable workflows and manual build/deploy/release entrypoints.
- `.github/actions/`: local action documentation and future composite actions.
- `scripts/api-first/`: OpenAPI diff, lint, Redoc, changelog, npm publish, verify scripts.
- `scripts/java/`: Gradle quality, unit/integration tests, Docker integration env, test summaries.
- `scripts/web/`: static web build and artifact packaging.

## Risk Model

Small changes can break multiple repositories. Review compatibility, permissions, secrets, artifacts, outputs, and
release behavior before treating a diff as safe.
