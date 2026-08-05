# Canonical Examples

Use this file when you need concrete examples. Inspect one or two relevant examples, not every file.

## Workflows

- API contracts: `.github/workflows/reusable-api-contracts.yml`
- Contract validation only: `.github/workflows/reusable-verify-contracts.yml`
- Java backend CI: `.github/workflows/reusable-java-backend.yml`
- Backend deploy: `.github/workflows/reusable-backend-deploy.yml`
- Node web CI: `.github/workflows/reusable-node-web.yml`
- Node mobile CI: `.github/workflows/reusable-node-mobile.yml`
- Mobile manual build: `.github/workflows/mobile-build.yml`
- Manual API release: `.github/workflows/reusable-manual-api-release.yml`
- Manual post release: `.github/workflows/reusable-manual-post-release.yml`

## Scripts

- OpenAPI semantic diff guard: `scripts/api-first/api-oasdiff-guard.sh`
- OpenAPI npm publish: `scripts/api-first/npm-publish-contracts.sh`
- Contract verification: `scripts/api-first/verify-all-specs.sh`
- Java quality: `scripts/java/gradle-quality.sh`
- Java unit tests: `scripts/java/run-java-unit-tests.sh`
- Web dist build: `scripts/web/build-web-dist.sh`
- Web dist package: `scripts/web/package-web-dist.sh`
- Version resolution: `scripts/read-gradle-version.sh`, `scripts/read-version-node.sh`

## Consumer Examples

Use README examples as the first source. When available, inspect caller workflows in `wendara-backend`, `wendara-mobile`,
`wendara-landing`, and `wendara-api-definitions` before changing public contracts.
