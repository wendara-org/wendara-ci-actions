# Release and Consumer Rules

Use this file for release, publish, deploy, sync PR, package, artifact, and consumer compatibility changes.

## Consumer Compatibility

- Check affected consumers: backend, mobile, landing, and API definitions.
- Treat changes to workflow inputs, secrets, outputs, defaults, required permissions, script args, artifact names, and
  package names as compatibility-sensitive.
- Breaking changes require README migration guidance and, when practical, consumer workflow updates in the same task.

## Release and Publish

- Preserve semantic-release behavior for `develop` prereleases and `main` stable releases.
- Preserve main-to-develop sync PR behavior after stable releases.
- Do not break GHCR Docker publishing, npm package publishing, Maven/OpenAPI publishing, Redoc artifacts, or web dist
  packaging.
- Keep version source-of-truth rules stable: Gradle properties for backend where documented, `package.json` for Node,
  and OpenAPI `info.version` for contracts.
- Preserve immutable npm release versions and snapshot/pre-release uniqueness.

## Deploy and Mobile Build

- Deploy workflows must validate target environment, image tag, SSH key availability, and remote script behavior before
  acting.
- Deploy logs and summaries must avoid leaking secrets while preserving diagnostics.
- Mobile manual builds must preserve tag validation, platform/profile constraints, Expo token usage, and artifact links.

## API-First

- Preserve semantic diff guard, breaking-change version policy, metadata behavior, selective publish, reviewdog
  annotations, Redoc previews, and npm/Maven package naming.
