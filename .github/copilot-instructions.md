# Wendara CI Actions Copilot Instructions

Follow `AGENTS.md`, `AI_ENGINEERING_GUIDELINES.md`, and `ai/00_ALWAYS.md` for repository-wide behavior.

Load only task-specific rules from `ai/`. Do not load the entire AI folder by default.

Core constraints:

- Treat reusable workflow inputs, secrets, outputs, defaults, artifact names, job ids, and script CLI args as public
  contracts.
- Preserve compatibility for backend, mobile, landing, and API definitions consumers unless a breaking migration is
  explicit and documented.
- Use least-privilege GitHub permissions.
- Never leak secrets, tokens, auth headers, SSH keys, `.npmrc.ci`, Gradle credentials, or sensitive deploy output.
- Keep Bash strict, quoted, deterministic, and clear about required tools.
- Do not run real publish, deploy, Docker push, Expo build, or consumer workflows unless explicitly requested.

Reusable prompts live in `ai/prompts/`.
