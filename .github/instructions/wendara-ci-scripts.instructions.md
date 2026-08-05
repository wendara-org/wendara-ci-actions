---
applyTo: "scripts/**/*.sh"
---

# Wendara CI Script Instructions

- Use Bash with `set -euo pipefail`.
- Validate arguments and required tools early.
- Quote variables and paths.
- Preserve CLI arguments, stdout contracts, artifact names, version derivation, checksums, and exit-code semantics.
- Never print or persist secrets, tokens, auth headers, SSH keys, `.npmrc.ci`, Gradle credentials, or sensitive deploy
  output.
- Avoid `set -x` in CI scripts.
- Keep temp/build paths deterministic and safe.
- Run `bash -n` on touched scripts. Run ShellCheck when available.
