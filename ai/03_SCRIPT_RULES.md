# Script Rules

Use this file for `scripts/**/*.sh` changes.

## Bash Safety

- Use `#!/usr/bin/env bash` and `set -euo pipefail`.
- Validate required arguments at the top and print safe usage messages.
- Check required tools early with `command -v`.
- Quote variables and paths.
- Use arrays for command arguments when complexity grows.
- Prefer explicit temp/build directories and clean them safely.
- Return clear exit codes and GitHub annotation syntax when scripts are consumed by workflows.

## Secrets and Logs

- Never print secrets, tokens, private keys, auth headers, `.npmrc.ci`, Gradle credentials, SSH material, or raw deploy
  logs that may contain sensitive values.
- Avoid `set -x` in CI scripts.
- Redact or summarize sensitive external command output.

## Determinism and Compatibility

- Keep CLI arguments backward-compatible.
- Preserve stdout lines consumed by workflows, such as `KEY=value` outputs.
- Keep artifact names, checksum behavior, package naming, and version derivation stable.
- Fail fast on missing required files and tools.
- Prefer POSIX-friendly utilities available on GitHub-hosted Ubuntu runners unless documented.
